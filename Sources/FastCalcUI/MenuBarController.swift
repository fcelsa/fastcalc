import AppKit

@MainActor
public final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let settingsStore: AppSettingsStore
    private let onToggle: @MainActor () -> Void
    private let onOpenSettings: @MainActor () -> Void
    private let onMoveToScreen: @MainActor (Int) -> Void

    public init(
        onToggle: @escaping @MainActor () -> Void,
        onOpenSettings: @escaping @MainActor () -> Void,
        onMoveToScreen: @escaping @MainActor (Int) -> Void,
        settingsStore: AppSettingsStore = .shared
    ) {
        self.settingsStore = settingsStore
        self.onToggle = onToggle
        self.onOpenSettings = onOpenSettings
        self.onMoveToScreen = onMoveToScreen
        super.init()
    }

    public func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "fc"

        let menu = NSMenu()
        menu.delegate = self
        rebuildMenu(menu)
        item.menu = menu

        statusItem = item
    }

    public func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu(menu)
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let toggleItem = NSMenuItem(title: "Apri/Chiudi (F16)", action: #selector(toggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let settingsItem = NSMenuItem(title: "Impostazioni...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        menu.addItem(settingsItem)

        let screens = NSScreen.screens
        if screens.count > 1 {
            let moveRoot = NSMenuItem(title: "Sposta su schermo", action: nil, keyEquivalent: "")
            let moveMenu = NSMenu()
            let selectedIndex = settingsStore.loadFormattingSettings().preferredScreenIndex

            for index in screens.indices {
                let item = NSMenuItem(title: "Schermo \(index + 1)", action: #selector(moveToScreen(_:)), keyEquivalent: "")
                item.tag = index
                item.state = selectedIndex == index ? .on : .off
                item.target = self
                moveMenu.addItem(item)
            }

            moveRoot.submenu = moveMenu
            menu.addItem(moveRoot)
        }

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Esci", action: #selector(quit), keyEquivalent: "q")
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
    private func moveToScreen(_ sender: NSMenuItem) {
        onMoveToScreen(sender.tag)
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
