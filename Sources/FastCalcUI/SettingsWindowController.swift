import AppKit
import Carbon.HIToolbox

@MainActor
public final class SettingsWindowController: NSWindowController {
    private let settingsStore: AppSettingsStore
    private var draftSettings = FastCalcFormatSettings()
    private var previewSourceValue: Decimal?

    private let decimalsPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let roundingPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let allSpacesCheckbox = NSButton(checkboxWithTitle: "Visibile in tutti gli Spaces", target: nil, action: nil)
    private let defaultScreenPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let defaultScreenHintLabel = NSTextField(labelWithString: "")
    private let floatingWindowCheckbox = NSButton(checkboxWithTitle: "Mostra barra del titolo", target: nil, action: nil)
    private let alwaysOnTopCheckbox = NSButton(checkboxWithTitle: "Sempre in primo piano", target: nil, action: nil)
    private let startupModePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let hotKeyValueLabel = NSTextField(labelWithString: "")
    private let hotKeyCaptureButton = NSButton(title: "Registra", target: nil, action: nil)
    private let hotKeyResetButton = NSButton(title: "Default", target: nil, action: nil)
    private let hotKeyHintLabel = NSTextField(labelWithString: "")
    private let previewValueLabel = NSTextField(labelWithString: "")
    private let activeOpacitySlider = NSSlider(value: 90, minValue: 10, maxValue: 100, target: nil, action: nil)
    private let activeOpacityLabel = NSTextField(labelWithString: "")
    private let inactiveOpacitySlider = NSSlider(value: 50, minValue: 10, maxValue: 100, target: nil, action: nil)
    private let inactiveOpacityLabel = NSTextField(labelWithString: "")
    private let defaultsButton = NSButton(title: "Default", target: nil, action: nil)
    private let okButton = NSButton(title: "OK", target: nil, action: nil)
    private var hotKeyCaptureMonitor: Any?
    private var isCapturingHotKey = false

