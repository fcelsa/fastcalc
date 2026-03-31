import AppKit

@MainActor
public final class MenuBarController {
    private var statusItem: NSStatusItem?
    private let onToggle: @MainActor () -> Void
    private let onOpenSettings: @MainActor () -> Void

    public init(
        onToggle: @escaping @MainActor () -> Void,
        onOpenSettings: @escaping @MainActor () -> Void
    ) {
        self.onToggle = onToggle
        self.onOpenSettings = onOpenSettings
    }

    public func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "fc"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Apri/Chiudi (F16)", action: #selector(toggle), keyEquivalent: ""))
        let settingsItem = NSMenuItem(title: "Impostazioni...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Esci", action: #selector(quit), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        menu.addItem(quitItem)

        menu.items[0].target = self
        menu.items[1].target = self
        menu.items[3].target = self
        item.menu = menu

        statusItem = item
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
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
