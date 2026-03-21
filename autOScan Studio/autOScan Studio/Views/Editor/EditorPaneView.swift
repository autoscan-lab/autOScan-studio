import SwiftUI

struct EditorPaneView: View {
    @ObservedObject var state: StudioAppState

    var body: some View {
        VStack(spacing: 0) {
            if isShowingPolicyEditor {
                policyHeader
            } else if isShowingRemoteSetup {
                remoteHeader
            } else {
                editorHeader
            }

            ZStack {
                Color(nsColor: StudioTheme.editorColor)
                    .ignoresSafeArea()

                if isShowingPolicyEditor {
                    PolicyManagerView(state: state)
                } else if isShowingRemoteSetup {
                    RemoteOnboardingView(state: state)
                } else {
                    CodeTextView(text: state.editorText)
                }
            }
        }
        .background(StudioTheme.editor)
    }

    private var editorHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSeparator

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if state.openFileTabs.isEmpty {
                        Text("No file open")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(StudioTheme.textSecondary.opacity(0.85))
                    } else {
                        ForEach(state.openFileTabs) { tab in
                            Button {
                                state.selectFile(nodeID: tab.id)
                            } label: {
                                Text(tab.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(
                                        tab.id == state.selectedFileNodeID
                                        ? StudioTheme.textPrimary
                                        : StudioTheme.textSecondary
                                    )
                                    .lineLimit(1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(tab.id == state.selectedFileNodeID ? StudioTheme.hover : .clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.trailing, 6)
            }
            .padding(.horizontal, 12)
            .frame(height: StudioTheme.chromeRowHeight)

            headerSeparator
        }
        .background(StudioTheme.editor)
    }

    private var headerSeparator: some View {
        Rectangle()
            .fill(StudioTheme.separator.opacity(0.72))
            .frame(height: 1)
    }

    private var isShowingPolicyEditor: Bool {
        state.sidebarMode == .policies && state.hasWorkspace
    }

    private var isShowingRemoteSetup: Bool {
        state.sidebarMode == .remote
    }

    private var policyHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSeparator

            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(StudioTheme.textSecondary)

                if let selectedPolicyName = state.selectedPolicyDisplayName {
                    Text(selectedPolicyName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(StudioTheme.textPrimary)
                        .lineLimit(1)

                    if state.isPolicyDirty {
                        Text("Unsaved changes")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text("Policies")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(StudioTheme.textPrimary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: StudioTheme.chromeRowHeight)

            headerSeparator
        }
        .background(StudioTheme.editor)
    }

    private var remoteHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSeparator

            HStack(spacing: 8) {
                Image(systemName: "network")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(StudioTheme.textSecondary)

                Text(state.selectedRemotePreset?.name ?? "Remote")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)

                if state.remoteConnectionState == .connected {
                    Text("SSH Live")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(StudioTheme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(StudioTheme.accent.opacity(0.22))
                        )
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: StudioTheme.chromeRowHeight)

            headerSeparator
        }
        .background(StudioTheme.editor)
    }
}
