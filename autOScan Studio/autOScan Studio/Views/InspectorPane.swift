import SwiftUI

struct InspectorPane: View {
    @Bindable var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("autOScan")
                    .font(.system(size: 15, weight: .semibold, design: .default))
                    .foregroundStyle(StudioTheme.textPrimary)

                section(title: "Actions") {
                    VStack(alignment: .leading, spacing: 6) {
                        Button("Run Session") {
                            appendOutput("Run Session clicked")
                        }
                        .studioActionButton(emphasized: true)

                        Button("Run Submission") {
                            appendOutput("Run Submission clicked")
                        }
                        .studioActionButton()

                        Button("Compute AI") {
                            appendOutput("Compute AI clicked")
                        }
                        .studioActionButton()
                    }
                }

                section(title: "Session") {
                    VStack(alignment: .leading, spacing: 5) {
                        statusRow(label: "Policy", value: state.activePolicy)
                        statusRow(label: "Compile", value: state.compileStatus)
                        statusRow(label: "AI", value: state.aiStatus)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .default))
                .foregroundStyle(StudioTheme.textSecondary)

            content()
                .padding(7)
                .background(StudioTheme.surfaceMuted)
                .clipShape(.rect(cornerRadius: 3))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(StudioTheme.separator.opacity(0.8), lineWidth: 0.8)
                )
        }
    }

    private func statusRow(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .frame(width: 72, alignment: .leading)
                .font(.system(size: 11, weight: .semibold, design: .default))
                .foregroundStyle(StudioTheme.textSecondary)

            Text(value)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(StudioTheme.textPrimary)

            Spacer()
        }
    }

    private func appendOutput(_ message: String) {
        if message == "Run Session clicked" || message == "Run Submission clicked" {
            state.outputText = """
            --- expected/main.c
            +++ actual/main.c
            @@ -1,4 +1,4 @@
             int main(void) {
            -    return 0;
            +    return 1;
             }
            """
            return
        }
        if state.outputText.isEmpty {
            state.outputText = message
            return
        }
        state.outputText += "\n\(message)"
    }
}
