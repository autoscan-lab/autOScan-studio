import AppKit
import SwiftUI

@MainActor
final class StudioSplitViewController: NSSplitViewController {
    static let minSidebarWidth: CGFloat = 242
    private static let defaultInspectorFraction: CGFloat = 0.24

    let centerSplitViewController: StudioCenterSplitViewController

    private let state: StudioAppState
    private let sidebarSplitItem: NSSplitViewItem
    private let mainSplitItem: NSSplitViewItem
    private let inspectorSplitItem: NSSplitViewItem

    init(state: StudioAppState) {
        self.state = state
        centerSplitViewController = StudioCenterSplitViewController(state: state)

        let sidebarController = makeHostingController(rootView: SidebarContainerView(state: state))
        sidebarController.view.wantsLayer = true
        sidebarController.view.layer?.cornerRadius = 0
        sidebarController.view.layer?.masksToBounds = true
        sidebarController.view.layer?.backgroundColor = StudioTheme.sidebarColor.cgColor
        sidebarSplitItem = NSSplitViewItem(viewController: sidebarController)
        sidebarSplitItem.minimumThickness = Self.minSidebarWidth
        sidebarSplitItem.canCollapse = true
        sidebarSplitItem.collapseBehavior = .useConstraints
        sidebarSplitItem.isSpringLoaded = true
        sidebarSplitItem.holdingPriority = .defaultHigh
        sidebarSplitItem.titlebarSeparatorStyle = .none

        mainSplitItem = NSSplitViewItem(viewController: centerSplitViewController)
        mainSplitItem.minimumThickness = 420
        mainSplitItem.titlebarSeparatorStyle = .none

        let inspectorController = makeHostingController(rootView: InspectorPaneView(state: state))
        inspectorSplitItem = NSSplitViewItem(viewController: inspectorController)
        inspectorSplitItem.minimumThickness = 260
        inspectorSplitItem.maximumThickness = 460
        inspectorSplitItem.collapseBehavior = .useConstraints
        inspectorSplitItem.titlebarSeparatorStyle = .none
        inspectorSplitItem.isSpringLoaded = true
        inspectorSplitItem.holdingPriority = .defaultLow
        inspectorSplitItem.preferredThicknessFraction = Self.defaultInspectorFraction
        inspectorSplitItem.canCollapse = true
        inspectorSplitItem.isCollapsed = !state.isInspectorVisible

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

        splitView.dividerStyle = .thin
        splitView.isVertical = true
        splitView.wantsLayer = true
        splitView.layer?.backgroundColor = StudioTheme.canvasColor.cgColor
        view.wantsLayer = true
        view.layer?.backgroundColor = StudioTheme.canvasColor.cgColor

        addSplitViewItem(sidebarSplitItem)
        addSplitViewItem(mainSplitItem)
        addSplitViewItem(inspectorSplitItem)

        sidebarSplitItem.isCollapsed = !state.isSidebarVisible
        inspectorSplitItem.isCollapsed = !state.isInspectorVisible
    }

    func toggleSidebar() {
        let shouldShow = sidebarSplitItem.isCollapsed
        sidebarSplitItem.isCollapsed = !shouldShow
        state.isSidebarVisible = shouldShow
    }

    func toggleInspector() {
        let shouldShow = inspectorSplitItem.isCollapsed
        setInspectorVisible(shouldShow)
    }

    func setInspectorVisible(_ visible: Bool) {
        if visible {
            inspectorSplitItem.preferredThicknessFraction = Self.defaultInspectorFraction
        }
        inspectorSplitItem.isCollapsed = !visible
        splitView.adjustSubviews()
        view.layoutSubtreeIfNeeded()
        state.isInspectorVisible = visible
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
