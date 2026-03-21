import AppKit
import SwiftUI

@MainActor
final class StudioCenterSplitViewController: NSSplitViewController {
    private static let defaultOutputFraction: CGFloat = 0.26
    private static let outputMinimumThickness: CGFloat = 120

    private let state: StudioAppState
    private let editorSplitItem: NSSplitViewItem
    private let outputSplitItem: NSSplitViewItem
    private var hasAppliedInitialOutputLayout = false

    init(state: StudioAppState) {
        self.state = state

        let editorViewController = makeHostingController(rootView: EditorPaneView(state: state))
        editorSplitItem = NSSplitViewItem(viewController: editorViewController)
        editorSplitItem.minimumThickness = 220

        let outputViewController = makeHostingController(rootView: OutputPaneView(state: state))
        outputSplitItem = NSSplitViewItem(viewController: outputViewController)
        outputSplitItem.minimumThickness = state.isOutputVisible ? Self.outputMinimumThickness : 0
        outputSplitItem.holdingPriority = .defaultLow
        outputSplitItem.preferredThicknessFraction = Self.defaultOutputFraction

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
        outputSplitItem.viewController.view.isHidden = !state.isOutputVisible
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        if !state.isOutputVisible || !hasAppliedInitialOutputLayout {
            applyOutputPaneLayout()
            hasAppliedInitialOutputLayout = true
        }
    }

    func toggleOutputPane() {
        setOutputPaneVisible(!state.isOutputVisible)
    }

    func setOutputPaneVisible(_ visible: Bool) {
        if state.isOutputVisible != visible {
            state.isOutputVisible = visible
        }

        if visible {
            outputSplitItem.minimumThickness = Self.outputMinimumThickness
        } else {
            outputSplitItem.minimumThickness = 0
        }

        view.needsLayout = true
        applyOutputPaneLayout()
    }

    private func applyOutputPaneLayout() {
        guard splitViewItems.count == 2 else {
            return
        }

        let totalHeight = splitView.bounds.height
        let dividerThickness = splitView.dividerThickness
        let availableHeight = max(0, totalHeight - dividerThickness)
        guard availableHeight > 0 else {
            return
        }

        let outputView = outputSplitItem.viewController.view
        outputView.isHidden = false

        let dividerPosition: CGFloat
        if state.isOutputVisible {
            let desiredOutputHeight = max(
                Self.outputMinimumThickness,
                availableHeight * Self.defaultOutputFraction
            )
            let outputHeight = min(desiredOutputHeight, availableHeight)
            dividerPosition = max(0, availableHeight - outputHeight)
        } else {
            dividerPosition = availableHeight
        }

        splitView.setPosition(dividerPosition, ofDividerAt: 0)
        outputView.isHidden = !state.isOutputVisible
    }
}
