import AppKit
import Combine
import Foundation

@MainActor
final class StudioAppState: ObservableObject {
    struct PolicyBanner: Identifiable {
        enum Kind {
            case success
            case error
            case info
        }

        let id = UUID()
        let kind: Kind
        let message: String
    }

    struct RemotePreset: Identifiable, Hashable {
        let id: String
        let name: String
        let primaryText: String
        let secondaryText: String
    }

    struct RemoteTargetSummary: Identifiable, Hashable {
        let id: String
        let title: String
        let primaryText: String
        let secondaryText: String
    }

    struct RemoteOnboardingStep: Identifiable, Hashable {
        enum State {
            case pending
            case active
            case done
        }

        let id: String
        let title: String
        let detail: String
        let state: State
    }

    enum RemoteSetupState: Equatable {
        case needsSetup
        case settingUp
        case ready
    }

    enum RemoteConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
    }

    enum SidebarMode: String, CaseIterable, Identifiable {
        case workspace = "Workspace"
        case policies = "Policies"
        case remote = "Remote"

        var id: String { rawValue }
    }

    @Published var sidebarMode: SidebarMode = .workspace {
        didSet {
            persistUserInterfaceState()
        }
    }

    @Published var isSidebarVisible = true {
        didSet {
            persistUserInterfaceState()
        }
    }

    @Published var isInspectorVisible = false {
        didSet {
            persistUserInterfaceState()
        }
    }

    @Published var isOutputVisible = false {
        didSet {
            persistUserInterfaceState()
        }
    }

    @Published private(set) var workspaceNodes: [WorkspaceNode] = []
    @Published private(set) var toolbarTitle = "No file selected"
    @Published private(set) var openFileNodeIDs: [String] = []
    @Published private(set) var editorText = ""
    @Published private(set) var policies: [PolicyFile] = []
    @Published var selectedPolicyID: String?
    @Published var activePolicyID: String? {
        didSet {
            persistActivePolicySelection()
        }
    }
    @Published var activeRemoteTargetID: String? {
        didSet {
            persistActiveRemoteTargetSelection()
        }
    }
    @Published var remoteAccountUsername = "" {
        didSet {
            persistRemoteAccountUsername()
            if trimmedRemoteAccountUsername.isEmpty == false,
               remoteStatusMessage?.contains("name.lastname") == true {
                remoteStatusMessage = nil
            }
        }
    }
    @Published var remoteSetupState: RemoteSetupState = .needsSetup
    @Published var remoteConnectionState: RemoteConnectionState = .disconnected
    @Published private(set) var remoteSetupStepIndex = 0
    @Published private(set) var remoteStatusMessage: String?
    @Published var remoteInstallerInput = ""
    @Published private(set) var remoteInstallerOutput = ""
    @Published private(set) var remoteInstallerPrompt: RemoteInstallerPrompt?
    @Published private(set) var isRemoteInstallerVisible = false
    @Published private(set) var isRemoteInstallerRunning = false
    @Published var policyEditorText = ""
    @Published private(set) var selectedPolicyDraft: PolicyDraft?
    @Published var selectedPolicyTestCaseID: UUID?
    @Published private(set) var policyBanner: PolicyBanner?
    @Published private(set) var runOutputText = ""
    @Published private(set) var isRunInProgress = false
    @Published private(set) var runStatusMessage = "Ready to run"
    @Published private(set) var latestRunReport: EngineRunReport?
    @Published private(set) var latestRunError: String?

    @Published var expandedDirectoryIDs: Set<String> = [] {
        didSet {
            persistWorkspaceSelectionState()
        }
    }

    @Published var selectedFileNodeID: String? {
        didSet {
            persistWorkspaceSelectionState()
        }
    }

    private var workspaceRootURL: URL?
    private var urlByNodeID: [String: URL] = [:]
    private var loadedPolicyText = ""
    private var loadedPolicyDraft: PolicyDraft?

    private let engineClient: EngineClient
    private let workspaceService: WorkspaceService
    private let terminalService: TerminalService
    private let remoteAccessService: RemoteAccessService

    private var isRestoringSession = false
    private var activeSecurityScopedWorkspaceURL: URL?
    private var currentRunTask: Task<Void, Never>?
    private var remoteSetupTask: Task<Void, Never>?
    private var remoteConnectionTask: Task<Void, Never>?
    private var remoteRefreshTask: Task<Void, Never>?
    private var remoteInstallerTask: Task<Void, Never>?

    init(
        engineClient: EngineClient = BridgeEngineClient(),
        workspaceService: WorkspaceService = LocalWorkspaceService(),
        terminalService: TerminalService = InMemoryTerminalService(),
        remoteAccessService: RemoteAccessService = LocalRemoteAccessService()
    ) {
        self.engineClient = engineClient
        self.workspaceService = workspaceService
        self.terminalService = terminalService
        self.remoteAccessService = remoteAccessService
        restorePersistedSession()
    }

    deinit {
        remoteSetupTask?.cancel()
        remoteConnectionTask?.cancel()
        remoteRefreshTask?.cancel()
        remoteInstallerTask?.cancel()
        activeSecurityScopedWorkspaceURL?.stopAccessingSecurityScopedResource()
    }

    func openWorkspacePanel() {
        guard let url = workspaceService.chooseWorkspaceURL() else {
            return
        }

        loadWorkspace(at: url)
    }

    func loadWorkspace(
        at rootURL: URL,
        restoredExpandedDirectoryIDs: Set<String>? = nil,
        restoredSelectedFileNodeID: String? = nil
    ) {
        beginAccessingWorkspace(at: rootURL)

        let snapshot: WorkspaceSnapshot
        do {
            snapshot = try workspaceService.loadWorkspace(at: rootURL)
        } catch {
            return
        }

        workspaceRootURL = rootURL
        toolbarTitle = rootURL.lastPathComponent
        workspaceNodes = snapshot.nodes
        urlByNodeID = snapshot.urlByNodeID
        openFileNodeIDs = []
        refreshPolicies()

        let directoryIdentifiers = directoryIDs(in: workspaceNodes)
        let restoredExpanded = (restoredExpandedDirectoryIDs ?? [snapshot.rootNodeID]).intersection(directoryIdentifiers)
        expandedDirectoryIDs = restoredExpanded.union([snapshot.rootNodeID])

        if let restoredSelectedFileNodeID {
            selectFile(nodeID: restoredSelectedFileNodeID)
        } else {
            selectFile(nodeID: nil)
        }

        if let restoredActivePolicyID = UserDefaults.standard.string(forKey: PersistedKey.activePolicyID),
           policies.contains(where: { $0.id == restoredActivePolicyID }) {
            activePolicyID = restoredActivePolicyID
        } else if activePolicyID == nil {
            activePolicyID = policies.first?.id
        }

        if let selectedPolicyID {
            selectPolicyForEditing(policyID: selectedPolicyID)
        } else if let preferredPolicyID = activePolicyID ?? policies.first?.id {
            selectPolicyForEditing(policyID: preferredPolicyID)
        }

        persistWorkspaceBookmark(for: rootURL)
    }

    func nodes(for mode: SidebarMode) -> [WorkspaceNode] {
        switch mode {
        case .workspace:
            return workspaceNodes
        case .policies:
            return policies.map { policy in
                WorkspaceNode(id: policy.id, name: policy.name, isDirectory: false, children: [])
            }
        case .remote:
            return []
        }
    }

    func fileURL(forNodeID nodeID: String) -> URL? {
        urlByNodeID[nodeID]
    }

    func selectedSidebarNodeID(for mode: SidebarMode) -> String? {
        switch mode {
        case .policies:
            return selectedPolicyID
        case .workspace:
            return selectedFileNodeID
        case .remote:
            return nil
        }
    }

    func handleSidebarSelection(nodeID: String, mode: SidebarMode) {
        switch mode {
        case .policies:
            selectPolicyForEditing(policyID: nodeID)
        case .workspace:
            selectFile(nodeID: nodeID)
        case .remote:
            return
        }
    }

    func selectRemotePreset(_ preset: RemotePreset) {
        guard activeRemoteTargetID != preset.id else {
            return
        }

        if let previousHost = selectedRemoteHost {
            Task { [remoteAccessService] in
                await remoteAccessService.disconnect(from: previousHost)
            }
        }
        cancelRemoteConnection()
        hideRemoteInstaller()
        activeRemoteTargetID = preset.id
        setRemoteStatus(nil)
        refreshRemoteEnvironment()
    }

    func handleRemoteConnectionAction(for preset: RemotePreset) {
        guard !isRemoteInstallerVisible else {
            return
        }

        if activeRemoteTargetID != preset.id {
            selectRemotePreset(preset)
        }

        switch remoteSetupState {
        case .needsSetup:
            guard !trimmedRemoteAccountUsername.isEmpty else {
                setRemoteStatus("Enter your `name.lastname` Salle username first.")
                return
            }
            startRemoteSetup()
        case .settingUp:
            return
        case .ready:
            startRemoteConnection()
        }
    }

    func disconnectRemoteConnection() {
        if let selectedRemoteHost {
            Task { [remoteAccessService] in
                await remoteAccessService.disconnect(from: selectedRemoteHost)
            }
        }
        cancelRemoteConnection()
    }

    func submitRemoteInstallerInput() {
        let trimmedInput = remoteInstallerInput.trimmingCharacters(in: .newlines)
        guard !trimmedInput.isEmpty else {
            return
        }

        let payload = remoteInstallerInput
        remoteInstallerInput = ""
        remoteInstallerPrompt = nil

        Task { [remoteAccessService] in
            await remoteAccessService.sendInstallerInput(payload)
        }
    }

    func cancelRemoteInstaller() {
        Task { [remoteAccessService] in
            await remoteAccessService.cancelPublicKeyInstall()
        }
        hideRemoteInstaller()
        setRemoteStatus("Public key install cancelled.")
    }

    func dismissRemoteInstaller() {
        hideRemoteInstaller()
    }

    func isDirectoryExpanded(_ nodeID: String) -> Bool {
        expandedDirectoryIDs.contains(nodeID)
    }

    func setDirectoryExpanded(_ nodeID: String, isExpanded: Bool) {
        if isExpanded {
            expandedDirectoryIDs.insert(nodeID)
        } else {
            expandedDirectoryIDs.remove(nodeID)
        }
    }

    func selectFile(nodeID: String?) {
        guard let nodeID, let fileURL = urlByNodeID[nodeID], !fileURL.hasDirectoryPath else {
            selectedFileNodeID = nil
            toolbarTitle = workspaceDisplayName
            editorText = ""
            return
        }

        selectedFileNodeID = nodeID
        if openFileNodeIDs.contains(nodeID) == false {
            openFileNodeIDs.append(nodeID)
        }
        toolbarTitle = workspaceDisplayName

        do {
            let fileLoadResult = try workspaceService.readFile(at: fileURL)
            switch fileLoadResult {
            case .text(let text):
                editorText = text
            case .tooLarge, .unsupportedEncoding:
                editorText = ""
            }
        } catch {
            editorText = ""
        }
    }

    var hasWorkspace: Bool {
        workspaceRootURL != nil
    }

    var workspaceDisplayName: String {
        workspaceRootURL?.lastPathComponent ?? "No folder"
    }

    var remotePresets: [RemotePreset] {
        Self.defaultRemotePresets
    }

    var activeRemoteTarget: RemoteTargetSummary? {
        guard let activeRemoteTargetID,
              let preset = remotePresets.first(where: { $0.id == activeRemoteTargetID }) else {
            return nil
        }

        return RemoteTargetSummary(
            id: preset.id,
            title: preset.name,
            primaryText: preset.primaryText,
            secondaryText: preset.secondaryText
        )
    }

    var selectedRemotePreset: RemotePreset? {
        guard let activeRemoteTargetID else {
            return nil
        }

        return remotePresets.first { $0.id == activeRemoteTargetID }
    }

    var selectedRemoteHost: RemoteSSHHost? {
        guard let preset = selectedRemotePreset else {
            return nil
        }

        return RemoteSSHHost(
            alias: preset.name.lowercased(),
            host: preset.primaryText
        )
    }

    var canUseRemoteActions: Bool {
        activeRemoteTarget != nil && remoteConnectionState == .connected
    }

    func remoteButtonLabel(for preset: RemotePreset) -> String {
        let isSelected = activeRemoteTargetID == preset.id
        if !isSelected {
            return remoteSetupState == .ready ? "Connect" : "Set Up"
        }

        switch remoteSetupState {
        case .needsSetup:
            return "Set Up"
        case .settingUp:
            return "Setup"
        case .ready:
            switch remoteConnectionState {
            case .disconnected:
                return "Connect"
            case .connecting:
                return "Joining"
            case .connected:
                return "Connected"
            }
        }
    }

    func isRemoteButtonEnabled(for preset: RemotePreset) -> Bool {
        if isRemoteInstallerVisible {
            return false
        }

        if activeRemoteTargetID == preset.id {
            if remoteSetupState == .settingUp {
                return false
            }

            if remoteConnectionState != .disconnected {
                return false
            }
        }

        if remoteSetupState == .settingUp || remoteConnectionState == .connecting {
            return false
        }

        return true
    }

    var trimmedRemoteAccountUsername: String {
        remoteAccountUsername.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func remoteLoginPreview(for preset: RemotePreset) -> String {
        let username = trimmedRemoteAccountUsername.isEmpty ? "name.lastname" : trimmedRemoteAccountUsername
        return "\(username)@\(preset.primaryText)"
    }

    var remoteOnboardingSteps: [RemoteOnboardingStep] {
        Self.remoteSetupBlueprint.enumerated().map { index, step in
            let state: RemoteOnboardingStep.State
            switch remoteSetupState {
            case .needsSetup:
                state = .pending
            case .settingUp:
                if index < remoteSetupStepIndex {
                    state = .done
                } else if index == remoteSetupStepIndex {
                    state = .active
                } else {
                    state = .pending
                }
            case .ready:
                state = .done
            }

            return RemoteOnboardingStep(
                id: step.id,
                title: step.title,
                detail: step.detail,
                state: state
            )
        }
    }

    var remoteHosts: [RemoteSSHHost] {
        remotePresets.map { preset in
            RemoteSSHHost(
                alias: preset.name.lowercased(),
                host: preset.primaryText
            )
        }
    }

    private var workspaceConfigDirectoryURL: URL? {
        workspaceRootURL?.appendingPathComponent(".autoscan", isDirectory: true)
    }

    var openFileTabs: [EditorFileTab] {
        openFileNodeIDs.compactMap { nodeID in
            guard let fileURL = urlByNodeID[nodeID], !fileURL.hasDirectoryPath else {
                return nil
            }
            return EditorFileTab(
                id: nodeID,
                title: fileURL.lastPathComponent
            )
        }
    }

    var selectedPolicy: PolicyFile? {
        guard let selectedPolicyID else {
            return nil
        }
        return policies.first { $0.id == selectedPolicyID }
    }

    var selectedPolicyDisplayName: String? {
        if let draftName = selectedPolicyDraft?.name.trimmingCharacters(in: .whitespacesAndNewlines), !draftName.isEmpty {
            return draftName
        }

        if let selectedPolicy {
            return selectedPolicy.url.deletingPathExtension().lastPathComponent
        }

        return nil
    }

    var activePolicyName: String? {
        guard let activePolicyID else {
            return nil
        }
        return policies.first { $0.id == activePolicyID }?.name
    }

    var currentRunnablePolicy: PolicyFile? {
        if let selectedPolicy {
            return selectedPolicy
        }

        if let activePolicyID {
            return policies.first { $0.id == activePolicyID }
        }

        return policies.first
    }

    var canRunWorkspace: Bool {
        hasWorkspace && currentRunnablePolicy != nil && !isRunInProgress
    }

    var isPolicyDirty: Bool {
        guard let selectedPolicyDraft, let loadedPolicyDraft, selectedPolicy != nil else {
            return false
        }
        return selectedPolicyDraft != loadedPolicyDraft
    }

    var hasPolicies: Bool {
        !policies.isEmpty
    }

    func clearPolicyBanner() {
        policyBanner = nil
    }

    func clearRunOutput() {
        terminalService.clear()
        runOutputText = terminalService.output
    }

    var selectedPolicyTestCase: PolicyDraft.TestCase? {
        guard
            let selectedPolicyDraft,
            let selectedPolicyTestCaseID
        else {
            return selectedPolicyDraft?.testCases.first
        }

        return selectedPolicyDraft.testCases.first { $0.id == selectedPolicyTestCaseID }
    }

    func updateSelectedPolicyDraft(_ draft: PolicyDraft) {
        clearPolicyBanner()
        selectedPolicyDraft = draft

        if let selectedPolicyTestCaseID,
           draft.testCases.contains(where: { $0.id == selectedPolicyTestCaseID }) == false {
            self.selectedPolicyTestCaseID = draft.testCases.first?.id
        } else if self.selectedPolicyTestCaseID == nil {
            self.selectedPolicyTestCaseID = draft.testCases.first?.id
        }
    }

    func selectPolicyTestCase(id: UUID?) {
        selectedPolicyTestCaseID = id
    }

    func selectPolicyForEditing(policyID: String?) {
        selectedPolicyID = policyID
        clearPolicyBanner()

        guard let policy = selectedPolicy else {
            policyEditorText = ""
            loadedPolicyText = ""
            loadedPolicyDraft = nil
            selectedPolicyDraft = nil
            selectedPolicyTestCaseID = nil
            return
        }

        do {
            let text = try workspaceService.readPolicy(policy)
            loadedPolicyText = text
            policyEditorText = text
            let draft = PolicyDraft.parse(text)
            loadedPolicyDraft = draft
            selectedPolicyDraft = draft
            selectedPolicyTestCaseID = draft.testCases.first?.id
        } catch {
            loadedPolicyText = ""
            policyEditorText = ""
            loadedPolicyDraft = nil
            selectedPolicyDraft = nil
            selectedPolicyTestCaseID = nil
            policyBanner = PolicyBanner(
                kind: .error,
                message: "Couldn't open \(policy.name)."
            )
        }
    }

    func createPolicy(named name: String) {
        guard let workspaceRootURL else {
            policyBanner = PolicyBanner(
                kind: .error,
                message: "Open a workspace before creating a policy."
            )
            return
        }

        let draft = PolicyDraft.starter(named: name)
        let template = draft.serializedYAML()

        do {
            let createdPolicy = try workspaceService.createPolicy(
                named: name,
                content: template,
                in: workspaceRootURL
            )
            reloadWorkspaceAndPolicies(preservePolicySelection: createdPolicy.id)
            selectPolicyForEditing(policyID: createdPolicy.id)
            if activePolicyID == nil {
                activePolicyID = selectedPolicyID
            }
            policyBanner = PolicyBanner(
                kind: .success,
                message: "Created \(createdPolicy.name)."
            )
        } catch {
            policyBanner = PolicyBanner(
                kind: .error,
                message: "Couldn't create that policy."
            )
            return
        }
    }

    func saveSelectedPolicyEdits() {
        guard let policy = selectedPolicy else {
            return
        }

        guard let selectedPolicyDraft else {
            policyBanner = PolicyBanner(
                kind: .error,
                message: "Couldn't load the selected policy draft."
            )
            return
        }

        guard isPolicyDirty else {
            policyBanner = PolicyBanner(
                kind: .info,
                message: "No changes to save."
            )
            return
        }

        if let validationError = validate(selectedPolicyDraft) {
            policyBanner = PolicyBanner(
                kind: .error,
                message: validationError
            )
            return
        }

        do {
            let serializedPolicy = selectedPolicyDraft.serializedYAML()
            try workspaceService.updatePolicy(policy, content: serializedPolicy)
            policyEditorText = serializedPolicy
            reloadWorkspaceAndPolicies(preservePolicySelection: policy.id)
            selectPolicyForEditing(policyID: policy.id)
            policyBanner = PolicyBanner(
                kind: .success,
                message: "Saved \(policy.name)."
            )
        } catch {
            policyBanner = PolicyBanner(
                kind: .error,
                message: "Couldn't save \(policy.name)."
            )
            return
        }
    }

    func renameSelectedPolicy(to name: String) {
        guard let workspaceRootURL else {
            policyBanner = PolicyBanner(
                kind: .error,
                message: "Open a workspace before renaming a policy."
            )
            return
        }

        guard let policy = selectedPolicy else {
            return
        }

        guard var draft = selectedPolicyDraft else {
            policyBanner = PolicyBanner(
                kind: .error,
                message: "Couldn't load the selected policy draft."
            )
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            policyBanner = PolicyBanner(
                kind: .error,
                message: "Policy name is required."
            )
            return
        }

        draft.name = trimmedName
        if let validationError = validate(draft) {
            policyBanner = PolicyBanner(
                kind: .error,
                message: validationError
            )
            return
        }

        let serializedPolicy = draft.serializedYAML()
        let wasActivePolicy = activePolicyID == policy.id

        do {
            let renamedPolicy = try workspaceService.renamePolicy(
                policy,
                to: trimmedName,
                content: serializedPolicy,
                in: workspaceRootURL
            )
            policyEditorText = serializedPolicy
            loadedPolicyText = serializedPolicy
            loadedPolicyDraft = draft
            reloadWorkspaceAndPolicies(preservePolicySelection: renamedPolicy.id)
            selectPolicyForEditing(policyID: renamedPolicy.id)
            if wasActivePolicy {
                activePolicyID = renamedPolicy.id
            }
            policyBanner = PolicyBanner(
                kind: .success,
                message: "Renamed policy to \(trimmedName)."
            )
        } catch {
            policyBanner = PolicyBanner(
                kind: .error,
                message: "Couldn't rename \(policy.name)."
            )
        }
    }

    func revertSelectedPolicyEdits() {
        guard let loadedPolicyDraft, selectedPolicy != nil else {
            return
        }

        selectedPolicyDraft = loadedPolicyDraft
        selectedPolicyTestCaseID = loadedPolicyDraft.testCases.first?.id
        policyBanner = PolicyBanner(
            kind: .info,
            message: "Reverted unsaved changes."
        )
    }

    func deleteSelectedPolicy() {
        guard let policy = selectedPolicy else {
            return
        }

        do {
            try workspaceService.deletePolicy(policy)
            let deletedPolicyID = policy.id
            reloadWorkspaceAndPolicies(preservePolicySelection: nil)

            if activePolicyID == deletedPolicyID {
                activePolicyID = policies.first?.id
            }

            if let firstPolicy = policies.first {
                selectPolicyForEditing(policyID: firstPolicy.id)
            } else {
                selectPolicyForEditing(policyID: nil)
            }
        } catch {
            policyBanner = PolicyBanner(
                kind: .error,
                message: "Couldn't delete \(policy.name)."
            )
            return
        }

        policyBanner = PolicyBanner(
            kind: .success,
            message: "Deleted \(policy.name)."
        )
    }

    func setActivePolicyToSelection() {
        guard let selectedPolicyID else {
            return
        }
        activePolicyID = selectedPolicyID
        if let policy = selectedPolicy {
            policyBanner = PolicyBanner(
                kind: .success,
                message: "\(policy.name) is now active."
            )
        }
    }

    func importLibraryFileToSelectedPolicy() {
        importPolicyResource(
            kind: .library,
            prompt: "Import Library File",
            message: "Choose a file to copy into this workspace's .autoscan/libraries folder."
        ) { draft, importedFileName in
            if draft.libraryFiles.contains(importedFileName) == false {
                draft.libraryFiles.append(importedFileName)
            }
        }
    }

    func importTestFileToSelectedPolicy() {
        importPolicyResource(
            kind: .testFile,
            prompt: "Import Test File",
            message: "Choose a file to copy into this workspace's .autoscan/test_files folder."
        ) { draft, importedFileName in
            if draft.testFiles.contains(importedFileName) == false {
                draft.testFiles.append(importedFileName)
            }
        }
    }

    func importExpectedOutputFileToSelectedTestCase() {
        guard selectedPolicyDraft != nil else {
            policyBanner = PolicyBanner(
                kind: .error,
                message: "Select a policy before importing an expected output."
            )
            return
        }

        guard selectedPolicyTestCase != nil else {
            policyBanner = PolicyBanner(
                kind: .error,
                message: "Select a test case before importing an expected output."
            )
            return
        }

        guard let importedFileName = chooseAndImportPolicyResource(
            kind: .expectedOutput,
            prompt: "Import Expected Output",
            message: "Choose a file to copy into this workspace's .autoscan/expected_outputs folder."
        ) else {
            return
        }

        updateSelectedTestCase { testCase in
            testCase.expectedOutputFile = importedFileName
        }

        policyBanner = PolicyBanner(
            kind: .success,
            message: "Attached \(importedFileName) as the expected output."
        )
    }

    func clearExpectedOutputFileForSelectedTestCase() {
        guard selectedPolicyTestCase != nil else {
            return
        }

        updateSelectedTestCase { testCase in
            testCase.expectedOutputFile = ""
        }

        policyBanner = PolicyBanner(
            kind: .info,
            message: "Cleared the expected output file."
        )
    }

    func runWorkspaceSession() {
        guard !isRunInProgress else {
            return
        }

        guard let workspaceRootURL else {
            policyBanner = PolicyBanner(
                kind: .error,
                message: "Open a workspace before starting a run."
            )
            return
        }

        guard let policy = currentRunnablePolicy else {
            policyBanner = PolicyBanner(
                kind: .error,
                message: "Select or activate a policy before running."
            )
            return
        }

        if isPolicyDirty {
            saveSelectedPolicyEdits()
            guard !isPolicyDirty else {
                return
            }
        }

        currentRunTask?.cancel()
        latestRunReport = nil
        latestRunError = nil
        runStatusMessage = "Running \(policy.name)…"
        isRunInProgress = true
        isOutputVisible = true
        isInspectorVisible = true
        clearRunOutput()
        appendRunOutput("Running workspace \(workspaceRootURL.lastPathComponent) with \(policy.name).")

        let request = RunSessionRequest(
            workspacePath: workspaceRootURL.path,
            policyPath: policy.url.path,
            configDirectoryPath: workspaceConfigDirectoryURL?.path
        )

        currentRunTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let report = try await engineClient.runSession(request: request) { [weak self] event in
                    await MainActor.run {
                        self?.handleRunEvent(event)
                    }
                }

                await MainActor.run {
                    self.latestRunReport = report
                    self.isRunInProgress = false
                    self.runStatusMessage = "Run finished: \(report.summary.totalSubmissions) submissions checked."
                    self.appendRunOutput("Run finished in \(report.summary.durationMs) ms.")
                    self.currentRunTask = nil
                }
            } catch {
                await MainActor.run {
                    self.isRunInProgress = false
                    self.latestRunError = error.localizedDescription
                    self.runStatusMessage = "Run failed"
                    self.appendRunOutput("Run failed: \(error.localizedDescription)")
                    self.policyBanner = PolicyBanner(
                        kind: .error,
                        message: error.localizedDescription
                    )
                    self.currentRunTask = nil
                }
            }
        }
    }

    private func restorePersistedSession() {
        isRestoringSession = true
        defer {
            isRestoringSession = false
        }

        let defaults = UserDefaults.standard

        if let sidebarModeValue = defaults.string(forKey: PersistedKey.sidebarMode),
           let restoredMode = SidebarMode(rawValue: sidebarModeValue) {
            sidebarMode = restoredMode
        }

        if defaults.object(forKey: PersistedKey.isSidebarVisible) != nil {
            isSidebarVisible = defaults.bool(forKey: PersistedKey.isSidebarVisible)
        }

        if defaults.object(forKey: PersistedKey.isInspectorVisible) != nil {
            isInspectorVisible = defaults.bool(forKey: PersistedKey.isInspectorVisible)
        }

        if defaults.object(forKey: PersistedKey.isOutputVisible) != nil {
            isOutputVisible = defaults.bool(forKey: PersistedKey.isOutputVisible)
        }

        if let restoredRemoteTargetID = defaults.string(forKey: PersistedKey.activeRemoteTargetID) {
            activeRemoteTargetID = restoredRemoteTargetID
        }

        if let restoredRemoteAccountUsername = defaults.string(forKey: PersistedKey.remoteAccountUsername) {
            remoteAccountUsername = restoredRemoteAccountUsername
        }

        if activeRemoteTargetID != nil {
            refreshRemoteEnvironment()
        }

        let restoredExpandedDirectoryIDs = Set(defaults.stringArray(forKey: PersistedKey.expandedDirectoryIDs) ?? [])
        let restoredSelectedFileNodeID = defaults.string(forKey: PersistedKey.selectedFileNodeID)

        guard let workspaceBookmark = defaults.data(forKey: PersistedKey.workspaceBookmarkData) else {
            return
        }

        do {
            var isStale = false
            let workspaceURL = try URL(
                resolvingBookmarkData: workspaceBookmark,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            loadWorkspace(
                at: workspaceURL,
                restoredExpandedDirectoryIDs: restoredExpandedDirectoryIDs,
                restoredSelectedFileNodeID: restoredSelectedFileNodeID
            )

            if isStale {
                persistWorkspaceBookmark(for: workspaceURL, force: true)
            }
        } catch {
            clearPersistedWorkspaceState()
        }
    }

    private func persistUserInterfaceState() {
        guard !isRestoringSession else {
            return
        }

        let defaults = UserDefaults.standard
        defaults.set(sidebarMode.rawValue, forKey: PersistedKey.sidebarMode)
        defaults.set(isSidebarVisible, forKey: PersistedKey.isSidebarVisible)
        defaults.set(isInspectorVisible, forKey: PersistedKey.isInspectorVisible)
        defaults.set(isOutputVisible, forKey: PersistedKey.isOutputVisible)
    }

    private func persistWorkspaceSelectionState() {
        guard !isRestoringSession else {
            return
        }

        let defaults = UserDefaults.standard
        defaults.set(Array(expandedDirectoryIDs).sorted(), forKey: PersistedKey.expandedDirectoryIDs)

        if let selectedFileNodeID {
            defaults.set(selectedFileNodeID, forKey: PersistedKey.selectedFileNodeID)
        } else {
            defaults.removeObject(forKey: PersistedKey.selectedFileNodeID)
        }
    }

    private func persistActivePolicySelection() {
        let defaults = UserDefaults.standard
        if let activePolicyID {
            defaults.set(activePolicyID, forKey: PersistedKey.activePolicyID)
        } else {
            defaults.removeObject(forKey: PersistedKey.activePolicyID)
        }
    }

    private func persistActiveRemoteTargetSelection() {
        let defaults = UserDefaults.standard
        if let activeRemoteTargetID {
            defaults.set(activeRemoteTargetID, forKey: PersistedKey.activeRemoteTargetID)
        } else {
            defaults.removeObject(forKey: PersistedKey.activeRemoteTargetID)
        }
    }

    private func persistRemoteAccountUsername() {
        let defaults = UserDefaults.standard
        if trimmedRemoteAccountUsername.isEmpty {
            defaults.removeObject(forKey: PersistedKey.remoteAccountUsername)
        } else {
            defaults.set(trimmedRemoteAccountUsername, forKey: PersistedKey.remoteAccountUsername)
        }
    }

    private func persistWorkspaceBookmark(for rootURL: URL, force: Bool = false) {
        guard force || !isRestoringSession else {
            return
        }

        do {
            let bookmarkData = try rootURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: PersistedKey.workspaceBookmarkData)
        } catch {
            // Keep current session active even if bookmark persistence fails.
        }
    }

    private func clearPersistedWorkspaceState() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: PersistedKey.workspaceBookmarkData)
        defaults.removeObject(forKey: PersistedKey.expandedDirectoryIDs)
        defaults.removeObject(forKey: PersistedKey.selectedFileNodeID)
        defaults.removeObject(forKey: PersistedKey.activePolicyID)
        defaults.removeObject(forKey: PersistedKey.activeRemoteTargetID)
    }

    private func beginAccessingWorkspace(at url: URL) {
        if let activeSecurityScopedWorkspaceURL, activeSecurityScopedWorkspaceURL.path == url.path {
            return
        }

        activeSecurityScopedWorkspaceURL?.stopAccessingSecurityScopedResource()
        activeSecurityScopedWorkspaceURL = nil

        guard url.startAccessingSecurityScopedResource() else {
            return
        }

        activeSecurityScopedWorkspaceURL = url
    }

    private func directoryIDs(in nodes: [WorkspaceNode]) -> Set<String> {
        Set(flattenNodes(nodes).filter(\.isDirectory).map(\.id))
    }

    private func flattenNodes(_ nodes: [WorkspaceNode]) -> [WorkspaceNode] {
        nodes.flatMap { node in
            if node.children.isEmpty {
                return [node]
            }
            return [node] + flattenNodes(node.children)
        }
    }

    private func refreshPolicies() {
        guard let workspaceRootURL else {
            policies = []
            selectedPolicyID = nil
            policyEditorText = ""
            selectedPolicyDraft = nil
            loadedPolicyDraft = nil
            selectedPolicyTestCaseID = nil
            return
        }

        do {
            policies = try workspaceService.listPolicies(in: workspaceRootURL)
        } catch {
            policies = []
        }

        if let selectedPolicyID,
           policies.contains(where: { $0.id == selectedPolicyID }) == false {
            self.selectedPolicyID = nil
            loadedPolicyText = ""
            loadedPolicyDraft = nil
            policyEditorText = ""
            selectedPolicyDraft = nil
            selectedPolicyTestCaseID = nil
        }

        if let activePolicyID,
           policies.contains(where: { $0.id == activePolicyID }) == false {
            self.activePolicyID = nil
        }

        if selectedPolicyID == nil,
           let preferredPolicyID = activePolicyID ?? policies.first?.id {
            selectPolicyForEditing(policyID: preferredPolicyID)
        }
    }

    private func reloadWorkspaceAndPolicies(preservePolicySelection: String?) {
        guard let workspaceRootURL else {
            return
        }

        let currentExpanded = expandedDirectoryIDs
        let currentSelection = selectedFileNodeID
        loadWorkspace(
            at: workspaceRootURL,
            restoredExpandedDirectoryIDs: currentExpanded,
            restoredSelectedFileNodeID: currentSelection
        )

        if let preservePolicySelection,
           policies.contains(where: { $0.id == preservePolicySelection }) {
            selectPolicyForEditing(policyID: preservePolicySelection)
        }
    }

    private func importPolicyResource(
        kind: PolicyResourceKind,
        prompt: String,
        message: String,
        update: (inout PolicyDraft, String) -> Void
    ) {
        guard selectedPolicyDraft != nil else {
            policyBanner = PolicyBanner(
                kind: .error,
                message: "Select a policy before importing files."
            )
            return
        }

        guard let importedFileName = chooseAndImportPolicyResource(
            kind: kind,
            prompt: prompt,
            message: message
        ) else {
            return
        }

        updateDraft { draft in
            update(&draft, importedFileName)
        }

        policyBanner = PolicyBanner(
            kind: .success,
            message: "Imported \(importedFileName)."
        )
    }

    private func chooseAndImportPolicyResource(
        kind: PolicyResourceKind,
        prompt: String,
        message: String
    ) -> String? {
        clearPolicyBanner()

        guard let workspaceRootURL else {
            policyBanner = PolicyBanner(
                kind: .error,
                message: "Open a workspace before importing files."
            )
            return nil
        }

        guard let sourceURL = workspaceService.chooseFileURL(
            prompt: prompt,
            message: message,
            directoryURL: workspaceRootURL
        ) else {
            return nil
        }

        do {
            return try workspaceService.importPolicyResource(
                from: sourceURL,
                kind: kind,
                in: workspaceRootURL
            )
        } catch {
            policyBanner = PolicyBanner(
                kind: .error,
                message: "Couldn't import \(sourceURL.lastPathComponent)."
            )
            return nil
        }
    }

    private func updateDraft(_ mutate: (inout PolicyDraft) -> Void) {
        guard var draft = selectedPolicyDraft else {
            return
        }

        mutate(&draft)
        updateSelectedPolicyDraft(draft)
    }

    private func updateSelectedTestCase(_ mutate: (inout PolicyDraft.TestCase) -> Void) {
        guard
            var draft = selectedPolicyDraft,
            let selectedTestCaseID = selectedPolicyTestCaseID ?? draft.testCases.first?.id,
            let testCaseIndex = draft.testCases.firstIndex(where: { $0.id == selectedTestCaseID })
        else {
            return
        }

        mutate(&draft.testCases[testCaseIndex])
        updateSelectedPolicyDraft(draft)
        selectPolicyTestCase(id: selectedTestCaseID)
    }

    private func validate(_ draft: PolicyDraft) -> String? {
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Policy name is required."
        }

        if draft.sourceFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Source file is required."
        }

        for testCase in draft.testCases {
            let trimmedExit = testCase.expectedExit.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedExit.isEmpty, Int(trimmedExit) == nil {
                let caseName = testCase.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Unnamed test"
                    : testCase.name
                return "\(caseName) has an invalid expected exit code."
            }
        }

        return nil
    }

    private func handleRunEvent(_ event: EngineRunEvent) {
        switch event {
        case .started(let message):
            appendRunOutput(message)
        case .discoveryComplete(let discovery):
            appendRunOutput("Discovered \(discovery.submissionCount) submission(s).")
        case .compileComplete(let compile):
            let status = compile.ok ? "ok" : (compile.timedOut ? "timed out" : "failed")
            appendRunOutput("Compile \(compile.submissionID): \(status) (\(compile.durationMs) ms)")

            if let stderr = compile.stderr?.trimmingCharacters(in: .whitespacesAndNewlines), !stderr.isEmpty {
                appendRunOutput(stderr)
            }
        case .scanComplete(let scan):
            appendRunOutput("Scan \(scan.submissionID): \(scan.bannedHits) banned hit(s)")

            if !scan.parseErrors.isEmpty {
                appendRunOutput(scan.parseErrors.joined(separator: "\n"))
            }
        case .runComplete(let report):
            latestRunReport = report
            latestRunError = nil
            appendRunOutput(
                "Summary: \(report.summary.compilePass) compile pass, \(report.summary.compileFail) fail, \(report.summary.submissionsWithBanned) with banned calls."
            )
        case .error(let message):
            latestRunError = message
            appendRunOutput("Engine error: \(message)")
        }
    }

    private func appendRunOutput(_ line: String) {
        terminalService.append(line)
        runOutputText = terminalService.output
    }

    private func startRemoteSetup() {
        guard activeRemoteTargetID != nil else {
            return
        }

        cancelRemoteOperations()
        remoteSetupState = .settingUp
        remoteConnectionState = .disconnected
        remoteSetupStepIndex = 0
        setRemoteStatus(nil)

        remoteSetupTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let snapshot = try await self.remoteAccessService.performSetup(
                    username: self.trimmedRemoteAccountUsername,
                    hosts: self.remoteHosts
                ) { stepIndex in
                    Task { @MainActor [weak self] in
                        self?.remoteSetupStepIndex = stepIndex
                    }
                }

                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    self.remoteSetupState = snapshot.isConfigured ? .ready : .needsSetup
                    self.applyRemoteEnvironment(snapshot)
                    self.remoteSetupStepIndex = snapshot.isConfigured ? max(Self.remoteSetupBlueprint.count - 1, 0) : 0
                }

                if snapshot.isConfigured {
                    await MainActor.run {
                        self.startRemoteConnection()
                    }
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    self.remoteSetupState = .needsSetup
                    self.remoteConnectionState = .disconnected
                    self.remoteSetupStepIndex = 0
                    self.setRemoteStatus(error.localizedDescription)
                }
            }
        }
    }

    private func startRemoteConnection() {
        guard let selectedRemoteHost, remoteSetupState == .ready else {
            return
        }

        cancelRemoteConnection()
        remoteConnectionState = .connecting
        setRemoteStatus(nil)
        remoteConnectionTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await self.remoteAccessService.connect(to: selectedRemoteHost)
                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    self.remoteConnectionState = .connected
                    self.setRemoteStatus(nil)
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    self.remoteConnectionState = .disconnected
                    if let remoteAccessError = error as? RemoteAccessError,
                       case .publicKeyInstallRequired = remoteAccessError {
                        self.setRemoteStatus("Key login is not ready yet. Enter your La Salle password below and Studio will install the public key for you.")
                        self.startRemotePublicKeyInstall()
                    } else {
                        self.setRemoteStatus(error.localizedDescription)
                    }
                }
            }
        }
    }

    private func cancelRemoteConnection() {
        remoteConnectionTask?.cancel()
        remoteConnectionTask = nil
        remoteConnectionState = .disconnected
    }

    private func cancelRemoteOperations() {
        remoteSetupTask?.cancel()
        remoteSetupTask = nil
        remoteRefreshTask?.cancel()
        remoteRefreshTask = nil
        remoteConnectionTask?.cancel()
        remoteConnectionTask = nil
        remoteInstallerTask?.cancel()
        remoteInstallerTask = nil
    }

    private func refreshRemoteEnvironment() {
        remoteRefreshTask?.cancel()
        remoteRefreshTask = Task { [weak self] in
            guard let self else {
                return
            }

            let snapshot = await self.remoteAccessService.inspectEnvironment(hosts: self.remoteHosts)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self.applyRemoteEnvironment(snapshot)
            }
        }
    }

    private func applyRemoteEnvironment(_ snapshot: RemoteEnvironmentSnapshot) {
        if trimmedRemoteAccountUsername.isEmpty,
           let detectedUsername = snapshot.detectedUsername?.trimmingCharacters(in: .whitespacesAndNewlines),
           !detectedUsername.isEmpty {
            remoteAccountUsername = detectedUsername
        }

        if remoteSetupState != .settingUp {
            remoteSetupState = snapshot.isConfigured ? .ready : .needsSetup
            remoteSetupStepIndex = snapshot.isConfigured ? max(Self.remoteSetupBlueprint.count - 1, 0) : 0
        }

        if !snapshot.isConfigured {
            remoteConnectionState = .disconnected
        }

    }

    private func setRemoteStatus(_ message: String?) {
        let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        remoteStatusMessage = trimmed.isEmpty ? nil : trimmed
    }

    private func startRemotePublicKeyInstall() {
        guard let selectedRemoteHost else {
            return
        }

        remoteInstallerTask?.cancel()
        remoteInstallerOutput = ""
        remoteInstallerInput = ""
        remoteInstallerPrompt = nil
        isRemoteInstallerVisible = true
        isRemoteInstallerRunning = true

        remoteInstallerTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await self.remoteAccessService.startPublicKeyInstall(to: selectedRemoteHost) { event in
                    await MainActor.run {
                        self.handleRemoteInstallerEvent(event)
                    }
                }
            } catch {
                await MainActor.run {
                    self.hideRemoteInstaller()
                    self.setRemoteStatus(error.localizedDescription)
                }
            }
        }
    }

    private func handleRemoteInstallerEvent(_ event: RemoteInstallerEvent) {
        switch event {
        case .output(let chunk):
            if remoteInstallerOutput.isEmpty {
                remoteInstallerOutput = chunk
            } else {
                remoteInstallerOutput += chunk
            }
        case .inputRequested(let prompt):
            remoteInstallerPrompt = prompt
        case .finished(let success, let message):
            isRemoteInstallerRunning = false
            remoteInstallerTask = nil
            remoteInstallerPrompt = nil
            if let message {
                setRemoteStatus(message)
            }

            if success {
                hideRemoteInstaller()
                refreshRemoteEnvironment()
                startRemoteConnection()
            }
        }
    }

    private func hideRemoteInstaller() {
        remoteInstallerOutput = ""
        remoteInstallerInput = ""
        remoteInstallerPrompt = nil
        isRemoteInstallerVisible = false
        isRemoteInstallerRunning = false
    }

}

