import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceTreeView: NSViewControllerRepresentable {
    @ObservedObject var state: StudioAppState
    let mode: StudioAppState.SidebarMode

    func makeNSViewController(context: Context) -> WorkspaceTreeViewController {
        let controller = WorkspaceTreeViewController()
        controller.update(state: state, mode: mode)
        return controller
    }

    func updateNSViewController(_ controller: WorkspaceTreeViewController, context: Context) {
        controller.update(state: state, mode: mode)
    }
}

@MainActor
final class WorkspaceTreeViewController: NSViewController {
    private var state: StudioAppState?
    private var mode: StudioAppState.SidebarMode = .workspace

    private var scrollView: NSScrollView!
    private var outlineView: NSOutlineView!
    private var nodes: [WorkspaceNode] = []
    private var treeFingerprint = ""
    private var hasReloadedTree = false
    private var suppressSelectionCallback = false
    private var suppressExpansionCallback = false
    private let iconCache = NSCache<NSString, NSImage>()

    override func loadView() {
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = StudioTheme.sidebarColor.cgColor

        scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.backgroundColor = StudioTheme.sidebarColor
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.contentView.automaticallyAdjustsContentInsets = false
        scrollView.contentView.contentInsets = NSEdgeInsets(top: 8, left: 12, bottom: 0, right: 0)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.rowHeight = 20
        outlineView.selectionHighlightStyle = .regular
        outlineView.floatsGroupRows = false
        outlineView.focusRingType = .none
        outlineView.usesAlternatingRowBackgroundColors = false
        outlineView.backgroundColor = StudioTheme.sidebarColor
        outlineView.style = .plain
        outlineView.allowsMultipleSelection = false
        outlineView.autosaveExpandedItems = true
        outlineView.indentationPerLevel = 13
        outlineView.intercellSpacing = NSSize(width: 0, height: 2)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("WorkspaceColumn"))
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        scrollView.documentView = outlineView
        containerView.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        view = containerView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadUIIfLoaded(reloadTree: true)
    }

    func update(state: StudioAppState, mode: StudioAppState.SidebarMode) {
        let updatedNodes = state.nodes(for: mode)
        let updatedFingerprint = makeTreeFingerprint(nodes: updatedNodes, mode: mode)
        let shouldReloadTree = !hasReloadedTree || updatedFingerprint != treeFingerprint

        self.state = state
        self.mode = mode
        nodes = updatedNodes
        treeFingerprint = updatedFingerprint

        reloadUIIfLoaded(reloadTree: shouldReloadTree)
    }

    private func reloadUIIfLoaded(reloadTree: Bool) {
        guard isViewLoaded else {
            return
        }

        if reloadTree {
            outlineView.reloadData()
            hasReloadedTree = true
        }

        applyExpandedState()
        applySelectionState()
    }

    private func applyExpandedState() {
        guard mode == .workspace, let state else {
            return
        }

        suppressExpansionCallback = true
        defer {
            suppressExpansionCallback = false
        }

        for row in 0..<outlineView.numberOfRows {
            guard let node = outlineView.item(atRow: row) as? WorkspaceNode, node.isDirectory else {
                continue
            }

            let shouldBeExpanded = state.isDirectoryExpanded(node.id)
            let isExpanded = outlineView.isItemExpanded(node)
            guard shouldBeExpanded != isExpanded else {
                continue
            }

            if shouldBeExpanded {
                outlineView.expandItem(node)
            } else {
                outlineView.collapseItem(node, collapseChildren: true)
            }
        }
    }

    private func applySelectionState() {
        guard let state else {
            return
        }

        guard let selectedNodeID = state.selectedSidebarNodeID(for: mode) else {
            guard outlineView.selectedRow != -1 else {
                return
            }

            suppressSelectionCallback = true
            outlineView.deselectAll(nil)
            suppressSelectionCallback = false
            return
        }

        if let node = findNode(withID: selectedNodeID, in: nodes) {
            let row = outlineView.row(forItem: node)
            if row >= 0, outlineView.selectedRow != row {
                suppressSelectionCallback = true
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                suppressSelectionCallback = false
            }
        }
    }

    private func findNode(withID id: String, in list: [WorkspaceNode]) -> WorkspaceNode? {
        for node in list {
            if node.id == id {
                return node
            }
            if let child = findNode(withID: id, in: node.children) {
                return child
            }
        }
        return nil
    }

    private func makeTreeFingerprint(nodes: [WorkspaceNode], mode: StudioAppState.SidebarMode) -> String {
        var output = mode.rawValue
        output.reserveCapacity(max(64, nodes.count * 12))

        func append(nodes: [WorkspaceNode]) {
            for node in nodes {
                output += "|"
                output += node.id
                output += node.isDirectory ? "d" : "f"
                if !node.children.isEmpty {
                    append(nodes: node.children)
                }
            }
        }

        append(nodes: nodes)
        return output
    }

    private func iconImage(for node: WorkspaceNode) -> NSImage {
        let cacheKey = NSString(string: node.id)
        if let cachedImage = iconCache.object(forKey: cacheKey) {
            return cachedImage
        }

        let image: NSImage
        if let customImage = customAssetIcon(for: node) {
            image = customImage
        } else if let fileURL = state?.fileURL(forNodeID: node.id) {
            image = NSWorkspace.shared.icon(forFile: fileURL.path)
        } else if node.isDirectory {
            image = NSWorkspace.shared.icon(for: .folder)
        } else {
            let ext = URL(fileURLWithPath: node.id).pathExtension
            let type = UTType(filenameExtension: ext) ?? .text
            image = NSWorkspace.shared.icon(for: type)
        }

        image.size = NSSize(width: 16, height: 16)
        iconCache.setObject(image, forKey: cacheKey)
        return image
    }

    private func customAssetIcon(for node: WorkspaceNode) -> NSImage? {
        guard
            !node.isDirectory,
            let fileURL = state?.fileURL(forNodeID: node.id)
        else {
            return nil
        }

        let ext = fileURL.pathExtension.lowercased()
        let assetName: String
        switch ext {
        case "c":
            assetName = "FileTypeC"
        case "h", "hh", "hpp":
            assetName = "FileTypeH"
        case "cpp", "cc", "cxx":
            assetName = "FileTypeCpp"
        case "md", "markdown":
            assetName = "FileTypeMd"
        default:
            return nil
        }

        return NSImage(named: NSImage.Name(assetName))
    }

    private func makeCellView(for node: WorkspaceNode) -> NSTableCellView {
        let identifier = NSUserInterfaceItemIdentifier("WorkspaceCell")
        let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
        ?? NSTableCellView(frame: .zero)
        cell.identifier = identifier

        let imageView: NSImageView
        if let existingImageView = cell.imageView {
            imageView = existingImageView
        } else {
            imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(imageView)
            cell.imageView = imageView
        }

        let textField: NSTextField
        if let existingTextField = cell.textField {
            textField = existingTextField
        } else {
            textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingMiddle
            textField.font = .systemFont(ofSize: 13, weight: .regular)
            cell.addSubview(textField)
            cell.textField = textField
        }

        if cell.constraints.isEmpty {
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 13),
                imageView.heightAnchor.constraint(equalToConstant: 13),

                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 5),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        imageView.contentTintColor = nil
        imageView.image = iconImage(for: node)
        textField.stringValue = node.name
        textField.textColor = node.isDirectory ? StudioTheme.textSecondaryColor : StudioTheme.textPrimaryColor
        return cell
    }
}

