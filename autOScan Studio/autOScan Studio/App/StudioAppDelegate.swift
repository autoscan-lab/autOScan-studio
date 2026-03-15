import AppKit

@MainActor
final class StudioAppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: StudioWindowController?
    private let state = StudioAppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1540, height: 940),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.minSize = NSSize(width: 1240, height: 800)
        window.center()
        window.title = "autOScan Studio"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = StudioTheme.canvasColor
        window.appearance = NSAppearance(named: .darkAqua)
        window.isOpaque = true

        let splitViewController = StudioSplitViewController(state: state)
        window.contentViewController = splitViewController

        let windowController = StudioWindowController(
            window: window,
            splitViewController: splitViewController,
            state: state
        )
        self.windowController = windowController

        windowController.showWindow(self)
        window.makeKeyAndOrderFront(self)

        ensureMainMenu()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc
    private func openWorkspaceFromMenu(_ sender: Any?) {
        state.openWorkspacePanel()
    }

    private func ensureMainMenu() {
        let mainMenu = NSApp.mainMenu ?? NSMenu(title: "MainMenu")
        if NSApp.mainMenu == nil {
            NSApp.mainMenu = mainMenu
        }

        ensureAppMenu(in: mainMenu)
        ensureTopLevelMenu(title: "File", in: mainMenu, index: 1, builder: configureFileMenuIfNeeded)
        ensureTopLevelMenu(title: "Edit", in: mainMenu, index: 2, builder: configureEditMenuIfNeeded)
        ensureTopLevelMenu(title: "View", in: mainMenu, index: 3, builder: configureViewMenuIfNeeded)
        ensureTopLevelMenu(title: "Window", in: mainMenu, index: 4, builder: configureWindowMenuIfNeeded)
        ensureTopLevelMenu(title: "Help", in: mainMenu, index: 5, builder: configureHelpMenuIfNeeded)
    }

    private func ensureAppMenu(in mainMenu: NSMenu) {
        if let existingIndex = mainMenu.items.firstIndex(where: { $0.submenu?.title == "autOScan Studio" }) {
            let item = mainMenu.items[existingIndex]
            if existingIndex != 0 {
                mainMenu.removeItem(at: existingIndex)
                mainMenu.insertItem(item, at: 0)
            }
            return
        }

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "autOScan Studio")

        appMenu.addItem(
            withTitle: "About autOScan Studio",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            withTitle: "Hide autOScan Studio",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )

        let hideOthers = NSMenuItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)

        appMenu.addItem(
            withTitle: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            withTitle: "Quit autOScan Studio",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        appMenuItem.submenu = appMenu
        mainMenu.insertItem(appMenuItem, at: 0)
    }

    private func ensureTopLevelMenu(
        title: String,
        in mainMenu: NSMenu,
        index: Int,
        builder: (NSMenu) -> Void
    ) {
        let item: NSMenuItem
        if let existing = mainMenu.items.first(where: { $0.title == title }) {
            item = existing
        } else {
            item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = NSMenu(title: title)
            mainMenu.addItem(item)
        }

        if let currentIndex = mainMenu.items.firstIndex(of: item), currentIndex != index {
            mainMenu.removeItem(at: currentIndex)
            mainMenu.insertItem(item, at: min(index, mainMenu.items.count))
        }

        if let submenu = item.submenu {
            builder(submenu)
        }
    }

    private func configureFileMenuIfNeeded(_ fileMenu: NSMenu) {
        if fileMenu.items.contains(where: { $0.action == #selector(openWorkspaceFromMenu(_:)) }) {
            return
        }

        let openWorkspaceItem = NSMenuItem(
            title: "Open Workspace…",
            action: #selector(openWorkspaceFromMenu(_:)),
            keyEquivalent: "o"
        )
        openWorkspaceItem.target = self
        openWorkspaceItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.insertItem(openWorkspaceItem, at: 0)
    }

    private func configureEditMenuIfNeeded(_ editMenu: NSMenu) {
        guard editMenu.items.isEmpty else {
            return
        }

        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    }

    private func configureViewMenuIfNeeded(_ viewMenu: NSMenu) {
        guard viewMenu.items.isEmpty else {
            return
        }

        viewMenu.addItem(
            withTitle: "Enter Full Screen",
            action: #selector(NSWindow.toggleFullScreen(_:)),
            keyEquivalent: "f"
        )
    }

    private func configureWindowMenuIfNeeded(_ windowMenu: NSMenu) {
        guard windowMenu.items.isEmpty else {
            NSApp.windowsMenu = windowMenu
            return
        }

        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(
            withTitle: "Bring All to Front",
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        )
        NSApp.windowsMenu = windowMenu
    }

    private func configureHelpMenuIfNeeded(_ helpMenu: NSMenu) {
        guard helpMenu.items.isEmpty else {
            return
        }

        helpMenu.addItem(withTitle: "autOScan Studio Help", action: nil, keyEquivalent: "?")
    }

}