private enum PersistedKey {
    static let workspaceBookmarkData = "studio.session.workspaceBookmarkData"
    static let sidebarMode = "studio.session.sidebarMode"
    static let isSidebarVisible = "studio.session.isSidebarVisible"
    static let isInspectorVisible = "studio.session.isInspectorVisible"
    static let isOutputVisible = "studio.session.isOutputVisible"
    static let expandedDirectoryIDs = "studio.session.expandedDirectoryIDs"
    static let selectedFileNodeID = "studio.session.selectedFileNodeID"
    static let activePolicyID = "studio.session.activePolicyID"
    static let activeRemoteTargetID = "studio.session.activeRemoteTargetID"
    static let remoteAccountUsername = "studio.remote.accountUsername"
}

struct EditorFileTab: Identifiable, Equatable {
    let id: String
    let title: String
}

private extension StudioAppState {
    static let remoteSetupBlueprint: [(id: String, title: String, detail: String)] = [
        (
            id: "permission",
            title: "Use `~/.ssh`",
            detail: "macOS asks for one-time access to your existing `~/.ssh` folder so Studio can reuse it."
        ),
        (
            id: "key",
            title: "Reuse or create SSH key",
            detail: "Studio reuses your shared Salle key when it exists, or creates one automatically if it doesn't."
        ),
        (
            id: "alias",
            title: "Register terminal aliases",
            detail: "Write the Montserrat, Matagalls, and Puigpedros aliases so the same setup works in Studio and Terminal."
        )
    ]

    static let defaultRemotePresets: [RemotePreset] = [
        RemotePreset(
            id: "preset:montserrat",
            name: "Montserrat",
            primaryText: "montserrat.salle.url.edu",
            secondaryText: "name.lastname@montserrat.salle.url.edu"
        ),
        RemotePreset(
            id: "preset:matagalls",
            name: "Matagalls",
            primaryText: "matagalls.salle.url.edu",
            secondaryText: "name.lastname@matagalls.salle.url.edu"
        ),
        RemotePreset(
            id: "preset:puigpedros",
            name: "Puigpedros",
            primaryText: "puigpedros.salle.url.edu",
            secondaryText: "name.lastname@puigpedros.salle.url.edu"
        )
    ]
}
