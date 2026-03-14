import SwiftUI

struct RootView: View {
    @Bindable var state: AppState

    var body: some View {
        NavigationSplitView(columnVisibility: splitColumnVisibility) {
            SidebarPane(state: state)
                .background(StudioTheme.sidebar)
                .ignoresSafeArea(.container, edges: .top)
                .navigationSplitViewColumnWidth(min: 230, ideal: 280, max: 340)
        } detail: {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(StudioTheme.separator)
                    .frame(height: 1)

                HSplitView {
                    mainPane
                        .layoutPriority(1)

                    if state.isInspectorPresented {
                        InspectorPane(state: state)
                            .frame(minWidth: 260, idealWidth: 320, maxWidth: 640)
                            .background(StudioTheme.sidebar)
                    }
                }
                .layoutPriority(1)
            }
            .background(StudioTheme.editor)
            .ignoresSafeArea(.container, edges: .top)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Text(state.toolbarTitle)
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(StudioTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .sharedBackgroundVisibility(.hidden)

            if #available(macOS 26.0, *) {
                ToolbarSpacer(.flexible, placement: .automatic)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                toggleTopBarButton(
                    title: "Output",
                    systemName: "rectangle.bottomthird.inset.filled",
                    isActive: state.isOutputPresented,
                    helpText: state.isOutputPresented ? "Hide Output" : "Show Output"
                ) {
                    state.isOutputPresented.toggle()
                }

                toggleTopBarButton(
                    title: "Inspector",
                    systemName: "sidebar.right",
                    isActive: state.isInspectorPresented,
                    helpText: state.isInspectorPresented ? "Hide Right Sidebar" : "Show Right Sidebar"
                ) {
                    state.isInspectorPresented.toggle()
                }
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .toolbarRole(.editor)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .background(StudioTheme.canvas)
    }

    private var splitColumnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { state.isSidebarPresented ? .all : .detailOnly },
            set: { visibility in
                state.isSidebarPresented = visibility != .detailOnly
            }
        )
    }

    @ViewBuilder
    private var mainPane: some View {
        if state.isOutputPresented {
            VSplitView {
                EditorPane(state: state)
                    .frame(minWidth: 520)
                    .background(StudioTheme.editor)
                    .layoutPriority(1)

                BottomPanel(state: state)
                    .frame(minHeight: 220, idealHeight: 280)
                    .background(StudioTheme.chrome)
            }
        } else {
            EditorPane(state: state)
                .frame(minWidth: 520)
                .background(StudioTheme.editor)
                .layoutPriority(1)
        }
    }

    private func toggleTopBarButton(
        title: String,
        systemName: String,
        isActive: Bool,
        helpText: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.system(size: 12, weight: .semibold, design: .default))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(StudioTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(glassButtonBackground(isActive: isActive))
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    @ViewBuilder
    private func glassButtonBackground(isActive: Bool) -> some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: 11)
                .fill(
                    isActive ? StudioTheme.surface.opacity(0.42) : StudioTheme.surfaceMuted.opacity(0.24)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(
                            isActive ? StudioTheme.accent.opacity(0.75) : StudioTheme.separator.opacity(0.45),
                            lineWidth: 0.8
                        )
                )
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 11))
        } else {
            RoundedRectangle(cornerRadius: 11)
                .fill(
                    isActive ? StudioTheme.surface.opacity(0.9) : StudioTheme.surfaceMuted.opacity(0.7)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(
                            isActive ? StudioTheme.accent.opacity(0.75) : StudioTheme.separator.opacity(0.8),
                            lineWidth: 0.8
                        )
                )
        }
    }
}

#Preview {
    RootView(state: AppState())
        .frame(width: 1400, height: 860)
}
