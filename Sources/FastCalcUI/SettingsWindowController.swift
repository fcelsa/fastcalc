import AppKit

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
    private let previewValueLabel = NSTextField(labelWithString: "")
    private let activeOpacitySlider = NSSlider(value: 90, minValue: 10, maxValue: 100, target: nil, action: nil)
    private let activeOpacityLabel = NSTextField(labelWithString: "")
    private let inactiveOpacitySlider = NSSlider(value: 50, minValue: 10, maxValue: 100, target: nil, action: nil)
    private let inactiveOpacityLabel = NSTextField(labelWithString: "")
    private let defaultsButton = NSButton(title: "Default", target: nil, action: nil)
    private let okButton = NSButton(title: "OK", target: nil, action: nil)

    public init(settingsStore: AppSettingsStore = .shared) {
        self.settingsStore = settingsStore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
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

        // MARK: – Decimali / arrotondamento / anteprima

        decimalsPopup.addItems(withTitles: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "FL"])
        decimalsPopup.target = self
        decimalsPopup.action = #selector(decimalsChanged)
        decimalsPopup.setContentHuggingPriority(.required, for: .horizontal)

        roundingPopup.addItems(withTitles: ["Difetto", "Medio", "Eccesso"])
        roundingPopup.target = self
        roundingPopup.action = #selector(roundingChanged)
        roundingPopup.setContentHuggingPriority(.required, for: .horizontal)

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
        let startupRow = hRow([lbl("Apertura all'avvio"), startupModePopup])

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
            floatingRow, startupRow,
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
    private func opacityChanged() {
        updateDraftFromUI()
    }

    @objc
    private func confirmAndClose() {
        updateDraftFromUI()
        settingsStore.saveFormattingSettings(draftSettings)
        close()
    }

    @objc
    private func resetToDefaults() {
        draftSettings = AppSettingsStore.defaultFormattingSettings
        applyDraftToUI()
        updatePreview()
    }
}
