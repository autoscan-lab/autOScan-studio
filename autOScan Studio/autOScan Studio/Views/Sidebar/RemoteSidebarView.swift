import SwiftUI

struct RemoteSidebarView: View {
    @ObservedObject var state: StudioAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                universityPresetsSection
                remoteActionsSection
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(StudioTheme.sidebar)
    }

    private var universityPresetsSection: some View {
        sectionCard(title: "University Servers", systemImage: "network") {
            VStack(spacing: 8) {
                ForEach(state.remotePresets) { preset in
                    let isActive = state.activeRemoteTarget?.id == preset.id
                    let isActionEnabled = state.isRemoteButtonEnabled(for: preset)

                    HStack(spacing: 10) {
                        Text(preset.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(StudioTheme.textPrimary)

                        Spacer(minLength: 0)

                        Button(state.remoteButtonLabel(for: preset)) {
                            state.handleRemoteConnectionAction(for: preset)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(tagForegroundStyle(isActive: isActive, isEnabled: isActionEnabled))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 999, style: .continuous)
                                .fill(tagBackgroundStyle(isActive: isActive, isEnabled: isActionEnabled))
                        )
                        .disabled(!isActionEnabled)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isActive ? StudioTheme.selection.opacity(0.72) : StudioTheme.editor.opacity(0.7))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onTapGesture {
                        state.selectRemotePreset(preset)
                    }
                }
            }
        }
    }

    private var remoteActionsSection: some View {
        sectionCard(title: "Remote Actions", systemImage: "arrow.up.arrow.down") {
            VStack(alignment: .leading, spacing: 10) {
                remoteActionRow(
                    title: "Upload Folder",
                    prominence: .primary,
                    isEnabled: state.canUseRemoteActions && state.hasWorkspace,
                    helpText: uploadFolderHelpText,
                    hint: "Send workspace"
                )

                remoteActionRow(
                    title: "Sync",
                    prominence: .secondary,
                    isEnabled: state.canUseRemoteActions,
                    helpText: syncHelpText,
                    hint: "Pull changes"
                )
            }
        }
    }

    private var uploadFolderHelpText: String {
        if !state.hasWorkspace {
            return "Open a workspace before uploading a folder."
        }

        if state.activeRemoteTarget == nil {
            return "Choose a university server before uploading a folder."
        }

        return "Upload \(state.workspaceDisplayName) to the selected server."
    }

    private var syncHelpText: String {
        if state.activeRemoteTarget == nil {
            return "Choose a university server before syncing."
        }

        return "Sync with the selected server."
    }

    private func remoteActionRow(
        title: String,
        prominence: ActionProminence,
        isEnabled: Bool,
        helpText: String,
        hint: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if prominence == .primary {
                    Button(title) { }
                        .buttonStyle(.borderedProminent)
                        .tint(StudioTheme.accent)
                } else {
                    Button(title) { }
                        .buttonStyle(.bordered)
                }
            }
            .disabled(!isEnabled)
            .help(helpText)

            Text(hint)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(StudioTheme.textSecondary)
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(StudioTheme.pane)
        .clipShape(.rect(cornerRadius: 10))
    }
}

private extension RemoteSidebarView {
    enum ActionProminence {
        case primary
        case secondary
    }

    func tagForegroundStyle(isActive: Bool, isEnabled: Bool) -> Color {
        if isActive {
            return StudioTheme.textPrimary
        }

        if !isEnabled {
            return StudioTheme.textSecondary.opacity(0.7)
        }

        return StudioTheme.textSecondary
    }

    func tagBackgroundStyle(isActive: Bool, isEnabled: Bool) -> Color {
        if isActive {
            return StudioTheme.accent.opacity(0.22)
        }

        if !isEnabled {
            return StudioTheme.hover.opacity(0.8)
        }

        return StudioTheme.hover
    }
}
