import AppKit
import Combine
import Foundation

@MainActor
final class StudioAppState: ObservableObject {
    enum SidebarMode: String, CaseIterable, Identifiable {
        case workspace = "Workspace"
        case policies = "Policies"
        case runs = "Runs"

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
    @Published var policyEditorText = ""

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

    private let engineClient: EngineClient
    private let workspaceService: WorkspaceService
    private let terminalService: TerminalService
    private let sshProfileStore: SSHProfileStore

    private var isRestoringSession = false
    private var activeSecurityScopedWorkspaceURL: URL?

    init(
        engineClient: EngineClient = PlaceholderEngineClient(),
        workspaceService: WorkspaceService = LocalWorkspaceService(),
        terminalService: TerminalService = InMemoryTerminalService(),
        sshProfileStore: SSHProfileStore = InMemorySSHProfileStore()
    ) {
        self.engineClient = engineClient
        self.workspaceService = workspaceService
        self.terminalService = terminalService
        self.sshProfileStore = sshProfileStore
        restorePersistedSession()
    }

    deinit {
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

        persistWorkspaceBookmark(for: rootURL)
    }

    func nodes(for mode: SidebarMode) -> [WorkspaceNode] {
        switch mode {
        case .workspace:
            return workspaceNodes
        case .policies:
            return flatFileNodes(matching: { $0.hasSuffix(".yaml") || $0.contains("policy") })
        case .runs:
            return flatFileNodes(matching: { $0.contains("report") || $0.contains("run") })
        }
    }

    func fileURL(forNodeID nodeID: String) -> URL? {
        urlByNodeID[nodeID]
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

    var activePolicyName: String? {
        guard let activePolicyID else {
            return nil
        }
        return policies.first { $0.id == activePolicyID }?.name
    }

    func selectPolicyForEditing(policyID: String?) {
        selectedPolicyID = policyID

        guard let policy = selectedPolicy else {
            policyEditorText = ""
            return
        }

        do {
            policyEditorText = try workspaceService.readPolicy(policy)
        } catch {
            policyEditorText = ""
        }
    }

    func createPolicy(named name: String) {
        guard let workspaceRootURL else {
            return
        }

        let template = """
        # \(name)
        checks:
          - compile: true
        """

        do {
            let createdPolicy = try workspaceService.createPolicy(
                named: name,
                content: template + "\n",
                in: workspaceRootURL
            )
            reloadWorkspaceAndPolicies(preservePolicySelection: createdPolicy.id)
            selectPolicyForEditing(policyID: createdPolicy.id)
            if activePolicyID == nil {
                activePolicyID = selectedPolicyID
            }
        } catch {
            return
        }
    }

    func saveSelectedPolicyEdits() {
        guard let policy = selectedPolicy else {
            return
        }

        do {
            try workspaceService.updatePolicy(policy, content: policyEditorText)
            reloadWorkspaceAndPolicies(preservePolicySelection: policy.id)
            selectedPolicyID = policy.id
        } catch {
            return
        }
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
            return
        }
    }

    func setActivePolicyToSelection() {
        guard let selectedPolicyID else {
            return
        }
        activePolicyID = selectedPolicyID
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

    private func flatFileNodes(matching predicate: (String) -> Bool) -> [WorkspaceNode] {
        let allFileNodes = flattenNodes(workspaceNodes)
            .filter { !$0.isDirectory && predicate($0.id) }
            .sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }

        return allFileNodes.map { node in
            WorkspaceNode(id: node.id, name: node.id, isDirectory: false, children: [])
        }
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
            policyEditorText = ""
        }

        if let activePolicyID,
           policies.contains(where: { $0.id == activePolicyID }) == false {
            self.activePolicyID = nil
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
            selectedPolicyID = preservePolicySelection
        }
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
}

struct EditorFileTab: Identifiable, Equatable {
    let id: String
    let title: String
}
