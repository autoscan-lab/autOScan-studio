import SwiftUI

struct EditorPane: View {
    @Bindable var state: AppState

    var body: some View {
        CodeTextView(text: state.editorText)
            .background(StudioTheme.editor)
    }
}
