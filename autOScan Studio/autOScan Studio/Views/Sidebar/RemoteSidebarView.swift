import SwiftUI

struct RemoteSidebarView: View {
    @ObservedObject var state: StudioAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                universityPresetsSection
                activeTargetSection
                savedProfilesSection
                remoteActionsSection
            }
            .padding(12)
        }
        .scrollIndicators(.hidden)
        .background(StudioTheme.sidebar)
    }

    private var universityPresetsSection: some View {
        sectionCard(title: "University Presets", systemImage: "network") {
            VStack(spacing: 8) {
                ForEach(state.remotePresets) { preset in
                    let isActive = state.activeRemoteTarget?.id == preset.id

                    Button {
                        state.activateRemotePreset(preset)
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(preset.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(StudioTheme.textPrimary)

                                Text(preset.primaryText)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(StudioTheme.textSecondary)

                                Text(preset.secondaryText)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(StudioTheme.textSecondary.opacity(0.82))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)

                            Text(isActive ? "Active" : "Use")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(isActive ? StudioTheme.textPrimary : StudioTheme.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                                        .fill(isActive ? StudioTheme.accent.opacity(0.22) : StudioTheme.hover)
                                )
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isActive ? StudioTheme.selection.opacity(0.72) : StudioTheme.editor.opacity(0.7))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var activeTargetSection: some View {
        sectionCard(title: "Active Remote", systemImage: "bolt.horizontal.circle") {
            if let target = state.activeRemoteTarget {
                VStack(alignment: .leading, spacing: 10) {
                    detailRow("Source", target.source.rawValue)
                    detailRow("Target", target.title)
                    detailRow("Primary", target.primaryText)
                    detailRow("Notes", target.secondaryText)

                    Text("This target is ready for upcoming connect, upload, and sync actions.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(StudioTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Clear Target") {
                        state.clearActiveRemoteTarget()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Text("Choose a university preset or saved profile to make it the active remote target for this workspace.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var savedProfilesSection: some View {
        sectionCard(title: "Saved Profiles", systemImage: "person.crop.rectangle.stack") {
            if state.savedSSHProfiles.isEmpty {
                Text("No saved SSH profiles yet. Profile management lands here next, and those profiles will show up alongside the university presets.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 8) {
                    ForEach(state.savedSSHProfiles) { profile in
                        let isActive = state.activeRemoteTarget?.id == "profile:\(profile.id.uuidString)"

                        Button {
                            state.activateRemoteProfile(profile)
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(profile.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(StudioTheme.textPrimary)

                                    Text(profile.host)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(StudioTheme.textSecondary)

                                    Text("\(profile.user) • Port \(profile.port)")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundStyle(StudioTheme.textSecondary.opacity(0.82))
                                }

                                Spacer(minLength: 0)

                                Text(isActive ? "Active" : "Use")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(isActive ? StudioTheme.textPrimary : StudioTheme.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                                            .fill(isActive ? StudioTheme.accent.opacity(0.22) : StudioTheme.hover)
                                    )
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isActive ? StudioTheme.selection.opacity(0.72) : StudioTheme.editor.opacity(0.7))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var remoteActionsSection: some View {
        sectionCard(title: "Remote Actions", systemImage: "arrow.up.arrow.down") {
            VStack(alignment: .leading, spacing: 10) {
                stagedActionButton(
                    title: "Upload Workspace",
                    detail: workspaceUploadDetail
                )

                stagedActionButton(
                    title: "Upload Selected Item",
                    detail: selectionUploadDetail
                )

                stagedActionButton(
                    title: "Sync Back",
                    detail: "Download and sync flows will attach to the active remote target here."
                )
            }
        }
    }

    private var workspaceUploadDetail: String {
        if !state.hasWorkspace {
            return "Open a workspace to stage a remote upload from Studio."
        }

        if state.activeRemoteTarget == nil {
            return "Choose an active remote target first."
        }

        return "The current workspace, \(state.workspaceDisplayName), is ready for the Remote sync slice."
    }

    private var selectionUploadDetail: String {
        if let selectedWorkspaceItemName = state.selectedWorkspaceItemName {
            if state.activeRemoteTarget == nil {
                return "\(selectedWorkspaceItemName) is selected. Choose an active remote target first."
            }

            return "\(selectedWorkspaceItemName) is selected and ready for the targeted upload slice."
        }

        return "Pick a file in the Workspace tab to prepare a targeted remote upload."
    }

    private func stagedActionButton(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button(title) { }
                .buttonStyle(.bordered)
                .disabled(true)

            Text(detail)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(StudioTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(StudioTheme.textSecondary)

            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(StudioTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
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
        .padding(12)
        .background(StudioTheme.pane)
        .clipShape(.rect(cornerRadius: 10))
    }
}
