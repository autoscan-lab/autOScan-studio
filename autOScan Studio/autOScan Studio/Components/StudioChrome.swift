import SwiftUI

struct StudioPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(StudioTheme.chrome)
    }
}

struct StudioInsetModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(StudioTheme.surfaceMuted)
            .clipShape(.rect(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(StudioTheme.separator.opacity(0.8), lineWidth: 0.8)
            )
    }
}

struct StudioActionButtonStyle: ButtonStyle {
    let emphasized: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .default))
            .foregroundStyle(emphasized ? Color.black.opacity(0.8) : StudioTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(emphasized ? StudioTheme.accent : StudioTheme.surface)
            .clipShape(.rect(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(StudioTheme.separator.opacity(0.75), lineWidth: 0.8)
            )
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

extension View {
    func studioPanel() -> some View {
        modifier(StudioPanelModifier())
    }

    func studioInset() -> some View {
        modifier(StudioInsetModifier())
    }

    func studioActionButton(emphasized: Bool = false) -> some View {
        buttonStyle(StudioActionButtonStyle(emphasized: emphasized))
    }
}
