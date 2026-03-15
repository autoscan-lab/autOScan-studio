import AppKit

final class StudioSplitView: NSSplitView {
    override var dividerColor: NSColor {
        StudioTheme.separatorColor
    }

    override var dividerThickness: CGFloat {
        1.0
    }
}
