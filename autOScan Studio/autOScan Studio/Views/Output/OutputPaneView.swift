import SwiftUI

struct OutputPaneView: View {
    @ObservedObject var state: StudioAppState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Output")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StudioTheme.textPrimary)

                Text(state.runStatusMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button("Clear") {
                    state.clearRunOutput()
                }
                .buttonStyle(.bordered)
                .disabled(state.runOutputText.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Rectangle()
                .fill(StudioTheme.separator.opacity(0.72))
                .frame(height: 1)

            ZStack(alignment: .topLeading) {
                Color(nsColor: StudioTheme.paneColor)
                    .ignoresSafeArea()

                if state.runOutputText.isEmpty {
                    Text("Run output will appear here.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(StudioTheme.textSecondary)
                        .padding(14)
                } else {
                    ScrollView {
                        Text(state.runOutputText)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(StudioTheme.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