    public init(settingsStore: AppSettingsStore = .shared) {
        self.settingsStore = settingsStore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Impostazioni"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        setupView()
        loadFromSettings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func present() {
        loadFromSettings()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func setPreviewSourceValue(_ value: Decimal?) {
        previewSourceValue = value
    }

    private func setupView() {
        guard let contentView = window?.contentView else { return }

        // MARK: – Helpers

        func lbl(_ text: String, size: CGFloat = 13) -> NSTextField {
            let l = NSTextField(labelWithString: text)
            l.font = .systemFont(ofSize: size)
            l.setContentHuggingPriority(.required, for: .horizontal)
            l.setContentCompressionResistancePriority(.required, for: .horizontal)
            return l
        }

        func hRow(_ views: [NSView], spacing: CGFloat = 6) -> NSStackView {
            let s = NSStackView(views: views)
            s.orientation = .horizontal
            s.alignment = .centerY
            s.spacing = spacing
            return s
        }

        func configurePopup(_ popup: NSPopUpButton, minimumWidth: CGFloat) {
            popup.setContentHuggingPriority(.required, for: .horizontal)
            popup.setContentCompressionResistancePriority(.required, for: .horizontal)
            popup.widthAnchor.constraint(greaterThanOrEqualToConstant: minimumWidth).isActive = true
        }

        // MARK: – Decimali / arrotondamento / anteprima

        decimalsPopup.addItems(withTitles: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "FL"])
        decimalsPopup.target = self
        decimalsPopup.action = #selector(decimalsChanged)
        configurePopup(decimalsPopup, minimumWidth: 60)

        roundingPopup.addItems(withTitles: ["Difetto", "Medio", "Eccesso"])
        roundingPopup.target = self
        roundingPopup.action = #selector(roundingChanged)
        configurePopup(roundingPopup, minimumWidth: 112)

        previewValueLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        previewValueLabel.textColor = .secondaryLabelColor
        previewValueLabel.alignment = .left
        previewValueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let formatRow = hRow([
            lbl("Decimali"), decimalsPopup,
            lbl("Arrotondamento"), roundingPopup,
            lbl("Esempio"), previewValueLabel
        ], spacing: 10)

        // MARK: – Separatore

        let separator = NSBox()
        separator.boxType = .separator

        // MARK: – Comportamento finestra

        allSpacesCheckbox.target = self
        allSpacesCheckbox.action = #selector(windowBehaviorChanged)
        allSpacesCheckbox.setContentHuggingPriority(.required, for: .horizontal)
        let allSpacesTrailer = NSView()
        allSpacesTrailer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let allSpacesRow = hRow([allSpacesCheckbox, allSpacesTrailer])

        defaultScreenPopup.target = self
        defaultScreenPopup.action = #selector(windowBehaviorChanged)
        configurePopup(defaultScreenPopup, minimumWidth: 132)
        let screenRow = hRow([lbl("Schermo di default"), defaultScreenPopup])

        defaultScreenHintLabel.font = .systemFont(ofSize: 11)
        defaultScreenHintLabel.textColor = .secondaryLabelColor
        defaultScreenHintLabel.alignment = .left

        floatingWindowCheckbox.target = self
        floatingWindowCheckbox.action = #selector(windowBehaviorChanged)
        floatingWindowCheckbox.setContentHuggingPriority(.required, for: .horizontal)
        alwaysOnTopCheckbox.target = self
        alwaysOnTopCheckbox.action = #selector(windowBehaviorChanged)
        alwaysOnTopCheckbox.setContentHuggingPriority(.required, for: .horizontal)
        let floatingTrailer = NSView()
        floatingTrailer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let floatingRow = hRow([floatingWindowCheckbox, alwaysOnTopCheckbox, floatingTrailer], spacing: 12)

        startupModePopup.addItems(withTitles: ["Default", "Nascosta", "Visibile"])
        startupModePopup.target = self
        startupModePopup.action = #selector(windowBehaviorChanged)
        configurePopup(startupModePopup, minimumWidth: 110)
        let startupRow = hRow([lbl("Apertura all'avvio"), startupModePopup])

        hotKeyValueLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        hotKeyValueLabel.alignment = .left
        hotKeyValueLabel.setContentHuggingPriority(.required, for: .horizontal)
        hotKeyCaptureButton.target = self
        hotKeyCaptureButton.action = #selector(toggleHotKeyCapture)
        hotKeyCaptureButton.bezelStyle = .rounded
        hotKeyResetButton.target = self
        hotKeyResetButton.action = #selector(resetHotKeyToDefault)
        hotKeyResetButton.bezelStyle = .rounded
        let hotKeyTrailer = NSView()
        hotKeyTrailer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let hotKeyRow = hRow([lbl("Hotkey globale"), hotKeyValueLabel, hotKeyCaptureButton, hotKeyResetButton, hotKeyTrailer], spacing: 8)

        hotKeyHintLabel.font = .systemFont(ofSize: 11)
        hotKeyHintLabel.textColor = .secondaryLabelColor
        hotKeyHintLabel.alignment = .left
        hotKeyHintLabel.lineBreakMode = .byWordWrapping
        hotKeyHintLabel.maximumNumberOfLines = 2

        // MARK: – Slider opacità

        let opLabelWidth: CGFloat = 112

        activeOpacitySlider.target = self
        activeOpacitySlider.action = #selector(opacityChanged)
        activeOpacitySlider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        activeOpacityLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        activeOpacityLabel.alignment = .right
        activeOpacityLabel.textColor = .secondaryLabelColor
        activeOpacityLabel.setContentHuggingPriority(.required, for: .horizontal)
        let activeLbl = lbl("Opacità attiva")
        activeLbl.widthAnchor.constraint(equalToConstant: opLabelWidth).isActive = true
        let activeOpRow = hRow([activeLbl, activeOpacitySlider, activeOpacityLabel])

        inactiveOpacitySlider.target = self
        inactiveOpacitySlider.action = #selector(opacityChanged)
        inactiveOpacitySlider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        inactiveOpacityLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        inactiveOpacityLabel.alignment = .right
        inactiveOpacityLabel.textColor = .secondaryLabelColor
        inactiveOpacityLabel.setContentHuggingPriority(.required, for: .horizontal)
        let inactiveLbl = lbl("Opacità inattiva")
        inactiveLbl.widthAnchor.constraint(equalToConstant: opLabelWidth).isActive = true
        let inactiveOpRow = hRow([inactiveLbl, inactiveOpacitySlider, inactiveOpacityLabel])

        // MARK: – Bottone OK

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        defaultsButton.target = self
        defaultsButton.action = #selector(resetToDefaults)
        defaultsButton.bezelStyle = .rounded
        defaultsButton.widthAnchor.constraint(equalToConstant: 84).isActive = true
        okButton.target = self
        okButton.action = #selector(confirmAndClose)
        okButton.keyEquivalent = "\r"
        okButton.bezelStyle = .rounded
        okButton.widthAnchor.constraint(equalToConstant: 84).isActive = true
        let buttonRow = hRow([spacer, defaultsButton, okButton], spacing: 8)

        // MARK: – Root stack verticale

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .width
        root.spacing = 18
        root.edgeInsets = NSEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)
        root.translatesAutoresizingMaskIntoConstraints = false

        for view in [
            formatRow, separator,
            allSpacesRow, screenRow,
            floatingRow, startupRow, hotKeyRow, hotKeyHintLabel,
            activeOpRow, inactiveOpRow,
            buttonRow
        ] as [NSView] {
            root.addArrangedSubview(view)
        }
        root.setCustomSpacing(12, after: formatRow)
        root.setCustomSpacing(12, after: activeOpRow)

        contentView.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        window?.defaultButtonCell = okButton.cell as? NSButtonCell
    }

