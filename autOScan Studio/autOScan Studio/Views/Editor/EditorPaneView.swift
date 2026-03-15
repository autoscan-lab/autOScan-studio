import SwiftUI

struct EditorPaneView: View {
    @ObservedObject var state: StudioAppState

    var body: some View {
        VStack(spacing: 0) {
            editorHeader

            ZStack {
                Color(nsColor: StudioTheme.editorColor)
                    .ignoresSafeArea()

                if state.sidebarMode == .policies, state.hasWorkspace {
                    PolicyManagerView(state: state)
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
}
