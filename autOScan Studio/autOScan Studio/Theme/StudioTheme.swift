import SwiftUI

enum StudioTheme {
    static let canvas = Color(hex: 0x0B0B0D)
    static let chrome = Color(hex: 0x0F1012)
    static let sidebar = Color(hex: 0x111214)
    static let editor = Color(hex: 0x0C0D0F)
    static let surface = Color(hex: 0x16181A)
    static let surfaceMuted = Color(hex: 0x121315)
    static let separator = Color(hex: 0x26282B)

    static let textPrimary = Color(hex: 0xE6E7E9)
    static let textSecondary = Color(hex: 0x9DA3AB)

    static let accent = Color(hex: 0x19A37C)
    static let accentSoft = Color(hex: 0x162A22)
    static let success = Color(hex: 0x56D364)
    static let warning = Color(hex: 0xE3B341)
    static let error = Color(hex: 0xF85149)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