    private func loadFromSettings() {
        draftSettings = settingsStore.loadFormattingSettings()
        applyDraftToUI()
        updatePreview()
    }

    private func applyDraftToUI() {
        switch draftSettings.decimalMode {
        case .floating:
            decimalsPopup.selectItem(withTitle: "FL")
        case .fixed:
            let clampedPlaces = max(0, min(8, draftSettings.fixedDecimalPlaces))
            decimalsPopup.selectItem(withTitle: String(clampedPlaces))
        }

        switch draftSettings.roundingMode {
        case .down:
            roundingPopup.selectItem(at: 0)
        case .nearest:
            roundingPopup.selectItem(at: 1)
        case .up:
            roundingPopup.selectItem(at: 2)
        }

        allSpacesCheckbox.state = draftSettings.showOnAllSpaces ? .on : .off
        floatingWindowCheckbox.state = draftSettings.floatingWindowEnabled ? .on : .off
        alwaysOnTopCheckbox.state = draftSettings.alwaysOnTop ? .on : .off

        switch draftSettings.startupMode {
        case .default:
            startupModePopup.selectItem(at: 0)
        case .hidden:
            startupModePopup.selectItem(at: 1)
        case .visible:
            startupModePopup.selectItem(at: 2)
        }

        hotKeyValueLabel.stringValue = draftSettings.globalHotKey.displayName
        if !isCapturingHotKey {
            hotKeyHintLabel.stringValue = "Evita combinazioni gia usate dal sistema (es. Cmd+Space, Cmd+Tab)."
            hotKeyHintLabel.textColor = .secondaryLabelColor
        }

        activeOpacitySlider.doubleValue = draftSettings.activeWindowOpacity * 100
        inactiveOpacitySlider.doubleValue = draftSettings.inactiveWindowOpacity * 100
        updateOpacityLabels()

        reloadScreenChoices()
    }

    private func updateDraftFromUI() {
        if decimalsPopup.titleOfSelectedItem == "FL" {
            draftSettings.decimalMode = .floating
            draftSettings.fixedDecimalPlaces = 2
        } else {
            draftSettings.decimalMode = .fixed
            let fixedPlaces = Int(decimalsPopup.titleOfSelectedItem ?? "2") ?? 2
            draftSettings.fixedDecimalPlaces = max(0, min(8, fixedPlaces))
        }

        switch roundingPopup.indexOfSelectedItem {
        case 0:
            draftSettings.roundingMode = .down
        case 2:
            draftSettings.roundingMode = .up
        default:
            draftSettings.roundingMode = .nearest
        }

        draftSettings.showOnAllSpaces = allSpacesCheckbox.state == .on
        draftSettings.floatingWindowEnabled = floatingWindowCheckbox.state == .on
        draftSettings.alwaysOnTop = alwaysOnTopCheckbox.state == .on
        switch startupModePopup.indexOfSelectedItem {
        case 1:
            draftSettings.startupMode = .hidden
        case 2:
            draftSettings.startupMode = .visible
        default:
            draftSettings.startupMode = .default
        }

        draftSettings.activeWindowOpacity = activeOpacitySlider.doubleValue / 100
        draftSettings.inactiveWindowOpacity = inactiveOpacitySlider.doubleValue / 100
        updateOpacityLabels()

        if defaultScreenPopup.isEnabled {
            draftSettings.preferredScreenIndex = max(0, defaultScreenPopup.indexOfSelectedItem)
        } else {
            draftSettings.preferredScreenIndex = nil
        }
    }

