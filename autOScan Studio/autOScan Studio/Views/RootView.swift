import SwiftUI

struct RootView: View {
    @Bindable var state: AppState

    var body: some View {
        HSplitView {
            if state.isSidebarPresented {
                SidebarPane(state: state)
                    .frame(minWidth: 250, idealWidth: 280, maxWidth: 360)
                    .background(StudioTheme.sidebar)
            }

            VSplitView {
                EditorPane(state: state)
                    .frame(minWidth: 560)
                    .background(StudioTheme.editor)
                    .layoutPriority(1)

                BottomPanel(state: state)
                    .frame(minHeight: 220, idealHeight: 280)
                    .background(StudioTheme.chrome)
            }
            .layoutPriority(1)

            InspectorPane(state: state)
                .frame(minWidth: 300, idealWidth: 360, maxWidth: 520)
                .background(StudioTheme.sidebar)
        }
        .background(StudioTheme.canvas)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    state.isSidebarPresented.toggle()
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help(state.isSidebarPresented ? "Hide Sidebar" : "Show Sidebar")
            }
        }
    }
}

#Preview {
    RootView(state: AppState())
        .frame(width: 1400, height: 860)
}
