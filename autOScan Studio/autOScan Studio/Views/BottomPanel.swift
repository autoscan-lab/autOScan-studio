import SwiftUI

struct BottomPanel: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Output")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(StudioTheme.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Rectangle()
                .fill(StudioTheme.separator)
                .frame(height: 1)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(parsedLines.enumerated()), id: \.offset) { index, line in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundStyle(StudioTheme.textSecondary)
                                .frame(width: 34, alignment: .trailing)

                            Text(line.text.isEmpty ? " " : line.text)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .foregroundStyle(textColor(for: line.kind))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                        .background(backgroundColor(for: line.kind))
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
        }
        .background(StudioTheme.chrome)
    }

    private var parsedLines: [DiffLine] {
        let rows = state.outputText.components(separatedBy: .newlines)
        return rows.map { row in
            DiffLine(text: row, kind: kind(for: row))
        }
    }

    private func kind(for row: String) -> DiffLine.Kind {
        if row.hasPrefix("+"), !row.hasPrefix("+++") {
            return .added
        }
        if row.hasPrefix("-"), !row.hasPrefix("---") {
            return .removed
        }
        return .context
    }

    private func textColor(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .added:
            StudioTheme.success
        case .removed:
            StudioTheme.error
        case .context:
            StudioTheme.textPrimary
        }
    }

    private func backgroundColor(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .added:
            StudioTheme.success.opacity(0.08)
        case .removed:
            StudioTheme.error.opacity(0.08)
        case .context:
            .clear
        }
    }
}

private struct DiffLine {
    enum Kind {
        case added
        case removed
        case context
    }

    let text: String
    let kind: Kind
}
