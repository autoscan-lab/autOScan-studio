import SwiftUI

struct SidebarPane: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("", selection: $state.sidebarMode) {
                ForEach(AppState.SidebarMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .tint(StudioTheme.accent)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 6)

            List(selection: $state.selectedPath) {
                ForEach(state.fileTree, id: \.self) { path in
                    Label {
                        Text(path)
                            .lineLimit(1)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                    } icon: {
                        Image(systemName: iconName(for: path))
                            .font(.system(size: 11, weight: .medium, design: .default))
                    }
                    .tag(path)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(StudioTheme.sidebar)
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func iconName(for path: String) -> String {
        if path.hasSuffix("/") {
            return "folder"
        }
        if path.hasSuffix(".yaml") {
            return "slider.horizontal.3"
        }
        return "doc.text"
    }
}
