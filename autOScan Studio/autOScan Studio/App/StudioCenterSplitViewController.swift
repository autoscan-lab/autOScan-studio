import AppKit
import SwiftUI

@MainActor
final class StudioCenterSplitViewController: NSSplitViewController {
    private static let defaultOutputFraction: CGFloat = 0.26

    private let state: StudioAppState
    private let editorSplitItem: NSSplitViewItem
    private let outputSplitItem: NSSplitViewItem
    private var isOutputAttached = false

    init(state: StudioAppState) {
        self.state = state

        let editorViewController = NSHostingController(rootView: EditorPaneView(state: state))
        editorSplitItem = NSSplitViewItem(viewController: editorViewController)
        editorSplitItem.minimumThickness = 220

        let outputViewController = NSHostingController(rootView: OutputPaneView())
        outputSplitItem = NSSplitViewItem(viewController: outputViewController)
        outputSplitItem.minimumThickness = 120
        outputSplitItem.canCollapse = false
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
        if state.isOutputVisible {
            attachOutputPane()
        }
    }

    func toggleOutputPane() {
        setOutputPaneVisible(!state.isOutputVisible)
    }

    func setOutputPaneVisible(_ visible: Bool) {
        if state.isOutputVisible != visible {
            state.isOutputVisible = visible
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            if visible {
                self.attachOutputPane()
            } else {
                self.detachOutputPane()
            }
        }
    }

    private func attachOutputPane() {
        guard !isOutputAttached else {
            return
        }

        outputSplitItem.preferredThicknessFraction = Self.defaultOutputFraction
        addSplitViewItem(outputSplitItem)
        isOutputAttached = true
        splitView.adjustSubviews()
    }

    private func detachOutputPane() {
        guard isOutputAttached else {
            return
        }

        removeSplitViewItem(outputSplitItem)
        isOutputAttached = false
        splitView.adjustSubviews()
    }
}
