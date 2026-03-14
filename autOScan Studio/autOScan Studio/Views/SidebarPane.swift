import SwiftUI

struct SidebarPane: View {
    @Bindable var state: AppState
    @State private var hoveredMode: AppState.SidebarMode?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            modeList
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 14)

            if state.sidebarMode == .workspace {
                HStack(spacing: 8) {
                    Text("Workspace")
                        .lineLimit(1)
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .foregroundStyle(StudioTheme.textSecondary)

                    Spacer()

                    Button {
                        state.openWorkspacePanel()
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 12, weight: .semibold, design: .default))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(StudioTheme.textSecondary)
                    .help("Open Workspace Folder")
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }

            explorerBody
        }
        .animation(nil, value: state.expandedDirectoryIDs)
        .animation(nil, value: state.selectedPath)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(StudioTheme.sidebar)
    }

    private var modeList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(AppState.SidebarMode.allCases) { mode in
                Button {
                    state.sidebarMode = mode
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: iconName(for: mode))
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .frame(width: 16)

                        Text(mode.rawValue)
                            .font(.system(size: 13, weight: .semibold, design: .default))

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(
                        state.sidebarMode == mode ? StudioTheme.textPrimary : StudioTheme.textSecondary
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(modeBackground(for: mode))
                    .clipShape(.rect(cornerRadius: 10))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onHover { isHovering in
                    if isHovering {
                        hoveredMode = mode
                    } else if hoveredMode == mode {
                        hoveredMode = nil
                    }
                }
            }
        }
    }

    private func modeBackground(for mode: AppState.SidebarMode) -> Color {
        if state.sidebarMode == mode {
            return StudioTheme.surface
        }
        if hoveredMode == mode {
            return StudioTheme.surface
        }
        return .clear
    }

    private var explorerBody: some View {
        ScrollView {
            if nodesForCurrentMode.isEmpty {
                EmptyView()
            } else {
                ExplorerNodeList(
                    state: state,
                    nodes: nodesForCurrentMode,
                    depth: 0,
                    iconName: iconName(for:)
                )
                .transaction { transaction in
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
                .padding(.top, 4)
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
        .scrollIndicators(.hidden)
        .background(StudioTheme.sidebar)
    }

    private var nodesForCurrentMode: [AppState.SidebarNode] {
        if state.sidebarMode != .workspace {
            return state.sidebarNodes
        }
        guard !state.workspaceTitle.isEmpty else {
            return []
        }
        let rootNode = AppState.SidebarNode(
            id: state.workspaceRootNodeID,
            displayName: state.workspaceTitle,
            isDirectory: true,
            children: state.workspaceNodes
        )
        return [rootNode]
    }

    private func iconName(for mode: AppState.SidebarMode) -> String {
        switch mode {
        case .workspace:
            return "folder"
        case .policies:
            return "slider.horizontal.3"
        case .runs:
            return "play.rectangle"
        }
    }

    private func iconName(for node: AppState.SidebarNode) -> String {
        guard !node.isDirectory else { return "folder" }
        let ext = URL(fileURLWithPath: node.id).pathExtension.lowercased()
        switch ext {
        case "c", "cpp", "h":
            return "c.circle"
        case "md":
            return "text.alignleft"
        default:
            return "doc.text"
        }
    }
}

private struct ExplorerNodeList: View {
    @Bindable var state: AppState
    let nodes: [AppState.SidebarNode]
    let depth: Int
    let iconName: (AppState.SidebarNode) -> String

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(nodes) { node in
                ExplorerRow(
                    state: state,
                    node: node,
                    depth: depth,
                    iconName: iconName
                )

                if node.isDirectory && state.isDirectoryExpanded(node.id), let children = node.children {
                    ExplorerNodeList(
                        state: state,
                        nodes: children,
                        depth: depth + 1,
                        iconName: iconName
                    )
                }
            }
        }
        .animation(nil, value: state.expandedDirectoryIDs)
    }
}

private struct ExplorerRow: View {
    @Bindable var state: AppState
    let node: AppState.SidebarNode
    let depth: Int
    let iconName: (AppState.SidebarNode) -> String

    var body: some View {
        HStack(spacing: 8) {
            if node.isDirectory {
                Image(systemName: state.isDirectoryExpanded(node.id) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold, design: .default))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .frame(width: 10)
            } else {
                Spacer()
                    .frame(width: 10)
            }

            Image(systemName: iconName(node))
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundStyle(node.isDirectory ? StudioTheme.textSecondary : StudioTheme.textPrimary)

            Text(node.displayName)
                .lineLimit(1)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(node.isDirectory ? StudioTheme.textSecondary : StudioTheme.textPrimary)

            Spacer(minLength: 0)
        }
        .padding(.leading, 8 + CGFloat(depth) * 16)
        .padding(.trailing, 8)
        .padding(.vertical, 7)
        .background(fileSelectionBackground)
        .clipShape(.rect(cornerRadius: 8))
        .contentShape(.rect)
        .onTapGesture {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if node.isDirectory {
                    state.toggleDirectoryExpansion(node.id)
                    return
                }
                state.selectedPath = node.id
            }
        }
        .animation(nil, value: state.expandedDirectoryIDs)
    }

    private var fileSelectionBackground: Color {
        guard !node.isDirectory, state.selectedPath == node.id else {
            return .clear
        }
        return StudioTheme.surface
    }
}
