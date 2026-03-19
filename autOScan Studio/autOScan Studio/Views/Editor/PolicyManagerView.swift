import SwiftUI

struct PolicyManagerView: View {
    @ObservedObject var state: StudioAppState

    @FocusState private var isCreateNameFocused: Bool
    @State private var newPolicyName = ""
    @State private var showingCreateSheet = false
    @State private var showingDeleteConfirmation = false

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
        .sheet(isPresented: $showingCreateSheet) {
            createPolicySheet
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
            Button("New Policy") {
                newPolicyName = ""
                showingCreateSheet = true
            }
            .buttonStyle(.bordered)

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

            Button(state.isRunInProgress ? "Running…" : "Run Workspace") {
                state.runWorkspaceSession()
            }
            .buttonStyle(.borderedProminent)
            .tint(state.isRunInProgress ? .gray : StudioTheme.accent)
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(!state.canRunWorkspace)

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

            Button("Create First Policy") {
                newPolicyName = ""
                showingCreateSheet = true
            }
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
                metadataCard
                generalSection
                compileSection
                resourcesSection
                testCasesSection
            }
            .padding(16)
        }
    }

    private var metadataCard: some View {
        sectionCard(title: "Policy", systemImage: "doc.text") {
            VStack(alignment: .leading, spacing: 8) {
                if let selectedPolicy = state.selectedPolicy {
                    HStack(spacing: 8) {
                        Text(selectedPolicy.id)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(StudioTheme.textSecondary)
                            .lineLimit(1)

                        if state.activePolicyID == selectedPolicy.id {
                            badge("Active", tint: StudioTheme.accent)
                        }

                        if state.isPolicyDirty {
                            badge("Unsaved", tint: .orange)
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var generalSection: some View {
        sectionCard(title: "General", systemImage: "slider.horizontal.3") {
            labeledField("Name") {
                TextField("Lab 03 - Processes", text: draftBinding(\.name, default: ""))
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var compileSection: some View {
        sectionCard(title: "Compile", systemImage: "hammer") {
            VStack(alignment: .leading, spacing: 12) {
                labeledField("Compiler") {
                    TextField("gcc", text: draftBinding(\.gcc, default: "gcc"))
                        .textFieldStyle(.roundedBorder)
                }

                labeledField("Source File") {
                    TextField("main.c", text: draftBinding(\.sourceFile, default: ""))
                        .textFieldStyle(.roundedBorder)
                }

                editableStringList(
                    title: "Flags",
                    items: draftStrings(\.flags),
                    placeholder: "-Wall",
                    addLabel: "Add Flag",
                    onUpdate: { items in
                        updateDraft { $0.flags = items }
                    }
                )
            }
        }
    }

    private var resourcesSection: some View {
        sectionCard(title: "Resources", systemImage: "tray.full") {
            VStack(alignment: .leading, spacing: 12) {
                editableStringList(
                    title: "Library Files",
                    items: draftStrings(\.libraryFiles),
                    placeholder: "hospital.o",
                    addLabel: "Add Library File",
                    onUpdate: { items in
                        updateDraft { $0.libraryFiles = items }
                    }
                )

                editableStringList(
                    title: "Test Files",
                    items: draftStrings(\.testFiles),
                    placeholder: "input.txt",
                    addLabel: "Add Test File",
                    onUpdate: { items in
                        updateDraft { $0.testFiles = items }
                    }
                )
            }
        }
    }

    private var testCasesSection: some View {
        sectionCard(title: "Test Cases", systemImage: "checklist") {
            HStack(spacing: 14) {
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

                        editableStringList(
                            title: "Arguments",
                            items: state.selectedPolicyTestCase?.args ?? [],
                            placeholder: "--count",
                            addLabel: "Add Arg",
                            onUpdate: { items in
                                updateSelectedTestCase { $0.args = items }
                            }
                        )

                        labeledField("Standard Input") {
                            TextEditor(text: selectedTestCaseBinding(\.input, default: ""))
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 90)
                                .padding(8)
                                .background(StudioTheme.pane)
                                .clipShape(.rect(cornerRadius: 8))
                        }

                        HStack(alignment: .top, spacing: 12) {
                            labeledField("Expected Exit") {
                                TextField("0", text: selectedTestCaseBinding(\.expectedExit, default: ""))
                                    .textFieldStyle(.roundedBorder)
                            }

                            labeledField("Expected Output File") {
                                TextField("expected.txt", text: selectedTestCaseBinding(\.expectedOutputFile, default: ""))
                                    .textFieldStyle(.roundedBorder)
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

    private func editableStringList(
        title: String,
        items: [String],
        placeholder: String,
        addLabel: String,
        onUpdate: @escaping ([String]) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)

                Spacer(minLength: 0)

                Button(addLabel) {
                    var updatedItems = items
                    updatedItems.append("")
                    onUpdate(updatedItems)
                }
                .buttonStyle(.bordered)
            }

            if items.isEmpty {
                Text("None")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(StudioTheme.textSecondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, value in
                        HStack(spacing: 8) {
                            TextField(
                                placeholder,
                                text: Binding(
                                    get: { value },
                                    set: { newValue in
                                        var updatedItems = items
                                        updatedItems[index] = newValue
                                        onUpdate(updatedItems)
                                    }
                                )
                            )
                            .textFieldStyle(.roundedBorder)

                            Button {
                                var updatedItems = items
                                updatedItems.remove(at: index)
                                onUpdate(updatedItems)
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
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StudioTheme.accent)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)
            }

            content()
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

    private var createPolicySheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Create Policy")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(StudioTheme.textPrimary)

            Text("A starter policy will be created under `policies/` in the current workspace.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(StudioTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Policy name", text: $newPolicyName)
                .textFieldStyle(.roundedBorder)
                .focused($isCreateNameFocused)
                .onSubmit {
                    createPolicyFromSheet()
                }

            HStack {
                Spacer(minLength: 0)

                Button("Cancel") {
                    showingCreateSheet = false
                }

                Button("Create") {
                    createPolicyFromSheet()
                }
                .buttonStyle(.borderedProminent)
                .tint(StudioTheme.accent)
                .keyboardShortcut(.defaultAction)
                .disabled(newPolicyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 380)
        .background(StudioTheme.pane)
        .onAppear {
            DispatchQueue.main.async {
                isCreateNameFocused = true
            }
        }
    }

    private func createPolicyFromSheet() {
        let trimmedName = newPolicyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }

        state.createPolicy(named: trimmedName)
        showingCreateSheet = false
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

    private func badge(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14))
            .clipShape(.rect(cornerRadius: 6))
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
