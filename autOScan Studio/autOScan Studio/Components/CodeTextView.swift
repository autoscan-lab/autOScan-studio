import AppKit
import SwiftUI

struct CodeTextView: NSViewRepresentable {
    enum ContentKind: String {
        case source
        case notice
    }

    let text: String
    let fileURL: URL?
    let contentKind: ContentKind

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            containerSize: NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        textContainer.widthTracksTextView = false

        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        configure(textView)

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = StudioTheme.editorColor
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        applyContent(to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        let signature = contentSignature
        guard context.coordinator.signature != signature else {
            return
        }

        context.coordinator.signature = signature
        applyContent(to: textView)
    }

    private var contentSignature: String {
        [
            contentKind.rawValue,
            fileURL?.pathExtension.lowercased() ?? "",
            text
        ]
        .joined(separator: "\u{1F}")
    }

    private func configure(_ textView: NSTextView) {
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.drawsBackground = true
        textView.backgroundColor = StudioTheme.editorColor
        textView.allowsUndo = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = .zero
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.textContainer?.lineFragmentPadding = 0
    }

    private func applyContent(to textView: NSTextView) {
        let attributedText = styledText()
        textView.textStorage?.setAttributedString(attributedText)
    }

    private func styledText() -> NSAttributedString {
        switch contentKind {
        case .source:
            let attributedString = NSMutableAttributedString(
                string: text,
                attributes: sourceBaseAttributes
            )
            applySyntaxHighlighting(to: attributedString)
            return attributedString
        case .notice:
            return NSAttributedString(
                string: text,
                attributes: noticeAttributes
            )
        }
    }

    private var sourceBaseAttributes: [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.16

        return [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: StudioTheme.textPrimaryColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    private var noticeAttributes: [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.12

        return [
            .font: NSFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: StudioTheme.textSecondaryColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func applySyntaxHighlighting(to attributedString: NSMutableAttributedString) {
        guard syntaxLanguage == .cFamily else {
            return
        }

        applyMatches(
            pattern: #"(?m)^\s*#.*$"#,
            color: NSColor(hex: 0xE39A4E),
            to: attributedString
        )
        applyMatches(
            pattern: #"\b(auto|bool|break|case|char|const|continue|default|do|double|else|enum|extern|float|for|goto|if|inline|int|long|register|restrict|return|short|signed|sizeof|static|struct|switch|typedef|union|unsigned|void|volatile|while|_Bool)\b"#,
            color: NSColor(hex: 0x68B5FF),
            to: attributedString
        )
        applyMatches(
            pattern: #"\b(NULL|true|false)\b"#,
            color: NSColor(hex: 0xD36CFF),
            to: attributedString
        )
        applyMatches(
            pattern: #"\b(0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b"#,
            color: NSColor(hex: 0xC792EA),
            to: attributedString
        )
        applyMatches(
            pattern: #"\"([^\"\\]|\\.)*\"|'([^'\\]|\\.)*'"#,
            color: NSColor(hex: 0xE6C07B),
            to: attributedString
        )
        applyMatches(
            pattern: #"//.*|/\*[\s\S]*?\*/"#,
            color: NSColor(hex: 0x7B9E7B),
            to: attributedString,
            options: [.dotMatchesLineSeparators]
        )
    }

    private var syntaxLanguage: SyntaxLanguage {
        guard let fileExtension = fileURL?.pathExtension.lowercased() else {
            return .plainText
        }

        switch fileExtension {
        case "c", "h", "cc", "cpp", "cxx", "hh", "hpp":
            return .cFamily
        default:
            return .plainText
        }
    }

    private func applyMatches(
        pattern: String,
        color: NSColor,
        to attributedString: NSMutableAttributedString,
        options: NSRegularExpression.Options = []
    ) {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else {
            return
        }

        let fullRange = NSRange(location: 0, length: attributedString.string.utf16.count)
        for match in expression.matches(in: attributedString.string, range: fullRange) {
            attributedString.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }
}

extension CodeTextView {
    final class Coordinator {
        var signature = ""
    }

    private enum SyntaxLanguage {
        case plainText
        case cFamily
    }
}
