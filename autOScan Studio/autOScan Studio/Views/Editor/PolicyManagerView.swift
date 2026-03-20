import SwiftUI

struct PolicyManagerView: View {
    private enum PolicySheet: String, Identifiable {
        case create
        case rename

        var id: String { rawValue }
    }

    private enum PolicySection: String, CaseIterable, Hashable {
        case compile
        case resources
        case testCases
    }

    @ObservedObject var state: StudioAppState

    @FocusState private var isPolicyNameFocused: Bool
    @State private var policyNameInput = ""
    @State private var activeSheet: PolicySheet?
    @State private var showingDeleteConfirmation = false
    @State private var expandedSections = Set(PolicySection.allCases)

    var body: some View {
        VStack(spacing: 0) {
            actionBar

            if let banner = state.policyBanner {
                policyBannerView(banner)
            }

            Rectangle()
                .fill(StudioTheme.separator)
                .frame(height: 1)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(StudioTheme.editor)
        .sheet(item: $activeSheet) { sheet in
            policyNameSheet(for: sheet)
        }
        .alert("Delete policy?", isPresented: $showingDeleteConfirmation, presenting: state.selectedPolicy) { selectedPolicy in
            Button("Delete", role: .destructive) {
                state.deleteSelectedPolicy()
            }
            Button("Cancel", role: .cancel) { }
        } message: { selectedPolicy in
            Text("This will permanently delete \(selectedPolicy.name).")
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("New Policy", action: presentCreateSheet)
                .buttonStyle(.bordered)

            Button("Rename", action: presentRenameSheet)
                .buttonStyle(.bordered)
                .disabled(state.selectedPolicy == nil)

            Button("Delete") {
                showingDeleteConfirmation = true
            }
            .buttonStyle(.bordered)
            .disabled(state.selectedPolicy == nil)

            Button("Set Active") {
                state.setActivePolicyToSelection()
            }
            .buttonStyle(.bordered)
            .disabled(state.selectedPolicy == nil || state.selectedPolicyID == state.activePolicyID)

            Spacer(minLength: 0)

            Button("Revert") {
                state.revertSelectedPolicyEdits()
            }
            .buttonStyle(.bordered)
            .disabled(!state.isPolicyDirty)

            Button("Save") {
                state.saveSelectedPolicyEdits()
            }
            .buttonStyle(.borderedProminent)
            .tint(StudioTheme.accent)
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(state.selectedPolicy == nil || !state.isPolicyDirty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if !state.hasPolicies {
            emptyPoliciesState
        } else if state.selectedPolicyDraft != nil {
            formContent
        } else {
            unselectedState
        }
    }

    private var emptyPoliciesState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No policies yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(StudioTheme.textPrimary)

            Text("Create a policy to define compile flags, source files, linked resources, and test cases for a grading run.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(StudioTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Create First Policy", action: presentCreateSheet)
                .buttonStyle(.borderedProminent)
                .tint(StudioTheme.accent)
        }
        .padding(18)
    }

    private var unselectedState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select a policy")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(StudioTheme.textPrimary)

            Text("Choose a policy from the sidebar to edit it here.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(StudioTheme.textSecondary)
        }
        .padding(18)
    }

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                compileSection
                resourcesSection
                testCasesSection
            }
            .padding(16)
        }
    }

    private var compileSection: some View {
        sectionCard(section: .compile, title: "Compile", systemImage: "hammer") {
            HStack(alignment: .top, spacing: 12) {
                labeledField("Source File") {
                    TextField("main.c", text: draftBinding(\.sourceFile, default: ""))
                        .textFieldStyle(.roundedBorder)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                labeledField("Flags") {
                    FlagTextField(
                        flags: state.selectedPolicyDraft?.flags ?? [],
                        placeholder: "-Wall -Wextra"
                    ) { updatedFlags in
                        updateDraft { $0.flags = updatedFlags }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private var resourcesSection: some View {
        sectionCard(section: .resources, title: "Resources", systemImage: "tray.full") {
            HStack(alignment: .top, spacing: 12) {
                importedFileList(
                    title: "Library Files",
                    items: draftStrings(\.libraryFiles),
                    helperText: "Imported files are copied into `.autoscan/libraries` for this workspace.",
                    addLabel: "Import Library File",
                    emptyMessage: "No library files linked yet.",
                    onAdd: {
                        state.importLibraryFileToSelectedPolicy()
                    },
                    onRemove: { index in
                        updateDraft { draft in
                            draft.libraryFiles.remove(at: index)
                        }
                    }
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)

                importedFileList(
                    title: "Test Files",
                    items: draftStrings(\.testFiles),
                    helperText: "Imported files are copied into `.autoscan/test_files` for this workspace.",
                    addLabel: "Import Test File",
                    emptyMessage: "No test files linked yet.",
                    onAdd: {
                        state.importTestFileToSelectedPolicy()
                    },
                    onRemove: { index in
                        updateDraft { draft in
                            draft.testFiles.remove(at: index)
                        }
                    }
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private var testCasesSection: some View {
        sectionCard(section: .testCases, title: "Test Cases", systemImage: "checklist") {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Cases")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(StudioTheme.textPrimary)

                        Spacer(minLength: 0)

                        Button("Add") {
                            addTestCase()
                        }
                        .buttonStyle(.bordered)

                        Button("Remove") {
                            removeSelectedTestCase()
                        }
                        .buttonStyle(.bordered)
                        .disabled(state.selectedPolicyTestCase == nil)
                    }

                    List(selection: selectedTestCaseSelectionBinding) {
                        ForEach(state.selectedPolicyDraft?.testCases ?? []) { testCase in
                            Text(testCase.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Test" : testCase.name)
                                .tag(Optional(testCase.id))
                        }
                    }
                    .frame(minWidth: 220, idealWidth: 240, maxWidth: 260, minHeight: 240)
                    .scrollContentBackground(.hidden)
                    .listStyle(.inset)
                    .background(StudioTheme.editor)
                }

                Rectangle()
                    .fill(StudioTheme.separator.opacity(0.72))
                    .frame(width: 1)

                VStack(alignment: .leading, spacing: 12) {
                    if state.selectedPolicyTestCase != nil {
                        labeledField("Name") {
                            TextField("No args", text: selectedTestCaseBinding(\.name, default: ""))
                                .textFieldStyle(.roundedBorder)
                        }

                        labeledField("Argument") {
                            TextField("--count", text: selectedTestCaseArgumentBinding)
                                .textFieldStyle(.roundedBorder)
                        }

                        labeledField("Standard Input") {
                            standardInputEditor
                        }

                        HStack(alignment: .top, spacing: 12) {
                            labeledField("Expected Exit") {
                                TextField("0", text: selectedTestCaseBinding(\.expectedExit, default: ""))
                                    .textFieldStyle(.roundedBorder)
                            }

                            labeledField("Expected Output File") {
                                selectedExpectedOutputPicker
                            }
                        }
                    } else {
                        Text("Add a test case to configure runtime inputs and expectations.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(StudioTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private var standardInputEditor: some View {
        let inputBinding = selectedTestCaseBinding(\.input, default: "")
        let currentInput = inputBinding.wrappedValue

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(StudioTheme.accent.opacity(0.10))

            if currentInput.isEmpty {
                Text("Type stdin here…")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
            }

            TextEditor(text: inputBinding)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.clear)
        }
        .frame(minHeight: 96)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(StudioTheme.accent.opacity(0.35), lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 8))
    }

    private func importedFileList(
        title: String,
        items: [String],
        helperText: String,
        addLabel: String,
        emptyMessage: String,
        onAdd: @escaping () -> Void,
        onRemove: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)

                Spacer(minLength: 0)

                Button(addLabel, action: onAdd)
                    .buttonStyle(.bordered)
            }

            Text(helperText)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(StudioTheme.textSecondary)

            if items.isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(StudioTheme.textSecondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, value in
                        HStack(spacing: 8) {
                            Image(systemName: "doc")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(StudioTheme.textSecondary)

                            Text(value)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(StudioTheme.textPrimary)
                                .lineLimit(1)

                            Spacer(minLength: 0)

                            Button {
                                onRemove(index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(StudioTheme.textPrimary)

            content()
        }
    }

    private func sectionCard<Content: View>(
        section: PolicySection,
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isExpanded = expandedSections.contains(section)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                toggleSection(section)
            } label: {
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: systemImage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(StudioTheme.accent)

                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(StudioTheme.textPrimary)
                    }
                    .transaction { transaction in
                        transaction.animation = nil
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(StudioTheme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isExpanded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .padding(.top, 12)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                        )
                    )
            }
        }
        .padding(14)
        .background(StudioTheme.pane)
        .clipShape(.rect(cornerRadius: 10))
    }

    private func policyBannerView(_ banner: StudioAppState.PolicyBanner) -> some View {
        HStack(spacing: 10) {
            Image(systemName: iconName(for: banner.kind))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(bannerColor(for: banner.kind))

            Text(banner.message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(StudioTheme.textPrimary)

            Spacer(minLength: 0)

            Button {
                state.clearPolicyBanner()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(bannerColor(for: banner.kind).opacity(0.12))
    }

    private func policyNameSheet(for sheet: PolicySheet) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(sheet == .create ? "Create Policy" : "Rename Policy")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(StudioTheme.textPrimary)

            Text(
                sheet == .create
                ? "A starter policy will be created under `policies/` in the current workspace."
                : "This updates the policy name and renames the saved policy file in `policies/`."
            )
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(StudioTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

            TextField("Policy name", text: $policyNameInput)
                .textFieldStyle(.roundedBorder)
                .focused($isPolicyNameFocused)
                .onSubmit {
                    submitPolicyNameSheet(sheet)
                }

            HStack {
                Spacer(minLength: 0)

                Button("Cancel") {
                    activeSheet = nil
                }

                Button(sheet == .create ? "Create" : "Rename") {
                    submitPolicyNameSheet(sheet)
                }
                .buttonStyle(.borderedProminent)
                .tint(StudioTheme.accent)
                .keyboardShortcut(.defaultAction)
                .disabled(policyNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 380)
        .background(StudioTheme.pane)
        .onAppear {
            DispatchQueue.main.async {
                isPolicyNameFocused = true
            }
        }
    }

    private func presentCreateSheet() {
        policyNameInput = ""
        activeSheet = .create
    }

    private func presentRenameSheet() {
        guard let selectedPolicyName = state.selectedPolicyDisplayName else {
            return
        }

        policyNameInput = selectedPolicyName
        activeSheet = .rename
    }

    private func submitPolicyNameSheet(_ sheet: PolicySheet) {
        let trimmedName = policyNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        switch sheet {
        case .create:
            state.createPolicy(named: trimmedName)
        case .rename:
            state.renameSelectedPolicy(to: trimmedName)
        }

        activeSheet = nil
    }

    private func draftBinding<Value>(
        _ keyPath: WritableKeyPath<PolicyDraft, Value>,
        default defaultValue: Value
    ) -> Binding<Value> {
        Binding(
            get: { state.selectedPolicyDraft?[keyPath: keyPath] ?? defaultValue },
            set: { newValue in
                updateDraft { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private func draftStrings(_ keyPath: KeyPath<PolicyDraft, [String]>) -> [String] {
        state.selectedPolicyDraft?[keyPath: keyPath] ?? []
    }

    private func updateDraft(_ mutate: (inout PolicyDraft) -> Void) {
        guard var draft = state.selectedPolicyDraft else {
            return
        }

        mutate(&draft)
        state.updateSelectedPolicyDraft(draft)
    }

    private func selectedTestCaseBinding<Value>(
        _ keyPath: WritableKeyPath<PolicyDraft.TestCase, Value>,
        default defaultValue: Value
    ) -> Binding<Value> {
        Binding(
            get: { state.selectedPolicyTestCase?[keyPath: keyPath] ?? defaultValue },
            set: { newValue in
                updateSelectedTestCase { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private var selectedTestCaseSelectionBinding: Binding<UUID?> {
        Binding(
            get: { state.selectedPolicyTestCaseID ?? state.selectedPolicyDraft?.testCases.first?.id },
            set: { state.selectPolicyTestCase(id: $0) }
        )
    }

    private var selectedTestCaseArgumentBinding: Binding<String> {
        Binding(
            get: { state.selectedPolicyTestCase?.singleArgument ?? "" },
            set: { newValue in
                updateSelectedTestCase { testCase in
                    if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        testCase.args = []
                    } else {
                        testCase.args = [newValue]
                    }
                }
            }
        )
    }

    private var selectedExpectedOutputPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            let selectedFileName = state.selectedPolicyTestCase?.expectedOutputFile.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            Text(selectedFileName.isEmpty ? "No file selected" : selectedFileName)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(selectedFileName.isEmpty ? StudioTheme.textSecondary : StudioTheme.textPrimary)

            HStack(spacing: 8) {
                Button("Choose File…") {
                    state.importExpectedOutputFileToSelectedTestCase()
                }
                .buttonStyle(.bordered)

                Button("Clear") {
                    state.clearExpectedOutputFileForSelectedTestCase()
                }
                .buttonStyle(.bordered)
                .disabled(selectedFileName.isEmpty)
            }
        }
    }

    private func updateSelectedTestCase(_ mutate: (inout PolicyDraft.TestCase) -> Void) {
        guard
            var draft = state.selectedPolicyDraft,
            let selectedTestCaseID = state.selectedPolicyTestCaseID ?? draft.testCases.first?.id,
            let testCaseIndex = draft.testCases.firstIndex(where: { $0.id == selectedTestCaseID })
        else {
            return
        }

        mutate(&draft.testCases[testCaseIndex])
        state.updateSelectedPolicyDraft(draft)
        state.selectPolicyTestCase(id: selectedTestCaseID)
    }

    private func addTestCase() {
        updateDraft { draft in
            let newTestCase = PolicyDraft.TestCase(
                name: "New Test",
                expectedExit: "0"
            )
            draft.testCases.append(newTestCase)
            state.selectPolicyTestCase(id: newTestCase.id)
        }
    }

    private func removeSelectedTestCase() {
        guard
            let selectedTestCaseID = state.selectedPolicyTestCaseID,
            var draft = state.selectedPolicyDraft,
            let testCaseIndex = draft.testCases.firstIndex(where: { $0.id == selectedTestCaseID })
        else {
            return
        }

        draft.testCases.remove(at: testCaseIndex)
        if draft.testCases.isEmpty {
            draft.testCases = [PolicyDraft.TestCase(name: "No args", expectedExit: "0")]
        }

        state.updateSelectedPolicyDraft(draft)
        state.selectPolicyTestCase(id: draft.testCases.first?.id)
    }

    private func toggleSection(_ section: PolicySection) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }

    private func bannerColor(for kind: StudioAppState.PolicyBanner.Kind) -> Color {
        switch kind {
        case .success:
            return .green
        case .error:
            return .red
        case .info:
            return StudioTheme.accent
        }
    }

    private func iconName(for kind: StudioAppState.PolicyBanner.Kind) -> String {
        switch kind {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
}

private struct FlagTextField: View {
    let flags: [String]
    let placeholder: String
    let onUpdate: ([String]) -> Void

    @FocusState private var isFocused: Bool
    @State private var text = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.roundedBorder)
            .focused($isFocused)
            .onAppear {
                text = flags.joined(separator: " ")
            }
            .onChange(of: flags) { _, newFlags in
                if !isFocused {
                    text = newFlags.joined(separator: " ")
                }
            }
            .onChange(of: text) { _, newValue in
                onUpdate(Self.parseFlags(from: newValue))
            }
    }

    private static func parseFlags(from text: String) -> [String] {
        text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }
}
