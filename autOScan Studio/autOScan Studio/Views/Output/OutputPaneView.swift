import SwiftUI

struct OutputPaneView: View {
    var body: some View {
        ZStack {
            Color(nsColor: StudioTheme.paneColor)
                .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
