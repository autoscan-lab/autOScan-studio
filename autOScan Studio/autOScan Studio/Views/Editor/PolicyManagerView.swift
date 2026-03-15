import SwiftUI

struct PolicyManagerView: View {
    @ObservedObject var state: StudioAppState

    @State private var newPolicyName = ""
    @State private var showingCreateSheet = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 0) {
            policyListPane
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 320)

            Rectangle()
                .fill(StudioTheme.separator)
                .frame(width: 1)

            editorPane
        }
        .background(StudioTheme.editor)
    }

    private var policyListPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Policies")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)

                Spacer(minLength: 0)

                if let activePolicyName = state.activePolicyName {
                    Text("Active: \(activePolicyName)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(StudioTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if state.policies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No policies yet.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(StudioTheme.textSecondary)
                    Text("Create one to start grading with a policy.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(StudioTheme.textSecondary.opacity(0.8))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)

                Spacer(minLength: 0)
            } else {
                List(selection: policySelectionBinding) {
                    ForEach(state.policies, id: \.id) { policy in
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .foregroundStyle(StudioTheme.textSecondary)
                            Text(policy.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(StudioTheme.textPrimary)
                                .lineLimit(1)
                            if state.activePolicyID == policy.id {
                                Spacer(minLength: 0)
                                Text("Active")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(StudioTheme.accent)
                            }
                        }
                        .tag(policy.id)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.inset)
                .background(StudioTheme.editor)
            }

            HStack(spacing: 8) {
                Button("New") {
                    newPolicyName = ""
                    showingCreateSheet = true
                }
                .buttonStyle(.bordered)

                Button("Delete") {
                    showingDeleteConfirmation = true
                }
                .buttonStyle(.bordered)
                .disabled(state.selectedPolicy == nil)

                Spacer(minLength: 0)

                Button("Set Active") {
                    state.setActivePolicyToSelection()
                }
                .buttonStyle(.borderedProminent)
                .tint(StudioTheme.accent)
                .disabled(state.selectedPolicy == nil)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
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
        .background(StudioTheme.editor)
    }

    private var editorPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let selectedPolicy = state.selectedPolicy {
                    Text(selectedPolicy.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(StudioTheme.textPrimary)
                } else {
                    Text("Select a policy")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(StudioTheme.textSecondary)
                }

                Spacer(minLength: 0)

                Button("Save") {
                    state.saveSelectedPolicyEdits()
                }
                .buttonStyle(.borderedProminent)
                .tint(StudioTheme.accent)
                .disabled(state.selectedPolicy == nil)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Rectangle()
                .fill(StudioTheme.separator)
                .frame(height: 1)

            if state.selectedPolicy == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No policy selected")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(StudioTheme.textSecondary)
                    Text("Choose a policy from the left to edit it.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(StudioTheme.textSecondary.opacity(0.8))
                }
                .padding(16)

                Spacer(minLength: 0)
            } else {
                TextEditor(text: $state.policyEditorText)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(StudioTheme.textPrimary)
                    .padding(12)
                    .background(StudioTheme.editor)
            }
        }
        .background(StudioTheme.editor)
    }

    private var createPolicySheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Create Policy")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(StudioTheme.textPrimary)

            TextField("Policy name", text: $newPolicyName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer(minLength: 0)
                Button("Cancel") {
                    showingCreateSheet = false
                }
                Button("Create") {
                    state.createPolicy(named: newPolicyName)
                    showingCreateSheet = false
                }
                .buttonStyle(.borderedProminent)
                .tint(StudioTheme.accent)
                .disabled(newPolicyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 360)
        .background(StudioTheme.pane)
    }

    private var policySelectionBinding: Binding<String?> {
        Binding(
            get: { state.selectedPolicyID },
            set: { state.selectPolicyForEditing(policyID: $0) }
        )
    }
}
