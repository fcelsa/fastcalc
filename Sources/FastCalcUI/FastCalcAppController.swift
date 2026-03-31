import AppKit
import FastCalcCore

@MainActor
public final class FastCalcAppController: NSObject, NSApplicationDelegate {
    private let stateStore = AppStateStore()
    private let engine = CalculatorEngine()
    private let settingsStore = AppSettingsStore.shared
    private var windowController: RollWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var menuBarController: MenuBarController?
    private var hotKeyMonitor: HotKeyMonitor?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMainMenu()

        let windowController = RollWindowController(stateStore: stateStore)
        self.windowController = windowController

        let menuBar = MenuBarController(
            onToggle: { [weak self] in
                self?.toggleWindow()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            },
            onMoveToScreen: { [weak self] screenIndex in
                self?.moveWindowToScreen(screenIndex)
            }
        )
        menuBar.install()
        self.menuBarController = menuBar

        let hotKey = HotKeyMonitor()
        let hotKeyBound = hotKey.registerF16 { [weak self] in
            self?.toggleWindow()
        }
        if !hotKeyBound {
            print("[fastcalc] Warning: impossibile registrare la hotkey F16")
        }
        self.hotKeyMonitor = hotKey

        windowController.loadPersistedVisibility()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        windowController?.persistState()
        hotKeyMonitor?.unregister()
    }

    private func toggleWindow() {
        windowController?.toggleVisibility()
    }

    private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(settingsStore: settingsStore)
        }
        settingsWindowController?.setPreviewSourceValue(windowController?.currentPreviewValue())
        settingsWindowController?.present()
    }

    private func moveWindowToScreen(_ screenIndex: Int) {
        windowController?.moveWindowToScreen(screenIndex, persistPreference: true)
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let settingsItem = NSMenuItem(title: "Impostazioni...", action: #selector(openSettingsFromMenu(_:)), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())

        let appName = ProcessInfo.processInfo.processName
        let quitItem = NSMenuItem(title: "Esci \(appName)", action: #selector(quitFromMenu(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        appMenu.addItem(quitItem)

        NSApp.mainMenu = mainMenu
    }

    @objc
    private func openSettingsFromMenu(_ sender: Any?) {
        openSettings()
    }

    @objc
    private func quitFromMenu(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }

    // Esposto per la fase successiva di wiring tasti/engine.
    public func resetEverythingFromDoubleDelete() {
        _ = engine.pressDelete()
        _ = engine.pressDelete()
        windowController?.resetRollAndPlacement()
        stateStore.clearAll()
    }
}
