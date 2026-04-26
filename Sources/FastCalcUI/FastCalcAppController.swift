import AppKit
import FastCalcCore

@MainActor
public final class FastCalcAppController: NSObject, NSApplicationDelegate {
    private let stateStore = AppStateStore()
    private let engine = CalculatorEngine()
    private let settingsStore = AppSettingsStore.shared
    private var windowController: RollWindowController?
    private var aboutWindowController: AboutWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var menuBarController: MenuBarController?
    private var hotKeyMonitor: HotKeyMonitor?
    private var lastFocusedAppPID: pid_t?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        applyActivationPolicyFromSettings()
        installMainMenu()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: .fastCalcSettingsDidChange,
            object: nil
        )

        let windowController = RollWindowController(stateStore: stateStore)
        windowController.onEscapeFocusReturnRequested = { [weak self] in
            self?.returnFocusToPreviousAppWithoutHiding()
        }
        self.windowController = windowController

        let menuBar = MenuBarController(
            onToggle: { [weak self] in
                self?.toggleWindow()
            },
            onOpenAbout: { [weak self] in
                self?.openAbout()
            },
            onCopyTapeText: { [weak self] in
                self?.copyTapeTextToClipboard()
            },
            onCopyVisiblePNG: { [weak self] in
                self?.copyVisiblePNGToClipboard()
            },
            onPrint: { [weak self] in
                self?.printTape()
            },
            onExportPDF: { [weak self] in
                self?.exportTapePDF()
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
        let hotKeyBound = registerConfiguredHotKey(using: hotKey)
        if !hotKeyBound {
            print("[fastcalc] Warning: impossibile registrare la hotkey configurata")
        }
        self.hotKeyMonitor = hotKey

        windowController.loadPersistedVisibility()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        windowController?.persistState()
        hotKeyMonitor?.unregister()
        NotificationCenter.default.removeObserver(self, name: .fastCalcSettingsDidChange, object: nil)
    }

    @objc
    private func settingsDidChange() {
        applyActivationPolicyFromSettings()
        let settings = settingsStore.loadFormattingSettings()
        menuBarController?.updateVisibility(isVisible: settings.menuBarIconEnabled)
        if let hotKeyMonitor {
            _ = registerConfiguredHotKey(using: hotKeyMonitor)
        }
        installMainMenu()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
            return true
        }

        windowController?.showWindow()
        return true
    }

    public func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        menuBarController?.makeMenu()
    }

    private func registerConfiguredHotKey(using monitor: HotKeyMonitor) -> Bool {
        let configured = settingsStore.loadFormattingSettings().globalHotKey
        let bound = monitor.register(configured) { [weak self] in
            self?.toggleWindow()
        }

        if !bound {
            return monitor.register(.f16) { [weak self] in
                self?.toggleWindow()
            }
        }

        return true
    }

    private func applyActivationPolicyFromSettings() {
        let settings = settingsStore.loadFormattingSettings()
        let targetPolicy: NSApplication.ActivationPolicy = settings.dockIconEnabled ? .regular : .accessory
        if NSApp.activationPolicy() != targetPolicy {
            let switched = NSApp.setActivationPolicy(targetPolicy)
            if !switched {
                print("[fastcalc] Warning: impossibile cambiare activation policy a \(targetPolicy)")
            }
        }

        if targetPolicy == .regular {
            // Ensure main menu becomes visible after switching from accessory mode.
            installMainMenu()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func toggleWindow() {
        guard let windowController, let window = windowController.window else {
            windowController?.toggleVisibility()
            return
        }

        let shouldCapturePreviousFocus = !window.isVisible || !window.isKeyWindow
        if shouldCapturePreviousFocus {
            captureCurrentFrontmostApplication()
        }

        let wasVisibleAndKey = window.isVisible && window.isKeyWindow
        windowController.toggleVisibility()

        if wasVisibleAndKey {
            restorePreviousFocusOrFallback(clearTrackedPreviousApp: true)
        }
    }

    private func showMainWindow() {
        captureCurrentFrontmostApplication()
        windowController?.showWindow()
    }

    private func returnFocusToPreviousAppWithoutHiding() {
        restorePreviousFocusOrFallback(clearTrackedPreviousApp: false)
    }

    private func captureCurrentFrontmostApplication() {
        let currentPID = NSRunningApplication.current.processIdentifier
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              frontmostApp.processIdentifier != currentPID else {
            return
        }

        lastFocusedAppPID = frontmostApp.processIdentifier
    }

    private func restorePreviousFocusOrFallback(clearTrackedPreviousApp: Bool) {
        if let pid = lastFocusedAppPID,
           let app = NSRunningApplication(processIdentifier: pid),
           app.processIdentifier != NSRunningApplication.current.processIdentifier,
           app.activate(options: [.activateIgnoringOtherApps]) {
            if clearTrackedPreviousApp {
                lastFocusedAppPID = nil
            }
            return
        }

        let finderBundleIdentifier = "com.apple.finder"
        if let finder = NSRunningApplication.runningApplications(withBundleIdentifier: finderBundleIdentifier).first {
            _ = finder.activate(options: [.activateIgnoringOtherApps])
        }

        if clearTrackedPreviousApp {
            lastFocusedAppPID = nil
        }
    }

    private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(settingsStore: settingsStore)
        }
        settingsWindowController?.setPreviewSourceValue(windowController?.currentPreviewValue())
        settingsWindowController?.present()
    }

    private func openAbout() {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController()
        }
        aboutWindowController?.present()
    }

    private func printTape() {
        windowController?.printTape()
    }

    private func copyTapeTextToClipboard() {
        windowController?.copyTapeTextToClipboard()
    }

    private func copyPreferredNumericToClipboard() {
        windowController?.copyPreferredNumericToClipboard()
    }

    private func copyVisiblePNGToClipboard() {
        windowController?.copyVisibleWindowPNGToClipboard()
    }

    private func exportTapePDF() {
        windowController?.exportTapePDF()
    }

    private func moveWindowToScreen(_ screenIndex: Int) {
        windowController?.moveWindowToScreen(screenIndex, persistPreference: true)
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()
        let hotKeyName = settingsStore.loadFormattingSettings().globalHotKey.displayName

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let aboutItem = NSMenuItem(title: "Informazioni su FastCalc...", action: #selector(openAboutFromMenu(_:)), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)

        appMenu.addItem(.separator())

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

        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu

        let printItem = NSMenuItem(title: "Stampa...", action: #selector(printFromMenu(_:)), keyEquivalent: "p")
        printItem.keyEquivalentModifierMask = [.command]
        printItem.target = self
        fileMenu.addItem(printItem)

        let exportPDFItem = NSMenuItem(title: "Esporta PDF...", action: #selector(exportPDFFromMenu(_:)), keyEquivalent: "")
        exportPDFItem.target = self
        fileMenu.addItem(exportPDFItem)

        let editMenuItem = NSMenuItem(title: "Modifica", action: nil, keyEquivalent: "")
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Modifica")
        editMenuItem.submenu = editMenu

        let undoItem = NSMenuItem(title: "Annulla", action: Selector(("undo:")), keyEquivalent: "z")
        undoItem.keyEquivalentModifierMask = [.command]
        editMenu.addItem(undoItem)

        let redoItem = NSMenuItem(title: "Ripristina", action: Selector(("redo:")), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)

        editMenu.addItem(.separator())

        let cutItem = NSMenuItem(title: "Taglia", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        cutItem.keyEquivalentModifierMask = [.command]
        editMenu.addItem(cutItem)

        let copyItem = NSMenuItem(title: "Copia", action: #selector(copyPreferredNumericFromMenu(_:)), keyEquivalent: "c")
        copyItem.keyEquivalentModifierMask = [.command]
        copyItem.target = self
        editMenu.addItem(copyItem)

        let pasteItem = NSMenuItem(title: "Incolla", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        pasteItem.keyEquivalentModifierMask = [.command]
        editMenu.addItem(pasteItem)

        editMenu.addItem(.separator())

        let copyTapeItem = NSMenuItem(title: "Copia come testo", action: #selector(copyTapeFromMenu(_:)), keyEquivalent: "C")
        copyTapeItem.keyEquivalentModifierMask = [.command, .shift]
        copyTapeItem.target = self
        editMenu.addItem(copyTapeItem)

        let copyPNGItem = NSMenuItem(title: "Copia come immagine", action: #selector(copyVisiblePNGFromMenu(_:)), keyEquivalent: "C")
        copyPNGItem.keyEquivalentModifierMask = [.command, .option, .shift]
        copyPNGItem.target = self
        editMenu.addItem(copyPNGItem)

        let viewMenuItem = NSMenuItem(title: "Vista", action: nil, keyEquivalent: "")
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "Vista")
        viewMenuItem.submenu = viewMenu

        let toggleItem = NSMenuItem(title: "Visualizza/Nascondi (\(hotKeyName))", action: #selector(toggleFromMenu(_:)), keyEquivalent: "")
        toggleItem.target = self
        viewMenu.addItem(toggleItem)

        let screens = NSScreen.screens
        if screens.count > 1 {
            let moveRoot = NSMenuItem(title: "Sposta su schermo", action: nil, keyEquivalent: "")
            let moveMenu = NSMenu(title: "Sposta su schermo")
            let selectedIndex = settingsStore.loadFormattingSettings().preferredScreenIndex

            for index in screens.indices {
                let item = NSMenuItem(title: "Schermo \(index + 1)", action: #selector(moveToScreenFromMenu(_:)), keyEquivalent: "")
                item.tag = index
                item.state = selectedIndex == index ? .on : .off
                item.target = self
                moveMenu.addItem(item)
            }

            moveRoot.submenu = moveMenu
            viewMenu.addItem(moveRoot)
        } else {
            let moveRoot = NSMenuItem(title: "Sposta su schermo", action: nil, keyEquivalent: "")
            moveRoot.isEnabled = false
            viewMenu.addItem(moveRoot)
        }

        NSApp.mainMenu = mainMenu
    }

    @objc
    private func openSettingsFromMenu(_ sender: Any?) {
        openSettings()
    }

    @objc
    private func openAboutFromMenu(_ sender: Any?) {
        openAbout()
    }

    @objc
    private func printFromMenu(_ sender: Any?) {
        printTape()
    }

    @objc
    private func copyPreferredNumericFromMenu(_ sender: Any?) {
        copyPreferredNumericToClipboard()
    }

    @objc
    private func toggleFromMenu(_ sender: Any?) {
        toggleWindow()
    }

    @objc
    private func copyTapeFromMenu(_ sender: Any?) {
        copyTapeTextToClipboard()
    }

    @objc
    private func copyVisiblePNGFromMenu(_ sender: Any?) {
        copyVisiblePNGToClipboard()
    }

    @objc
    private func exportPDFFromMenu(_ sender: Any?) {
        exportTapePDF()
    }

    @objc
    private func moveToScreenFromMenu(_ sender: NSMenuItem) {
        moveWindowToScreen(sender.tag)
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