extension WorkspaceTreeViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let node = item as? WorkspaceNode else {
            return nodes.count
        }
        return node.children.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        guard let node = item as? WorkspaceNode else {
            return nodes[index]
        }
        return node.children[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? WorkspaceNode else {
            return false
        }
        return node.isDirectory
    }
}

extension WorkspaceTreeViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        guard let node = item as? WorkspaceNode else {
            return false
        }

        if node.isDirectory {
            let shouldExpand = !outlineView.isItemExpanded(node)
            suppressExpansionCallback = true
            if shouldExpand {
                outlineView.expandItem(node)
            } else {
                outlineView.collapseItem(node, collapseChildren: true)
            }
            suppressExpansionCallback = false
            DispatchQueue.main.async { [weak self] in
                self?.state?.setDirectoryExpanded(node.id, isExpanded: shouldExpand)
            }
            return false
        }

        return true
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? WorkspaceNode else {
            return nil
        }
        return makeCellView(for: node)
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !suppressSelectionCallback else {
            return
        }

        let row = outlineView.selectedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? WorkspaceNode else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.state?.handleSidebarSelection(nodeID: node.id, mode: self?.mode ?? .workspace)
        }
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        guard !suppressExpansionCallback else {
            return
        }
        guard let node = notification.userInfo?["NSObject"] as? WorkspaceNode else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.state?.setDirectoryExpanded(node.id, isExpanded: true)
        }
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard !suppressExpansionCallback else {
            return
        }
        guard let node = notification.userInfo?["NSObject"] as? WorkspaceNode else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.state?.setDirectoryExpanded(node.id, isExpanded: false)
        }
    }
}
