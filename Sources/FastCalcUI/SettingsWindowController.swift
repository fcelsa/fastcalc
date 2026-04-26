import AppKit
import Carbon.HIToolbox

@MainActor
/// Preferences window controller for formatting, window behavior and user-defined functions.
///
/// The controller keeps a draft for general settings that is committed on OK, while user-defined
/// functions are autosaved to match the expected macOS inspector workflow.
public final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private static let functionRowPasteboardType = NSPasteboard.PasteboardType("fastcalc.userfunction.row")

    private enum Section: Int {
        case general = 0
        case functions = 1
    }

    private enum Metrics {
        static let windowSize = NSSize(width: 640, height: 560)
        static let contentInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        static let rowSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 10
        static let labelColumnWidth: CGFloat = 120
        static let rowLabelSpacing: CGFloat = 16
        static let controlColumnWidth: CGFloat = 332
        static let generalSectionLeadingInset: CGFloat = 16
        static let inlineControlSpacing: CGFloat = 10
        static let inlineGroupSpacing: CGFloat = 20
        static let formFieldWidth: CGFloat = 280
        static let functionListWidth: CGFloat = 240
        static let functionListHeight: CGFloat = 480
        static let sliderWidth: CGFloat = 120
        static let hotKeyDisplayWidth: CGFloat = 150
        static let buttonWidth: CGFloat = 86
    }

    private let settingsStore: AppSettingsStore

    /// General settings remain staged until the user confirms with OK.
    private var draftSettings = FastCalcFormatSettings()

    /// Functions are edited in-place and autosaved for a more native inspector workflow.
    private var draftFunctions: [UserDefinedFunction] = []
    private var previewSourceValue: Decimal?
    private var selectedFunctionIndex: Int?
    private var hotKeyCaptureMonitor: Any?
    private var isCapturingHotKey = false

    // MARK: - Shared UI

    private let sectionSelector = NSSegmentedControl(labels: ["Generale", "Funzioni utente"], trackingMode: .selectOne, target: nil, action: nil)
    private let generalSectionContainer = NSView(frame: .zero)
    private let functionsSectionContainer = NSView(frame: .zero)
    private let defaultsButton = NSButton(title: "Default", target: nil, action: nil)
    private let okButton = NSButton(title: "OK", target: nil, action: nil)

    // MARK: - General tab UI

    private let decimalsPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let roundingPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let previewValueLabel = NSTextField(labelWithString: "")
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
    private let menuBarIconCheckbox = NSButton(checkboxWithTitle: "Icona menu", target: nil, action: nil)
    private let dockIconCheckbox = NSButton(checkboxWithTitle: "Icona nel Dock", target: nil, action: nil)
    private let iconVisibilityWarningLabel = NSTextField(labelWithString: "")
    private let activeOpacitySlider = NSSlider(value: 90, minValue: 10, maxValue: 100, target: nil, action: nil)
    private let activeOpacityLabel = NSTextField(labelWithString: "")
    private let inactiveOpacitySlider = NSSlider(value: 50, minValue: 10, maxValue: 100, target: nil, action: nil)
    private let inactiveOpacityLabel = NSTextField(labelWithString: "")

    // MARK: - Functions tab UI

    private let functionsTableView = NSTableView(frame: .zero)
    private let functionListActionsControl = NSSegmentedControl(frame: .zero)
    private let functionNameField = NSTextField(string: "")
    private let functionNoteField = NSTextField(string: "")
    private let functionExpressionField = NSTextField(string: "")
    private let functionResultOnlyCheckbox = NSButton(checkboxWithTitle: "Result only", target: nil, action: nil)
    private let functionHintLabel = NSTextField(labelWithString: "")

    public init(settingsStore: AppSettingsStore = .shared) {
        self.settingsStore = settingsStore

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Metrics.windowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Impostazioni"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        configureWindow()
        setupView()
        loadFromSettings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Presents the window with the latest settings from persistent storage.
    public func present() {
        loadFromSettings()
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func setPreviewSourceValue(_ value: Decimal?) {
        previewSourceValue = value
        updatePreview()
    }

    // MARK: - Setup

    /// Configures the window-level defaults that should not change at runtime.
    private func configureWindow() {
        window?.defaultButtonCell = okButton.cell as? NSButtonCell
    }

    /// Builds the full preferences UI using a shared footer and two switchable content panes.
    private func setupView() {
        guard let contentView = window?.contentView else { return }

        configureSharedControls()
        configureGeneralControls()
        configureFunctionsControls()

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .width
        root.spacing = 14
        root.edgeInsets = Metrics.contentInsets
        root.translatesAutoresizingMaskIntoConstraints = false

        let sectionHost = NSView(frame: .zero)
        sectionHost.translatesAutoresizingMaskIntoConstraints = false

        generalSectionContainer.translatesAutoresizingMaskIntoConstraints = false
        functionsSectionContainer.translatesAutoresizingMaskIntoConstraints = false

        let generalView = buildGeneralSectionView()
        let functionsView = buildFunctionsSectionView()
        generalSectionContainer.addSubview(generalView)
        functionsSectionContainer.addSubview(functionsView)

        NSLayoutConstraint.activate([
            generalView.leadingAnchor.constraint(equalTo: generalSectionContainer.leadingAnchor),
            generalView.trailingAnchor.constraint(equalTo: generalSectionContainer.trailingAnchor),
            generalView.topAnchor.constraint(equalTo: generalSectionContainer.topAnchor),
            generalView.bottomAnchor.constraint(equalTo: generalSectionContainer.bottomAnchor),
            functionsView.leadingAnchor.constraint(equalTo: functionsSectionContainer.leadingAnchor),
            functionsView.trailingAnchor.constraint(equalTo: functionsSectionContainer.trailingAnchor),
            functionsView.topAnchor.constraint(equalTo: functionsSectionContainer.topAnchor),
            functionsView.bottomAnchor.constraint(equalTo: functionsSectionContainer.bottomAnchor)
        ])

        for sectionView in [generalSectionContainer, functionsSectionContainer] {
            sectionHost.addSubview(sectionView)
            NSLayoutConstraint.activate([
                sectionView.leadingAnchor.constraint(equalTo: sectionHost.leadingAnchor),
                sectionView.trailingAnchor.constraint(equalTo: sectionHost.trailingAnchor),
                sectionView.topAnchor.constraint(equalTo: sectionHost.topAnchor),
                sectionView.bottomAnchor.constraint(equalTo: sectionHost.bottomAnchor)
            ])
        }

        let sectionSelectorRow = buildSectionSelectorRow()
        let headerSeparator = makeSeparator()

        root.addArrangedSubview(sectionSelectorRow)
        root.addArrangedSubview(headerSeparator)
        root.addArrangedSubview(sectionHost)
        root.addArrangedSubview(buildFooterRow())
        root.setCustomSpacing(8, after: sectionSelectorRow)
        root.setCustomSpacing(10, after: headerSeparator)

        contentView.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            sectionHost.heightAnchor.constraint(greaterThanOrEqualToConstant: 400)
        ])

        updateVisibleSection()
    }

    /// Builds the general settings pane with grouped form rows aligned on a shared label column.
    private func buildGeneralSectionView() -> NSView {
        let formattingRows = buildFormRows(rows: [
            ("Decimali", decimalsPopup),
            ("Arrotondamento", buildRoundingPreviewRow())
        ], controlWidth: nil)

        let behaviorRows = buildFormRows(rows: [
            ("Vista", buildCheckboxRow([allSpacesCheckbox, floatingWindowCheckbox, alwaysOnTopCheckbox])),
            (nil, buildStartupAndScreenRow())
        ], controlWidth: nil)

        let interactionRows = buildFormRows(rows: [
            (nil, buildOpacityControlsRow()),
            (nil, buildIconVisibilityRow()),
            (nil, iconVisibilityWarningLabel),
            ("Hotkey globale", buildHotKeyRow())
        ], controlWidth: nil)

        let content = NSStackView(views: [
            formattingRows,
            makeSeparator(),
            behaviorRows,
            buildHintRow(defaultScreenHintLabel),
            interactionRows,
            buildHintRow(hotKeyHintLabel)
        ])
        content.orientation = .vertical
        content.alignment = .width
        content.spacing = Metrics.sectionSpacing
        content.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView(frame: .zero)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Metrics.generalSectionLeadingInset),
            content.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            content.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor)
        ])
        return container
    }

    /// Builds the functions pane as a split inspector inspired by Terminal profiles.
    private func buildFunctionsSectionView() -> NSView {
        let listScrollView = NSScrollView(frame: .zero)
        listScrollView.translatesAutoresizingMaskIntoConstraints = false
        listScrollView.borderType = .bezelBorder
        listScrollView.hasVerticalScroller = true
        listScrollView.hasHorizontalScroller = false
        listScrollView.drawsBackground = false
        listScrollView.documentView = functionsTableView
        listScrollView.widthAnchor.constraint(equalToConstant: Metrics.functionListWidth).isActive = true
        listScrollView.heightAnchor.constraint(equalToConstant: Metrics.functionListHeight).isActive = true

        let controlsBar = NSStackView(views: [functionListActionsControl])
        controlsBar.orientation = .horizontal
        controlsBar.alignment = .centerY
        controlsBar.spacing = 0

        let sidebar = NSStackView(views: [listScrollView, makeSeparator(), controlsBar])
        sidebar.orientation = .vertical
        sidebar.alignment = .width
        sidebar.spacing = 8

        let inspectorRows = buildFormRows(rows: [
            ("Nome", functionNameField),
            ("Nota", functionNoteField),
            ("Calcolo", functionExpressionField),
            (nil, functionResultOnlyCheckbox)
        ])

        let inspector = NSStackView(views: [inspectorRows, buildHintRow(functionHintLabel, indent: 0)])
        inspector.orientation = .vertical
        inspector.alignment = .width
        inspector.spacing = 12
        inspector.widthAnchor.constraint(equalToConstant: Metrics.controlColumnWidth + Metrics.labelColumnWidth + 16).isActive = true

        let split = NSStackView(views: [sidebar, inspector])
        split.orientation = .horizontal
        split.alignment = .top
        split.spacing = 18
        split.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView(frame: .zero)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(split)
        NSLayoutConstraint.activate([
            split.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Metrics.generalSectionLeadingInset),
            split.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            split.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            split.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor)
        ])
        return container
    }

    /// Creates the centered section switcher shown at the top of the window.
    private func buildSectionSelectorRow() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        sectionSelector.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sectionSelector)
        NSLayoutConstraint.activate([
            sectionSelector.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            sectionSelector.topAnchor.constraint(equalTo: container.topAnchor),
            sectionSelector.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    /// Creates the trailing footer row shared by both panes.
    private func buildFooterRow() -> NSView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return buildHorizontalRow([spacer, defaultsButton, okButton], spacing: 8)
    }

    // MARK: - Control configuration

    private func configureSharedControls() {
        sectionSelector.target = self
        sectionSelector.action = #selector(sectionChanged)
        sectionSelector.selectedSegment = Section.general.rawValue
        sectionSelector.segmentStyle = .rounded
        sectionSelector.setWidth(156, forSegment: Section.general.rawValue)
        sectionSelector.setWidth(156, forSegment: Section.functions.rawValue)
        if let generalImage = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "Generale") {
            sectionSelector.setImage(generalImage, forSegment: Section.general.rawValue)
        }
        if let functionsImage = NSImage(systemSymbolName: "function", accessibilityDescription: "Funzioni") {
            sectionSelector.setImage(functionsImage, forSegment: Section.functions.rawValue)
        }

        defaultsButton.target = self
        defaultsButton.action = #selector(resetToDefaults)
        defaultsButton.bezelStyle = .rounded
        defaultsButton.widthAnchor.constraint(equalToConstant: Metrics.buttonWidth).isActive = true

        okButton.target = self
        okButton.action = #selector(confirmAndClose)
        okButton.keyEquivalent = "\r"
        okButton.bezelStyle = .rounded
        okButton.widthAnchor.constraint(equalToConstant: Metrics.buttonWidth).isActive = true
    }

    private func configureGeneralControls() {
        configurePopup(decimalsPopup, minimumWidth: 72)
        decimalsPopup.addItems(withTitles: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "FL"])
        decimalsPopup.target = self
        decimalsPopup.action = #selector(decimalsChanged)

        configurePopup(roundingPopup, minimumWidth: 120)
        roundingPopup.addItems(withTitles: ["Difetto", "Medio", "Eccesso"])
        roundingPopup.target = self
        roundingPopup.action = #selector(roundingChanged)

        previewValueLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        previewValueLabel.textColor = .secondaryLabelColor

        allSpacesCheckbox.target = self
        allSpacesCheckbox.action = #selector(windowBehaviorChanged)

        configurePopup(defaultScreenPopup, minimumWidth: 150)
        defaultScreenPopup.target = self
        defaultScreenPopup.action = #selector(windowBehaviorChanged)

        defaultScreenHintLabel.font = .systemFont(ofSize: 11)
        defaultScreenHintLabel.textColor = .secondaryLabelColor

        floatingWindowCheckbox.target = self
        floatingWindowCheckbox.action = #selector(windowBehaviorChanged)

        alwaysOnTopCheckbox.target = self
        alwaysOnTopCheckbox.action = #selector(windowBehaviorChanged)

        configurePopup(startupModePopup, minimumWidth: 110)
        startupModePopup.addItems(withTitles: ["Default", "Nascosta", "Visibile"])
        startupModePopup.target = self
        startupModePopup.action = #selector(windowBehaviorChanged)

        hotKeyValueLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        hotKeyValueLabel.alignment = .left
        hotKeyValueLabel.lineBreakMode = .byTruncatingTail
        hotKeyValueLabel.setContentHuggingPriority(.required, for: .horizontal)
        hotKeyValueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        hotKeyValueLabel.widthAnchor.constraint(equalToConstant: Metrics.hotKeyDisplayWidth).isActive = true

        hotKeyCaptureButton.target = self
        hotKeyCaptureButton.action = #selector(toggleHotKeyCapture)
        hotKeyCaptureButton.bezelStyle = .rounded
        hotKeyResetButton.target = self
        hotKeyResetButton.action = #selector(resetHotKeyToDefault)
        hotKeyResetButton.bezelStyle = .rounded

        menuBarIconCheckbox.target = self
        menuBarIconCheckbox.action = #selector(windowBehaviorChanged)

        dockIconCheckbox.target = self
        dockIconCheckbox.action = #selector(windowBehaviorChanged)

        iconVisibilityWarningLabel.font = .systemFont(ofSize: 11)
        iconVisibilityWarningLabel.textColor = .systemOrange
        iconVisibilityWarningLabel.lineBreakMode = .byWordWrapping
        iconVisibilityWarningLabel.maximumNumberOfLines = 2

        hotKeyHintLabel.font = .systemFont(ofSize: 11)
        hotKeyHintLabel.textColor = .secondaryLabelColor
        hotKeyHintLabel.lineBreakMode = .byWordWrapping
        hotKeyHintLabel.maximumNumberOfLines = 2

        configureOpacityRow(slider: activeOpacitySlider, label: activeOpacityLabel)
        configureOpacityRow(slider: inactiveOpacitySlider, label: inactiveOpacityLabel)
    }

    private func configureFunctionsControls() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("function"))
        column.width = Metrics.functionListWidth
        functionsTableView.addTableColumn(column)
        functionsTableView.delegate = self
        functionsTableView.dataSource = self
        functionsTableView.headerView = nil
        functionsTableView.style = .sourceList
        functionsTableView.rowSizeStyle = .medium
        functionsTableView.focusRingType = .none
        functionsTableView.usesAlternatingRowBackgroundColors = true
        functionsTableView.backgroundColor = .clear
        functionsTableView.registerForDraggedTypes([Self.functionRowPasteboardType])
        functionsTableView.setDraggingSourceOperationMask(.move, forLocal: true)
        functionsTableView.draggingDestinationFeedbackStyle = .gap

        functionListActionsControl.segmentCount = 2
        functionListActionsControl.segmentStyle = .texturedRounded
        functionListActionsControl.trackingMode = .momentary
        functionListActionsControl.controlSize = .small
        functionListActionsControl.target = self
        functionListActionsControl.action = #selector(handleFunctionListAction)
        functionListActionsControl.setWidth(28, forSegment: 0)
        functionListActionsControl.setWidth(28, forSegment: 1)
        functionListActionsControl.setImage(NSImage(named: NSImage.addTemplateName) ?? NSImage(systemSymbolName: "plus", accessibilityDescription: "Aggiungi"), forSegment: 0)
        functionListActionsControl.setImage(NSImage(named: NSImage.removeTemplateName) ?? NSImage(systemSymbolName: "minus", accessibilityDescription: "Rimuovi"), forSegment: 1)

        functionNameField.placeholderString = "Nome funzione"
        functionNameField.delegate = self
        functionNameField.widthAnchor.constraint(greaterThanOrEqualToConstant: Metrics.formFieldWidth).isActive = true

        functionNoteField.placeholderString = "Nota breve (max 12)"
        functionNoteField.delegate = self
        functionNoteField.widthAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true

        functionExpressionField.placeholderString = "Calcolo con x, es: (x*1.22)+5"
        functionExpressionField.delegate = self
        functionExpressionField.widthAnchor.constraint(greaterThanOrEqualToConstant: Metrics.formFieldWidth).isActive = true

        functionResultOnlyCheckbox.target = self
        functionResultOnlyCheckbox.action = #selector(functionResultOnlyChanged)

        functionHintLabel.font = .systemFont(ofSize: 11)
        functionHintLabel.textColor = .secondaryLabelColor
        functionHintLabel.stringValue = "Usa x (o {x}) come operando corrente. Disattiva Result only per sviluppare nel roll solo espressioni digitabili dalla tastiera."
    }

    // MARK: - View helpers

    private func buildFormRows(rows: [(String?, NSView)], controlWidth: CGFloat? = Metrics.controlColumnWidth) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = Metrics.rowSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        for (title, control) in rows {
            stack.addArrangedSubview(buildFormRow(title: title, control: control, controlWidth: controlWidth))
        }

        return stack
    }

    private func buildFormRow(title: String?, control: NSView, controlWidth: CGFloat? = Metrics.controlColumnWidth) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = Metrics.rowLabelSpacing
        row.translatesAutoresizingMaskIntoConstraints = false

        if let title {
            row.addArrangedSubview(makeFormLabel(title))
        } else {
            let spacer = NSView(frame: NSRect(x: 0, y: 0, width: Metrics.labelColumnWidth, height: 1))
            spacer.translatesAutoresizingMaskIntoConstraints = false
            spacer.widthAnchor.constraint(equalToConstant: Metrics.labelColumnWidth).isActive = true
            row.addArrangedSubview(spacer)
        }

        row.addArrangedSubview(makeControlColumn(control, width: controlWidth))

        let filler = NSView()
        filler.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(filler)
        return row
    }

    private func buildHorizontalRow(_ views: [NSView], spacing: CGFloat = 10) -> NSStackView {
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = spacing
        return row
    }

    private func buildHintRow(_ label: NSTextField, indent: CGFloat = Metrics.labelColumnWidth + 16) -> NSView {
        let spacer = NSView(frame: NSRect(x: 0, y: 0, width: indent, height: 1))
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.widthAnchor.constraint(equalToConstant: indent).isActive = true
        let filler = NSView()
        filler.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return buildHorizontalRow([spacer, label, filler], spacing: 0)
    }

    private func buildCheckboxRow(_ checkboxes: [NSButton]) -> NSView {
        let filler = NSView()
        filler.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return buildHorizontalRow(checkboxes + [filler], spacing: 14)
    }

    private func buildRoundingPreviewRow() -> NSView {
        let exampleLabel = makeInlineLabel("Esempio")
        let filler = NSView()
        filler.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return buildHorizontalRow([roundingPopup, exampleLabel, previewValueLabel, filler], spacing: 12)
    }

    private func buildStartupAndScreenRow() -> NSView {
        let startupLabel = makeInlineLabel("Apertura all'avvio")
        let screenLabel = makeInlineLabel("Schermo di default")
        let filler = NSView()
        filler.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return buildHorizontalRow([startupLabel, startupModePopup, screenLabel, defaultScreenPopup, filler], spacing: Metrics.inlineControlSpacing)
    }

    private func buildOpacityControlsRow() -> NSView {
        activeOpacitySlider.widthAnchor.constraint(equalToConstant: Metrics.sliderWidth).isActive = true
        inactiveOpacitySlider.widthAnchor.constraint(equalToConstant: Metrics.sliderWidth).isActive = true
        activeOpacityLabel.widthAnchor.constraint(equalToConstant: 36).isActive = true
        inactiveOpacityLabel.widthAnchor.constraint(equalToConstant: 36).isActive = true

        let activeLabel = makeInlineLabel("Opacita attiva")
        let inactiveLabel = makeInlineLabel("Opacita inattiva")
        let activeGroup = buildHorizontalRow([activeLabel, activeOpacitySlider, activeOpacityLabel], spacing: 8)
        let inactiveGroup = buildHorizontalRow([inactiveLabel, inactiveOpacitySlider, inactiveOpacityLabel], spacing: 8)
        let filler = NSView()
        filler.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return buildHorizontalRow([activeGroup, inactiveGroup, filler], spacing: Metrics.inlineGroupSpacing)
    }

    private func buildIconVisibilityRow() -> NSView {
        let filler = NSView()
        filler.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return buildHorizontalRow([menuBarIconCheckbox, dockIconCheckbox, filler], spacing: 14)
    }

    private func buildHotKeyRow() -> NSView {
        let filler = NSView()
        filler.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = buildHorizontalRow([hotKeyCaptureButton, hotKeyResetButton, hotKeyValueLabel, filler], spacing: 8)
        row.widthAnchor.constraint(equalToConstant: Metrics.controlColumnWidth).isActive = true
        return row
    }

    private func makeFormLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13)
        label.alignment = .left
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.widthAnchor.constraint(equalToConstant: Metrics.labelColumnWidth).isActive = true
        return label
    }

    private func makeInlineLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }

    private func makeControlColumn(_ control: NSView, width: CGFloat?) -> NSView {
        let filler = NSView()
        filler.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = buildHorizontalRow([control, filler], spacing: 0)
        if let width {
            row.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        return row
    }

    private func makeSeparator() -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }

    private func configurePopup(_ popup: NSPopUpButton, minimumWidth: CGFloat) {
        popup.setContentHuggingPriority(.required, for: .horizontal)
        popup.setContentCompressionResistancePriority(.required, for: .horizontal)
        popup.widthAnchor.constraint(greaterThanOrEqualToConstant: minimumWidth).isActive = true
    }

    private func configureOpacityRow(slider: NSSlider, label: NSTextField) {
        slider.target = self
        slider.action = #selector(opacityChanged)
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.alignment = .right
        label.textColor = .secondaryLabelColor
    }

    // MARK: - State application

    /// Reloads the UI from persisted settings and restores the current function selection when possible.
    private func loadFromSettings() {
        draftSettings = settingsStore.loadFormattingSettings()
        draftFunctions = draftSettings.userFunctions
        if draftFunctions.isEmpty {
            selectedFunctionIndex = nil
        } else {
            selectedFunctionIndex = min(selectedFunctionIndex ?? 0, draftFunctions.count - 1)
        }
        applyDraftToUI()
        updatePreview()
    }

    private func applyDraftToUI() {
        switch draftSettings.decimalMode {
        case .floating:
            decimalsPopup.selectItem(withTitle: "FL")
        case .fixed:
            decimalsPopup.selectItem(withTitle: String(max(0, min(8, draftSettings.fixedDecimalPlaces))))
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
        menuBarIconCheckbox.state = draftSettings.menuBarIconEnabled ? .on : .off
        dockIconCheckbox.state = draftSettings.dockIconEnabled ? .on : .off

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
        updateIconVisibilityWarning()
        reloadScreenChoices()
        reloadFunctionsUI()
    }

    /// Copies the current general-pane control values into the draft model.
    private func updateDraftFromUI() {
        if decimalsPopup.titleOfSelectedItem == "FL" {
            draftSettings.decimalMode = .floating
            draftSettings.fixedDecimalPlaces = 2
        } else {
            draftSettings.decimalMode = .fixed
            draftSettings.fixedDecimalPlaces = max(0, min(8, Int(decimalsPopup.titleOfSelectedItem ?? "2") ?? 2))
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
        draftSettings.menuBarIconEnabled = menuBarIconCheckbox.state == .on
        draftSettings.dockIconEnabled = dockIconCheckbox.state == .on

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

        if defaultScreenPopup.isEnabled {
            draftSettings.preferredScreenIndex = max(0, defaultScreenPopup.indexOfSelectedItem)
        } else {
            draftSettings.preferredScreenIndex = nil
        }

        draftSettings.userFunctions = draftFunctions
    }

    private func updateVisibleSection() {
        let currentSection = Section(rawValue: sectionSelector.selectedSegment) ?? .general
        generalSectionContainer.isHidden = currentSection != .general
        functionsSectionContainer.isHidden = currentSection != .functions
        defaultsButton.isHidden = currentSection != .general
    }

    private func reloadFunctionsUI() {
        functionsTableView.reloadData()

        guard !draftFunctions.isEmpty else {
            selectedFunctionIndex = nil
            functionListActionsControl.setEnabled(false, forSegment: 1)
            populateFunctionInspector(nil)
            return
        }

        let row = min(max(selectedFunctionIndex ?? 0, 0), draftFunctions.count - 1)
        selectedFunctionIndex = row
        functionListActionsControl.setEnabled(true, forSegment: 1)
        if functionsTableView.selectedRow != row {
            functionsTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        populateFunctionInspector(draftFunctions[row])
    }

    private func populateFunctionInspector(_ function: UserDefinedFunction?) {
        guard let function else {
            functionNameField.stringValue = ""
            functionNoteField.stringValue = ""
            functionExpressionField.stringValue = ""
            functionResultOnlyCheckbox.state = .off
            return
        }

        functionNameField.stringValue = function.label
        functionNoteField.stringValue = function.note
        functionExpressionField.stringValue = function.expression
        functionResultOnlyCheckbox.state = function.resultOnly ? .on : .off
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
        previewValueLabel.stringValue = TapeFormatter.formatDecimalForColumn(sample, settings: draftSettings)
    }

    private func updateOpacityLabels() {
        activeOpacityLabel.stringValue = "\(Int(activeOpacitySlider.doubleValue.rounded()))%"
        inactiveOpacityLabel.stringValue = "\(Int(inactiveOpacitySlider.doubleValue.rounded()))%"
    }

    private func updateIconVisibilityWarning() {
        let menuBarEnabled = menuBarIconCheckbox.state == .on
        let dockEnabled = dockIconCheckbox.state == .on
        if !menuBarEnabled && !dockEnabled {
            iconVisibilityWarningLabel.stringValue = "Disabilitando entrambe le icone, l'unico modo per riportare in primo piano l'app sarà la hotkey globale."
        } else {
            iconVisibilityWarningLabel.stringValue = ""
        }
    }

    private func persistUserFunctions() {
        draftSettings.userFunctions = draftFunctions
        settingsStore.saveUserFunctions(draftFunctions)
    }

    // MARK: - Actions

    @objc
    private func sectionChanged() {
        updateVisibleSection()
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
        updateIconVisibilityWarning()
    }

    @objc
    private func opacityChanged() {
        updateDraftFromUI()
        updateOpacityLabels()
    }

    @objc
    private func handleFunctionListAction(_ sender: NSSegmentedControl) {
        defer { sender.selectedSegment = -1 }
        switch sender.selectedSegment {
        case 0:
            addFunction()
        case 1:
            removeSelectedFunction()
        default:
            break
        }
    }

    private func addFunction() {
        let function = UserDefinedFunction(label: "Nuova funzione", note: "", expression: "x", resultOnly: true)
        draftFunctions.append(function)
        selectedFunctionIndex = draftFunctions.count - 1
        persistUserFunctions()
        reloadFunctionsUI()
        window?.makeFirstResponder(functionNameField)
    }

    private func removeSelectedFunction() {
        guard let selectedFunctionIndex else { return }
        guard selectedFunctionIndex >= 0, selectedFunctionIndex < draftFunctions.count else { return }

        draftFunctions.remove(at: selectedFunctionIndex)
        if draftFunctions.isEmpty {
            self.selectedFunctionIndex = nil
        } else {
            self.selectedFunctionIndex = min(selectedFunctionIndex, draftFunctions.count - 1)
        }
        persistUserFunctions()
        reloadFunctionsUI()
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

    @objc
    private func functionResultOnlyChanged() {
        guard let selectedFunctionIndex else { return }
        guard selectedFunctionIndex >= 0, selectedFunctionIndex < draftFunctions.count else { return }

        draftFunctions[selectedFunctionIndex].resultOnly = functionResultOnlyCheckbox.state == .on
        persistUserFunctions()
        functionsTableView.reloadData(forRowIndexes: IndexSet(integer: selectedFunctionIndex), columnIndexes: IndexSet(integer: 0))
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
        draftFunctions = draftSettings.userFunctions
        selectedFunctionIndex = draftFunctions.isEmpty ? nil : 0
        applyDraftToUI()
        updatePreview()
    }

    // MARK: - Hot key capture

    /// Starts local event capture so the next key combination can be stored as the global shortcut.
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

    // MARK: - NSTextFieldDelegate

    /// Mirrors field edits back into the selected function and persists them immediately.
    public func controlTextDidChange(_ notification: Notification) {
        guard let selectedFunctionIndex else { return }
        guard selectedFunctionIndex >= 0, selectedFunctionIndex < draftFunctions.count else { return }

        let name = functionNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = String(functionNoteField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).prefix(12))
        let expression = functionExpressionField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        draftFunctions[selectedFunctionIndex].label = name.isEmpty ? "Nuova funzione" : name
        draftFunctions[selectedFunctionIndex].note = note
        draftFunctions[selectedFunctionIndex].expression = expression.isEmpty ? "x" : expression
        draftFunctions[selectedFunctionIndex].resultOnly = functionResultOnlyCheckbox.state == .on

        if functionNoteField.stringValue != draftFunctions[selectedFunctionIndex].note {
            functionNoteField.stringValue = draftFunctions[selectedFunctionIndex].note
        }

        persistUserFunctions()
        functionsTableView.reloadData(forRowIndexes: IndexSet(integer: selectedFunctionIndex), columnIndexes: IndexSet(integer: 0))
    }

    // MARK: - NSTableViewDataSource / Delegate

    public func numberOfRows(in tableView: NSTableView) -> Int {
        draftFunctions.count
    }

    public func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard tableView === functionsTableView else { return nil }
        guard row >= 0, row < draftFunctions.count else { return nil }

        let item = NSPasteboardItem()
        item.setString(String(row), forType: Self.functionRowPasteboardType)
        return item
    }

    public func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard tableView === functionsTableView else { return [] }
        guard dropOperation == .above else {
            tableView.setDropRow(row, dropOperation: .above)
            return .move
        }
        return .move
    }

    public func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard tableView === functionsTableView else { return false }
        guard dropOperation == .above else { return false }
        guard let sourceRowString = info.draggingPasteboard.string(forType: Self.functionRowPasteboardType),
              let sourceRow = Int(sourceRowString),
              sourceRow >= 0,
              sourceRow < draftFunctions.count
        else {
            return false
        }

        var destinationRow = max(0, min(row, draftFunctions.count))
        if destinationRow > sourceRow {
            destinationRow -= 1
        }

        guard destinationRow != sourceRow else { return false }

        let movedFunction = draftFunctions.remove(at: sourceRow)
        draftFunctions.insert(movedFunction, at: destinationRow)
        selectedFunctionIndex = destinationRow
        persistUserFunctions()
        reloadFunctionsUI()
        functionsTableView.selectRowIndexes(IndexSet(integer: destinationRow), byExtendingSelection: false)
        functionsTableView.scrollRowToVisible(destinationRow)
        populateFunctionInspector(draftFunctions[destinationRow])
        return true
    }

    public func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = functionsTableView.selectedRow
        guard selectedRow >= 0, selectedRow < draftFunctions.count else {
            selectedFunctionIndex = nil
            functionListActionsControl.setEnabled(false, forSegment: 1)
            populateFunctionInspector(nil)
            return
        }

        selectedFunctionIndex = selectedRow
        functionListActionsControl.setEnabled(true, forSegment: 1)
        populateFunctionInspector(draftFunctions[selectedRow])
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < draftFunctions.count else { return nil }

        let identifier = NSUserInterfaceItemIdentifier("functionCell")
        let item = draftFunctions[row]

        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView(frame: .zero)
            cell.identifier = identifier

            let label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 13)
            label.lineBreakMode = .byTruncatingTail
            cell.addSubview(label)
            cell.textField = label

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        cell.textField?.stringValue = item.note.isEmpty ? item.label : "\(item.label)  [\(item.note)]"
        return cell
    }
}
