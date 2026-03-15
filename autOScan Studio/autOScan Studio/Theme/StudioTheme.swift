import AppKit
import SwiftUI

enum StudioTheme {
    static let chromeRowHeight: CGFloat = 40

    static let canvasColor = NSColor(hex: 0x1F2126)
    static let sidebarColor = NSColor(hex: 0x17191D)
    static let editorColor = NSColor(hex: 0x22252C)
    static let paneColor = NSColor(hex: 0x1C1F25)
    static let separatorColor = NSColor(hex: 0x323743)
    static let textPrimaryColor = NSColor(hex: 0xF2F4F8)
    static let textSecondaryColor = NSColor(hex: 0x929AAC)
    static let selectionColor = NSColor(hex: 0x6E7890, alpha: 0.42)
    static let hoverColor = NSColor(hex: 0x2A2E37)
    static let accentColor = NSColor(hex: 0x007AFF)

    static let canvas = Color(nsColor: canvasColor)
    static let sidebar = Color(nsColor: sidebarColor)
    static let editor = Color(nsColor: editorColor)
    static let pane = Color(nsColor: paneColor)
    static let separator = Color(nsColor: separatorColor)
    static let textPrimary = Color(nsColor: textPrimaryColor)
    static let textSecondary = Color(nsColor: textSecondaryColor)
    static let selection = Color(nsColor: selectionColor)
    static let hover = Color(nsColor: hoverColor)
    static let accent = Color(nsColor: accentColor)
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}
