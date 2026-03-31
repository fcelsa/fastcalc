import AppKit

@MainActor
public final class SettingsWindowController: NSWindowController {
    private let settingsStore: AppSettingsStore
    private var draftSettings = FastCalcFormatSettings()
    private var previewSourceValue: Decimal?

    private let decimalModePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let fixedDecimalsField = NSTextField(string: "2")
    private let fixedDecimalsStepper = NSStepper(frame: .zero)
    private let roundingPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let previewValueLabel = NSTextField(labelWithString: "")
    private let roundingEffectLabel = NSTextField(labelWithString: "")
    private let okButton = NSButton(title: "OK", target: nil, action: nil)

    public init(settingsStore: AppSettingsStore = .shared) {
        self.settingsStore = settingsStore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 240),
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

        let modeLabel = NSTextField(labelWithString: "Decimali")
        modeLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        decimalModePopup.addItems(withTitles: ["Floating (puro)", "Fissi"])
        decimalModePopup.target = self
        decimalModePopup.action = #selector(decimalModeChanged)

        let fixedLabel = NSTextField(labelWithString: "Numero decimali")
        fixedLabel.font = .systemFont(ofSize: 13)

        fixedDecimalsField.alignment = .right
        fixedDecimalsField.controlSize = .small
        fixedDecimalsField.isEditable = true
        fixedDecimalsField.target = self
        fixedDecimalsField.action = #selector(fixedDecimalsFieldChanged)
        fixedDecimalsField.widthAnchor.constraint(equalToConstant: 44).isActive = true

        fixedDecimalsStepper.minValue = 0
        fixedDecimalsStepper.maxValue = 8
        fixedDecimalsStepper.increment = 1
        fixedDecimalsStepper.target = self
        fixedDecimalsStepper.action = #selector(fixedDecimalsStepperChanged)

        let fixedControls = NSStackView(views: [fixedDecimalsField, fixedDecimalsStepper])
        fixedControls.orientation = .horizontal
        fixedControls.alignment = .centerY
        fixedControls.spacing = 8

        let roundingLabel = NSTextField(labelWithString: "Arrotondamento")
        roundingLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        roundingPopup.addItems(withTitles: ["Difetto", "Medio", "Eccesso"])
        roundingPopup.target = self
        roundingPopup.action = #selector(roundingChanged)

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

        let grid = NSGridView(views: [
            [modeLabel, decimalModePopup],
            [fixedLabel, fixedControls],
            [roundingLabel, roundingPopup],
            [previewLabel, previewValueLabel],
            [effectLabel, roundingEffectLabel]
        ])
        grid.rowSpacing = 6
        grid.columnSpacing = 14
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.column(at: 0).xPlacement = .leading
        grid.column(at: 1).xPlacement = .trailing
        grid.row(at: 4).topPadding = 2

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
        updateFixedDecimalsEnabledState()
        updatePreview()
    }

    private func applyDraftToUI() {
        switch draftSettings.decimalMode {
        case .floating:
            decimalModePopup.selectItem(at: 0)
        case .fixed:
            decimalModePopup.selectItem(at: 1)
        }

        fixedDecimalsField.stringValue = String(draftSettings.fixedDecimalPlaces)
        fixedDecimalsStepper.integerValue = draftSettings.fixedDecimalPlaces

        switch draftSettings.roundingMode {
        case .down:
            roundingPopup.selectItem(at: 0)
        case .nearest:
            roundingPopup.selectItem(at: 1)
        case .up:
            roundingPopup.selectItem(at: 2)
        }
    }

    private func updateDraftFromUI() {
        draftSettings.decimalMode = decimalModePopup.indexOfSelectedItem == 1 ? .fixed : .floating

        let fixedPlaces = max(0, min(8, fixedDecimalsStepper.integerValue))
        draftSettings.fixedDecimalPlaces = fixedPlaces
        fixedDecimalsField.stringValue = String(fixedPlaces)

        switch roundingPopup.indexOfSelectedItem {
        case 0:
            draftSettings.roundingMode = .down
        case 2:
            draftSettings.roundingMode = .up
        default:
            draftSettings.roundingMode = .nearest
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

    private func updateFixedDecimalsEnabledState() {
        let isFixed = decimalModePopup.indexOfSelectedItem == 1
        fixedDecimalsField.isEnabled = isFixed
        fixedDecimalsStepper.isEnabled = isFixed
        fixedDecimalsField.textColor = isFixed ? .labelColor : .secondaryLabelColor
    }

    @objc
    private func decimalModeChanged() {
        updateFixedDecimalsEnabledState()
        updateDraftFromUI()
        updatePreview()
    }

    @objc
    private func fixedDecimalsStepperChanged() {
        fixedDecimalsField.stringValue = String(fixedDecimalsStepper.integerValue)
        updateDraftFromUI()
        updatePreview()
    }

    @objc
    private func fixedDecimalsFieldChanged() {
        let parsed = Int(fixedDecimalsField.stringValue) ?? fixedDecimalsStepper.integerValue
        let clamped = max(0, min(8, parsed))
        fixedDecimalsStepper.integerValue = clamped
        fixedDecimalsField.stringValue = String(clamped)
        updateDraftFromUI()
        updatePreview()
    }

    @objc
    private func roundingChanged() {
        updateDraftFromUI()
        updatePreview()
    }

    @objc
    private func confirmAndClose() {
        updateDraftFromUI()
        settingsStore.saveFormattingSettings(draftSettings)
        close()
    }
}