    private func reloadScreenChoices() {
        let screens = NSScreen.screens
        defaultScreenPopup.removeAllItems()

        for index in screens.indices {
            defaultScreenPopup.addItem(withTitle: "Schermo \(index + 1)")
        }

        if screens.count <= 1 {
            if defaultScreenPopup.numberOfItems == 0 {
                defaultScreenPopup.addItem(withTitle: "Schermo 1")
            }
            defaultScreenPopup.selectItem(at: 0)
            defaultScreenPopup.isEnabled = false
            defaultScreenHintLabel.stringValue = "Opzione attiva solo con piu schermi collegati."
        } else {
            defaultScreenPopup.isEnabled = true
            let preferredIndex = min(max(0, draftSettings.preferredScreenIndex ?? 0), screens.count - 1)
            defaultScreenPopup.selectItem(at: preferredIndex)
            defaultScreenHintLabel.stringValue = "Usato per apertura e riposizionamento finestra."
        }
    }

    private func updatePreview() {
        let sample = previewSourceValue ?? Decimal(string: "1234.56789") ?? 0
        let rendered = TapeFormatter.formatDecimalForColumn(sample, settings: draftSettings)
        previewValueLabel.stringValue = rendered
    }

    private func updateOpacityLabels() {
        activeOpacityLabel.stringValue = "\(Int(activeOpacitySlider.doubleValue.rounded()))%"
        inactiveOpacityLabel.stringValue = "\(Int(inactiveOpacitySlider.doubleValue.rounded()))%"
    }

    @objc
    private func decimalsChanged() {
        updateDraftFromUI()
        updatePreview()
    }

    @objc
    private func roundingChanged() {
        updateDraftFromUI()
        updatePreview()
    }

    @objc
    private func windowBehaviorChanged() {
        updateDraftFromUI()
    }

    @objc
    private func toggleHotKeyCapture() {
        isCapturingHotKey ? stopHotKeyCapture(cancelled: true) : startHotKeyCapture()
    }

    @objc
    private func resetHotKeyToDefault() {
        stopHotKeyCapture(cancelled: true)
        draftSettings.globalHotKey = .f16
        hotKeyValueLabel.stringValue = draftSettings.globalHotKey.displayName
        hotKeyHintLabel.stringValue = "Hotkey ripristinata su F16."
        hotKeyHintLabel.textColor = .secondaryLabelColor
    }

