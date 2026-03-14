import SwiftUI

struct InspectorPane: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("autOScan")
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(StudioTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)

            Rectangle()
                .fill(StudioTheme.separator)
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    section(title: "Policy") {
                        VStack(alignment: .leading, spacing: 6) {
                            statusRow(label: "Active", value: displayValue(state.activePolicy))

                            Button("Open Policies") {
                                state.sidebarMode = .policies
                                state.isSidebarPresented = true
                            }
                            .studioActionButton()
                        }
                    }

                    section(title: "Actions") {
                        VStack(alignment: .leading, spacing: 6) {
                            Button("Run Session") {
                                state.runStatus = "Session requested"
                                state.isOutputPresented = true
                                appendOutputLine("runSession requested (UI scaffold)")
                            }
                            .studioActionButton(emphasized: true)

                            Button("Run Submission") {
                                state.runStatus = "Submission requested"
                                state.isOutputPresented = true
                                appendOutputLine("runSubmission requested (UI scaffold)")
                            }
                            .studioActionButton()

                            Button("Export Report") {
                                state.exportStatus = "Requested"
                                state.isOutputPresented = true
                                appendOutputLine("exportReport requested (UI scaffold)")
                            }
                            .studioActionButton()
                        }
                    }

                    section(title: "Status") {
                        VStack(alignment: .leading, spacing: 5) {
                            statusRow(label: "Run", value: state.runStatus)
                            statusRow(label: "Compile", value: state.compileStatus)
                            statusRow(label: "Export", value: state.exportStatus)
                        }
                    }

                    section(title: "Banned Functions") {
                        VStack(alignment: .leading, spacing: 5) {
                            statusRow(label: "Status", value: state.bannedStatus)
                            statusRow(label: "Hits", value: "\(state.bannedHits)")
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
            .scrollIndicators(.hidden)
        }
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

    private func displayValue(_ value: String) -> String {
        value.isEmpty ? "—" : value
    }

    private func appendOutputLine(_ text: String) {
        if state.outputText.isEmpty {
            state.outputText = text
            return
        }
        state.outputText += "\n\(text)"
    }
}
