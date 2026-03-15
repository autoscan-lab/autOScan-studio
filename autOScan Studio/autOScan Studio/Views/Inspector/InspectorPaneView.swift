import SwiftUI

struct InspectorPaneView: View {
    var body: some View {
        ZStack {
            Color(nsColor: StudioTheme.sidebarColor)
                .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
