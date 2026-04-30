import AppKit

@MainActor
public final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let settingsStore: AppSettingsStore
    private let onToggle: @MainActor () -> Void
    private let onOpenAbout: @MainActor () -> Void
    private let onCopyTapeText: @MainActor () -> Void
    private let onCopyVisiblePNG: @MainActor () -> Void
    private let onPrint: @MainActor () -> Void
    private let onExportPDF: @MainActor () -> Void
    private let onOpenSettings: @MainActor () -> Void
    private let onMoveToScreen: @MainActor (Int) -> Void

    public init(
        onToggle: @escaping @MainActor () -> Void,
        onOpenAbout: @escaping @MainActor () -> Void,
        onCopyTapeText: @escaping @MainActor () -> Void,
        onCopyVisiblePNG: @escaping @MainActor () -> Void,
        onPrint: @escaping @MainActor () -> Void,
        onExportPDF: @escaping @MainActor () -> Void,
        onOpenSettings: @escaping @MainActor () -> Void,
        onMoveToScreen: @escaping @MainActor (Int) -> Void,
        settingsStore: AppSettingsStore = .shared
    ) {
        self.settingsStore = settingsStore
        self.onToggle = onToggle
        self.onOpenAbout = onOpenAbout
        self.onCopyTapeText = onCopyTapeText
        self.onCopyVisiblePNG = onCopyVisiblePNG
        self.onPrint = onPrint
        self.onExportPDF = onExportPDF
        self.onOpenSettings = onOpenSettings
        self.onMoveToScreen = onMoveToScreen
        super.init()
    }

    public func install() {
        updateVisibility(isVisible: settingsStore.loadFormattingSettings().menuBarIconEnabled)
    }

    public func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        rebuildMenu(menu)
        return menu
    }

    public func updateVisibility(isVisible: Bool) {
        if isVisible {
            installStatusItemIfNeeded()
        } else {
            removeStatusItem()
        }
    }

    private func installStatusItemIfNeeded() {
        guard statusItem == nil else {
            if let menu = statusItem?.menu {
                rebuildMenu(menu)
            }
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = L10n.Menu.statusIconTitle
        item.menu = makeMenu()

        statusItem = item
    }

    private func removeStatusItem() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    public func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu(menu)
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let hotKeyName = settingsStore.loadFormattingSettings().globalHotKey.displayName

        let toggleItem = NSMenuItem(title: L10n.Menu.toggleWithHotKey(hotKeyName), action: #selector(toggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let aboutItem = NSMenuItem(title: L10n.Menu.about, action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let copyItem = NSMenuItem(title: L10n.Menu.copyText, action: #selector(copyTapeText), keyEquivalent: "")
        copyItem.target = self
        menu.addItem(copyItem)

        let copyPNGItem = NSMenuItem(title: L10n.Menu.copyImage, action: #selector(copyVisiblePNG), keyEquivalent: "")
        copyPNGItem.target = self
        menu.addItem(copyPNGItem)

        let printItem = NSMenuItem(title: L10n.Menu.print, action: #selector(printTape), keyEquivalent: "p")
        printItem.keyEquivalentModifierMask = [.command]
        printItem.target = self
        menu.addItem(printItem)

        let exportItem = NSMenuItem(title: L10n.Menu.exportPdf, action: #selector(exportPDF), keyEquivalent: "")
        exportItem.target = self
        menu.addItem(exportItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: L10n.Menu.settings, action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        menu.addItem(settingsItem)

        let screens = NSScreen.screens
        if screens.count > 1 {
            let moveRoot = NSMenuItem(title: L10n.Menu.moveToScreen, action: nil, keyEquivalent: "")
            let moveMenu = NSMenu()
            let selectedIndex = settingsStore.loadFormattingSettings().preferredScreenIndex

            for index in screens.indices {
                let item = NSMenuItem(title: L10n.Menu.screen(index + 1), action: #selector(moveToScreen(_:)), keyEquivalent: "")
                item.tag = index
                item.state = selectedIndex == index ? .on : .off
                item.target = self
                moveMenu.addItem(item)
            }

            moveRoot.submenu = moveMenu
            menu.addItem(moveRoot)
        }

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: L10n.Menu.quit, action: #selector(quit), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc
    private func toggle() {
        onToggle()
    }

    @objc
    private func openSettings() {
        onOpenSettings()
    }

    @objc
    private func openAbout() {
        onOpenAbout()
    }

    @objc
    private func copyTapeText() {
        onCopyTapeText()
    }

    @objc
    private func copyVisiblePNG() {
        onCopyVisiblePNG()
    }

    @objc
    private func printTape() {
        onPrint()
    }

    @objc
    private func exportPDF() {
        onExportPDF()
    }

    @objc
    private func moveToScreen(_ sender: NSMenuItem) {
        onMoveToScreen(sender.tag)
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
