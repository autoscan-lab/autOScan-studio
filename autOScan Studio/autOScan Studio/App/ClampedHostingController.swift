import AppKit
import SwiftUI

@MainActor
func makeHostingController<Content: View>(rootView: Content) -> NSViewController {
    ClampedHostingController(rootView: rootView)
}

@MainActor
private final class ClampedHostingController<Content: View>: NSViewController {
    private let hostingView: ClampedHostingView<Content>

    init(rootView: Content) {
        hostingView = ClampedHostingView(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
        hostingView.sizingOptions = []
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = hostingView
    }
}

private final class ClampedHostingView<Content: View>: NSHostingView<Content> {
    override var frame: NSRect {
        get {
            super.frame
        }
        set {
            super.frame = clamped(newValue)
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(
            NSSize(
                width: max(0, newSize.width),
                height: max(0, newSize.height)
            )
        )
    }

    private func clamped(_ frame: NSRect) -> NSRect {
        NSRect(
            x: frame.origin.x,
            y: frame.origin.y,
            width: max(0, frame.size.width),
            height: max(0, frame.size.height)
        )
    }
}
