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
    private let floatingWindowCheckbox = NSButton(checkboxWithTitle: "Floating (spostabile)", target: nil, action: nil)
    private let previewValueLabel = NSTextField(labelWithString: "")
    private let roundingEffectLabel = NSTextField(labelWithString: "")
    private let okButton = NSButton(title: "OK", target: nil, action: nil)

    public init(settingsStore: AppSettingsStore = .shared) {
        self.settingsStore = settingsStore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 350),
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

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 10
        root.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        root.translatesAutoresizingMaskIntoConstraints = false

        let decimalsLabel = NSTextField(labelWithString: "Decimali")
        decimalsLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        decimalsPopup.addItems(withTitles: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "FL"])
        decimalsPopup.target = self
        decimalsPopup.action = #selector(decimalsChanged)

        let roundingLabel = NSTextField(labelWithString: "Arrotondamenti")
        roundingLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        roundingPopup.addItems(withTitles: ["Difetto", "Medio", "Eccesso"])
        roundingPopup.target = self
        roundingPopup.action = #selector(roundingChanged)

        allSpacesCheckbox.target = self
        allSpacesCheckbox.action = #selector(windowBehaviorChanged)

        defaultScreenPopup.target = self
        defaultScreenPopup.action = #selector(windowBehaviorChanged)

        defaultScreenHintLabel.font = .systemFont(ofSize: 11)
        defaultScreenHintLabel.textColor = .secondaryLabelColor

        floatingWindowCheckbox.target = self
        floatingWindowCheckbox.action = #selector(windowBehaviorChanged)

        previewValueLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        previewValueLabel.textColor = .secondaryLabelColor
        previewValueLabel.alignment = .right

        roundingEffectLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        roundingEffectLabel.textColor = .tertiaryLabelColor
        roundingEffectLabel.alignment = .right
        roundingEffectLabel.lineBreakMode = .byTruncatingTail

        let previewLabel = NSTextField(labelWithString: "Anteprima")
        previewLabel.font = .systemFont(ofSize: 13)

        let effectLabel = NSTextField(labelWithString: "Effetto")
        effectLabel.font = .systemFont(ofSize: 13)

        let spacesLabel = NSTextField(labelWithString: "Spaces")
        spacesLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        let screenLabel = NSTextField(labelWithString: "Schermo di default")
        screenLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        let floatingLabel = NSTextField(labelWithString: "Tipo finestra")
        floatingLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let grid = NSGridView(views: [
            [decimalsLabel, decimalsPopup],
            [roundingLabel, roundingPopup],
            [previewLabel, previewValueLabel],
            [effectLabel, roundingEffectLabel],
            [NSTextField(labelWithString: ""), separator],
            [spacesLabel, allSpacesCheckbox],
            [screenLabel, defaultScreenPopup],
            [NSTextField(labelWithString: ""), defaultScreenHintLabel],
            [floatingLabel, floatingWindowCheckbox]
        ])
        grid.rowSpacing = 6
        grid.columnSpacing = 14
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.column(at: 0).xPlacement = .leading
        grid.column(at: 1).xPlacement = .trailing
        grid.row(at: 5).topPadding = 2

        let spacer = NSView(frame: .zero)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        okButton.target = self
        okButton.action = #selector(confirmAndClose)
        okButton.keyEquivalent = "\r"
        okButton.bezelStyle = .rounded
        okButton.widthAnchor.constraint(equalToConstant: 84).isActive = true

        let buttonRow = NSStackView(views: [spacer, okButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8

        root.addArrangedSubview(grid)
        root.addArrangedSubview(buttonRow)

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

        let downSettings = FastCalcFormatSettings(
            decimalMode: draftSettings.decimalMode,
            fixedDecimalPlaces: draftSettings.fixedDecimalPlaces,
            roundingMode: .down
        )
        let nearestSettings = FastCalcFormatSettings(
            decimalMode: draftSettings.decimalMode,
            fixedDecimalPlaces: draftSettings.fixedDecimalPlaces,
            roundingMode: .nearest
        )
        let upSettings = FastCalcFormatSettings(
            decimalMode: draftSettings.decimalMode,
            fixedDecimalPlaces: draftSettings.fixedDecimalPlaces,
            roundingMode: .up
        )

        let downValue = TapeFormatter.formatDecimalForColumn(sample, settings: downSettings)
        let nearestValue = TapeFormatter.formatDecimalForColumn(sample, settings: nearestSettings)
        let upValue = TapeFormatter.formatDecimalForColumn(sample, settings: upSettings)

        func marked(_ value: String, for mode: DecimalRoundingMode) -> String {
            if draftSettings.roundingMode == mode {
                return "[\(value)]"
            }
            return value
        }

        roundingEffectLabel.stringValue = "D \(marked(downValue, for: .down))  M \(marked(nearestValue, for: .nearest))  E \(marked(upValue, for: .up))"
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
    private func confirmAndClose() {
        updateDraftFromUI()
        settingsStore.saveFormattingSettings(draftSettings)
        close()
    }
}
