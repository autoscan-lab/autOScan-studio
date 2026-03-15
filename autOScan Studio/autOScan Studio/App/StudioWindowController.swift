import AppKit
import Combine

@MainActor
final class StudioWindowController: NSWindowController, NSToolbarDelegate {
    private let splitViewController: StudioSplitViewController
    private let state: StudioAppState

    private var titleLabel: NSTextField?
    private var sidebarToolbarItem: NSToolbarItem?
    private var outputToolbarItem: NSToolbarItem?
    private var inspectorToolbarItem: NSToolbarItem?
    private var cancellables: Set<AnyCancellable> = []

    init(window: NSWindow, splitViewController: StudioSplitViewController, state: StudioAppState) {
        self.splitViewController = splitViewController
        self.state = state
        super.init(window: window)
        window.contentViewController = splitViewController

        setupToolbar()
        observeState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func observeState() {
        state.$toolbarTitle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] title in
                self?.titleLabel?.stringValue = title
            }
            .store(in: &cancellables)

        state.$isSidebarVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateToolbarToggleItems()
            }
            .store(in: &cancellables)

        state.$isOutputVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateToolbarToggleItems()
            }
            .store(in: &cancellables)

        state.$isInspectorVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateToolbarToggleItems()
            }
            .store(in: &cancellables)
    }

    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: NSToolbar.Identifier("StudioToolbar"))
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconAndLabel

        window?.titleVisibility = .hidden
        window?.titlebarAppearsTransparent = true
        window?.toolbarStyle = .unifiedCompact
        window?.titlebarSeparatorStyle = .none
        window?.backgroundColor = StudioTheme.canvasColor
        window?.toolbar = toolbar
    }

    private func updateToolbarToggleItems() {
        guard
            let sidebarToolbarItem,
            let outputToolbarItem,
            let inspectorToolbarItem
        else {
            return
        }

        configureSidebarToolbarItem(sidebarToolbarItem)
        configureOutputToolbarItem(outputToolbarItem)
        configureInspectorToolbarItem(inspectorToolbarItem)
    }

    private func configureSidebarToolbarItem(_ item: NSToolbarItem) {
        item.label = "Sidebar"
        item.paletteLabel = "Toggle Sidebar"
        item.toolTip = state.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar"
        item.image = NSImage(
            systemSymbolName: "sidebar.leading",
            accessibilityDescription: "Toggle Sidebar"
        )
        item.isBordered = false
        item.visibilityPriority = .high
    }

    private func configureOutputToolbarItem(_ item: NSToolbarItem) {
        let isVisible = state.isOutputVisible
        item.label = "Output"
        item.paletteLabel = "Toggle Output"
        item.toolTip = isVisible ? "Hide Output Pane" : "Show Output Pane"
        item.image = NSImage(
            systemSymbolName: isVisible ? "terminal.fill" : "terminal",
            accessibilityDescription: "Toggle Output"
        )
        item.isBordered = false
        item.visibilityPriority = .high
    }

    private func configureInspectorToolbarItem(_ item: NSToolbarItem) {
        item.label = "Inspector"
        item.paletteLabel = "Toggle Inspector"
        item.toolTip = state.isInspectorVisible ? "Hide Inspector Sidebar" : "Show Inspector Sidebar"
        item.image = NSImage(
            systemSymbolName: "sidebar.trailing",
            accessibilityDescription: "Toggle Inspector"
        )
        item.isBordered = false
        item.visibilityPriority = .high
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .toggleSidebarItem,
            .sidebarTrackingSeparatorItem,
            .fileTitleItem,
            .flexibleSpace,
            .outputToggleItem,
            .space,
            .inspectorToggleItem
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .toggleSidebarItem,
            .sidebarTrackingSeparatorItem,
            .fileTitleItem,
            .outputToggleItem,
            .space,
            .inspectorToggleItem,
            .flexibleSpace
        ]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .toggleSidebarItem:
            let item = NSToolbarItem(itemIdentifier: .toggleSidebarItem)
            item.target = self
            item.action = #selector(toggleSidebar)
            configureSidebarToolbarItem(item)
            sidebarToolbarItem = item
            return item

        case .sidebarTrackingSeparatorItem:
            return NSTrackingSeparatorToolbarItem(
                identifier: .sidebarTrackingSeparatorItem,
                splitView: splitViewController.splitView,
                dividerIndex: 0
            )

        case .fileTitleItem:
            let item = NSToolbarItem(itemIdentifier: .fileTitleItem)
            item.label = "Current File"
            item.paletteLabel = "Current File"
            item.isBordered = false

            let titleLabel = NSTextField(labelWithString: state.toolbarTitle)
            titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
            titleLabel.textColor = StudioTheme.textPrimaryColor
            titleLabel.lineBreakMode = .byTruncatingMiddle
            titleLabel.maximumNumberOfLines = 1
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            titleLabel.setContentHuggingPriority(.required, for: .horizontal)

            let container = NSView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.setContentCompressionResistancePriority(.required, for: .horizontal)
            container.setContentHuggingPriority(.required, for: .horizontal)
            container.addSubview(titleLabel)
            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
                titleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
            let minWidth = container.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
            let maxWidth = container.widthAnchor.constraint(lessThanOrEqualToConstant: 420)
            let preferredWidth = container.widthAnchor.constraint(equalTo: titleLabel.widthAnchor)
            preferredWidth.priority = .defaultHigh
            NSLayoutConstraint.activate([minWidth, maxWidth, preferredWidth])

            item.view = container
            item.visibilityPriority = .low
            self.titleLabel = titleLabel
            return item

        case .outputToggleItem:
            let item = NSToolbarItem(itemIdentifier: .outputToggleItem)
            item.target = self
            item.action = #selector(toggleOutput)
            configureOutputToolbarItem(item)
            outputToolbarItem = item
            return item

        case .inspectorToggleItem:
            let item = NSToolbarItem(itemIdentifier: .inspectorToggleItem)
            item.target = self
            item.action = #selector(toggleInspector)
            configureInspectorToolbarItem(item)
            inspectorToolbarItem = item
            return item

        default:
            return nil
        }
    }

    @objc
    private func toggleSidebar() {
        splitViewController.toggleSidebar()
    }

    @objc
    private func toggleOutput() {
        splitViewController.centerSplitViewController.toggleOutputPane()
    }

    @objc
    private func toggleInspector() {
        splitViewController.toggleInspector()
    }

}

extension NSToolbarItem.Identifier {
    static let toggleSidebarItem = NSToolbarItem.Identifier("ToggleSidebarItem")
    static let sidebarTrackingSeparatorItem = NSToolbarItem.Identifier("SidebarTrackingSeparatorItem")
    static let fileTitleItem = NSToolbarItem.Identifier("FileTitleItem")
    static let outputToggleItem = NSToolbarItem.Identifier("OutputToggleItem")
    static let inspectorToggleItem = NSToolbarItem.Identifier("InspectorToggleItem")
}
