import SwiftUI

struct SidebarContainerView: View {
    @ObservedObject var state: StudioAppState

    var body: some View {
        VStack(spacing: 0) {
            modeTabBar

            if state.hasWorkspace {
                WorkspaceTreeView(state: state, mode: state.sidebarMode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(StudioTheme.sidebar)
        .clipShape(Rectangle())
    }

    private var modeTabBar: some View {
        VStack(spacing: 0) {
            separatorLine

            HStack(spacing: 8) {
                ForEach(StudioAppState.SidebarMode.allCases) { mode in
                    Button {
                        state.sidebarMode = mode
                    } label: {
                        Image(systemName: iconName(for: mode))
                            .font(.system(size: 14, weight: .regular))
                            .symbolVariant(state.sidebarMode == mode ? .fill : .none)
                            .foregroundStyle(state.sidebarMode == mode ? StudioTheme.accent : StudioTheme.textSecondary)
                            .frame(width: 32, height: 24, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(mode.rawValue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 6)
            .frame(height: StudioTheme.chromeRowHeight)

            separatorLine
        }
        .background(StudioTheme.sidebar)
    }

    private var separatorLine: some View {
        Rectangle()
            .fill(StudioTheme.separator.opacity(0.72))
            .frame(height: 1)
    }

    private func iconName(for mode: StudioAppState.SidebarMode) -> String {
        switch mode {
        case .workspace:
            return "folder"
        case .policies:
            return "slider.horizontal.3"
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No Workspace")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(StudioTheme.textSecondary)
            Text("Use File > Open Workspace…")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(StudioTheme.textSecondary.opacity(0.8))
        }
        .padding(12)
    }
}
