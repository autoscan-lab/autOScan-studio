import AppKit
import SwiftUI

@MainActor
final class StudioCenterSplitViewController: NSSplitViewController {
    private static let defaultOutputFraction: CGFloat = 0.26

    private let state: StudioAppState
    private let editorSplitItem: NSSplitViewItem
    private let outputSplitItem: NSSplitViewItem

    init(state: StudioAppState) {
        self.state = state

        let editorViewController = makeHostingController(rootView: EditorPaneView(state: state))
        editorSplitItem = NSSplitViewItem(viewController: editorViewController)
        editorSplitItem.minimumThickness = 220

        let outputViewController = makeHostingController(rootView: OutputPaneView(state: state))
        outputSplitItem = NSSplitViewItem(viewController: outputViewController)
        outputSplitItem.minimumThickness = 120
        outputSplitItem.canCollapse = true
        outputSplitItem.collapseBehavior = .useConstraints
        outputSplitItem.holdingPriority = .defaultLow
        outputSplitItem.preferredThicknessFraction = Self.defaultOutputFraction
        outputSplitItem.isCollapsed = !state.isOutputVisible

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        splitView = StudioSplitView()
        super.loadView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        splitView.isVertical = false
        splitView.dividerStyle = .thin
        splitView.wantsLayer = true
        splitView.layer?.backgroundColor = StudioTheme.canvasColor.cgColor
        view.wantsLayer = true
        view.layer?.backgroundColor = StudioTheme.canvasColor.cgColor

        addSplitViewItem(editorSplitItem)
        addSplitViewItem(outputSplitItem)
        outputSplitItem.isCollapsed = !state.isOutputVisible
    }

    func toggleOutputPane() {
        setOutputPaneVisible(!state.isOutputVisible)
    }

    func setOutputPaneVisible(_ visible: Bool) {
        if state.isOutputVisible != visible {
            state.isOutputVisible = visible
        }

        if visible {
            outputSplitItem.preferredThicknessFraction = Self.defaultOutputFraction
        }
        outputSplitItem.isCollapsed = !visible
        splitView.adjustSubviews()
        view.layoutSubtreeIfNeeded()
    }
}

@MainActor
private func makeHostingController<Content: View>(rootView: Content) -> NSHostingController<Content> {
    let controller = NSHostingController(rootView: rootView)
    _ = controller.view
    controller.preferredContentSize = .zero

    if let hostingView = controller.view as? NSHostingView<Content> {
        hostingView.sizingOptions = []
    }

    return controller
}
