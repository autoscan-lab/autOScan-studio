import SwiftUI

struct ContentView: View {
    @State private var state = AppState()

    var body: some View {
        RootView(state: state)
            .font(.system(size: 12, weight: .regular, design: .default))
            .tint(StudioTheme.accent)
            .preferredColorScheme(.dark)
            .background(StudioTheme.canvas)
    }
}

#Preview {
    ContentView()
        .frame(width: 1400, height: 860)
}