    private func startHotKeyCapture() {
        stopHotKeyCapture(cancelled: true)
        isCapturingHotKey = true
        hotKeyCaptureButton.title = "Annulla"
        hotKeyHintLabel.stringValue = "Premi la nuova combinazione. Esc per annullare."
        hotKeyHintLabel.textColor = .secondaryLabelColor

        hotKeyCaptureMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, self.isCapturingHotKey else { return event }
            return self.handleHotKeyCapture(event)
        }
    }

    private func stopHotKeyCapture(cancelled: Bool) {
        if let hotKeyCaptureMonitor {
            NSEvent.removeMonitor(hotKeyCaptureMonitor)
            self.hotKeyCaptureMonitor = nil
        }

        if isCapturingHotKey {
            isCapturingHotKey = false
            hotKeyCaptureButton.title = "Registra"
            if cancelled {
                hotKeyHintLabel.stringValue = "Registrazione annullata."
                hotKeyHintLabel.textColor = .secondaryLabelColor
            }
        }
    }

    private func handleHotKeyCapture(_ event: NSEvent) -> NSEvent? {
        if event.type == .flagsChanged {
            hotKeyHintLabel.stringValue = "I soli tasti modificatori non sono validi."
            hotKeyHintLabel.textColor = .systemRed
            return nil
        }

        let keyCode = UInt32(event.keyCode)
        if keyCode == UInt32(kVK_Escape) {
            stopHotKeyCapture(cancelled: true)
            return nil
        }

        let candidate = GlobalHotKey(
            keyCode: keyCode,
            carbonModifiers: Self.carbonModifiers(from: event.modifierFlags)
        )

        switch Self.validateHotKey(candidate) {
        case .invalid(let message):
            NSSound.beep()
            hotKeyHintLabel.stringValue = message
            hotKeyHintLabel.textColor = .systemRed
        case .warning(let message):
            draftSettings.globalHotKey = candidate
            hotKeyValueLabel.stringValue = candidate.displayName
            hotKeyHintLabel.stringValue = message
            hotKeyHintLabel.textColor = .systemOrange
            stopHotKeyCapture(cancelled: false)
        case .valid:
            draftSettings.globalHotKey = candidate
            hotKeyValueLabel.stringValue = candidate.displayName
            hotKeyHintLabel.stringValue = "Hotkey aggiornata: \(candidate.displayName)."
            hotKeyHintLabel.textColor = .secondaryLabelColor
            stopHotKeyCapture(cancelled: false)
        }

        return nil
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        return modifiers
    }

    private enum HotKeyValidationResult {
        case valid
        case warning(String)
        case invalid(String)
    }

    private static func validateHotKey(_ hotKey: GlobalHotKey) -> HotKeyValidationResult {
        if isModifierOnlyKeyCode(hotKey.keyCode) {
            return .invalid("I soli tasti modificatori non sono consentiti.")
        }

        if !hotKey.isFunctionKey && !hotKey.hasModifiers {
            return .invalid("Per tasti non funzione usa almeno un modificatore (Cmd/Opt/Ctrl/Shift).")
        }

        if isHardBlockedShortcut(hotKey) {
            return .invalid("Combinazione riservata o troppo invasiva: scegli un'altra hotkey.")
        }

        if isLikelyReservedShortcut(hotKey) {
            return .warning("Combinazione probabilmente riservata dal sistema: verifica che funzioni sul tuo Mac.")
        }

        return .valid
    }

    private static func isModifierOnlyKeyCode(_ keyCode: UInt32) -> Bool {
        switch keyCode {
        case UInt32(kVK_Shift), UInt32(kVK_RightShift), UInt32(kVK_Command), UInt32(kVK_RightCommand), UInt32(kVK_Option), UInt32(kVK_RightOption), UInt32(kVK_Control), UInt32(kVK_RightControl), UInt32(kVK_CapsLock):
            return true
        default:
            return false
        }
    }

    private static func isHardBlockedShortcut(_ hotKey: GlobalHotKey) -> Bool {
        let cmd = UInt32(cmdKey)
        let cmdShift = UInt32(cmdKey | shiftKey)

        if hotKey.keyCode == UInt32(kVK_ANSI_Q) && hotKey.carbonModifiers == cmd { return true }
        if hotKey.keyCode == UInt32(kVK_ANSI_W) && hotKey.carbonModifiers == cmd { return true }
        if hotKey.keyCode == UInt32(kVK_ANSI_H) && hotKey.carbonModifiers == cmd { return true }
        if hotKey.keyCode == UInt32(kVK_ANSI_M) && hotKey.carbonModifiers == cmd { return true }
        if hotKey.keyCode == UInt32(kVK_Tab) && hotKey.carbonModifiers == cmd { return true }
        if hotKey.keyCode == UInt32(kVK_ANSI_3) && hotKey.carbonModifiers == cmdShift { return true }
        if hotKey.keyCode == UInt32(kVK_ANSI_4) && hotKey.carbonModifiers == cmdShift { return true }

        return false
    }

    private static func isLikelyReservedShortcut(_ hotKey: GlobalHotKey) -> Bool {
        let cmd = UInt32(cmdKey)
        let ctrl = UInt32(controlKey)
        let cmdShift = UInt32(cmdKey | shiftKey)

        if hotKey.keyCode == UInt32(kVK_Space) && hotKey.carbonModifiers == cmd { return true }
        if hotKey.keyCode == UInt32(kVK_Space) && hotKey.carbonModifiers == UInt32(cmdKey | optionKey) { return true }
        if hotKey.keyCode == UInt32(kVK_Space) && hotKey.carbonModifiers == ctrl { return true }
        if hotKey.keyCode == UInt32(kVK_Tab) && hotKey.carbonModifiers == UInt32(cmdKey | shiftKey) { return true }
        if hotKey.keyCode == UInt32(kVK_ANSI_5) && hotKey.carbonModifiers == cmdShift { return true }

        return false
    }

    @objc
    private func opacityChanged() {
        updateDraftFromUI()
    }

    @objc
    private func confirmAndClose() {
        stopHotKeyCapture(cancelled: true)
        updateDraftFromUI()
        settingsStore.saveFormattingSettings(draftSettings)
        close()
    }

    @objc
    private func resetToDefaults() {
        stopHotKeyCapture(cancelled: true)
        draftSettings = AppSettingsStore.defaultFormattingSettings
        applyDraftToUI()
        updatePreview()
    }

}
