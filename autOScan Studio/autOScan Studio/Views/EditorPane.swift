import SwiftUI

struct EditorPane: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(state.selectedPath ?? "No file selected")
                    .lineLimit(1)
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(StudioTheme.textPrimary)

                Spacer()

                Text("Read-only")
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(StudioTheme.surfaceMuted)
                    .clipShape(.rect(cornerRadius: 3))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Rectangle()
                .fill(StudioTheme.separator)
                .frame(height: 1)

            CodeTextView(text: state.editorText)
                .background(StudioTheme.editor)
        }
    }
}
