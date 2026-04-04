//
// This file manages the FastCalc paper-roll window.
// It uses a table-based tape renderer for stable column alignment,
// keyboard navigation, and calculator input routing.
//

import AppKit
import AVFoundation
import FastCalcCore

private final class RollWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class TapeTableView: NSTableView {
    var onKeyEvent: ((NSEvent) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if onKeyEvent?(event) == true {
            return
        }
        super.keyDown(with: event)
    }
}

private final class StatusLedView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 4
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setOn(_ isOn: Bool) {
        let color = isOn
            ? NSColor.systemGreen
            : NSColor(calibratedWhite: 0.45, alpha: 0.25)
        layer?.backgroundColor = color.cgColor
    }
}

private struct TapePrintableLine {
    let text: String
    let isNegative: Bool
}

private final class TapePrintPageView: NSView {
    private let lines: [TapePrintableLine]
    private let headerLeft: String
    private let headerRight: String
    private let pageSize: NSSize

    private let marginLeft: CGFloat = 54
    private let marginRight: CGFloat = 36
    private let marginTop: CGFloat = 36
    private let marginBottom: CGFloat = 32
    private let headerGap: CGFloat = 18
    private let footerGap: CGFloat = 4

    private let bodyFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
    private let headerFont = NSFont.monospacedSystemFont(ofSize: 8, weight: .semibold)
    private let footerFont = NSFont.monospacedSystemFont(ofSize: 8, weight: .regular)

    private let lineHeight: CGFloat
    private let rowsPerPage: Int
    private let totalPages: Int

    override var isFlipped: Bool { true }

    init(lines: [TapePrintableLine], headerLeft: String, headerRight: String, pageSize: NSSize) {
        self.lines = lines
        self.headerLeft = headerLeft
        self.headerRight = headerRight
        self.pageSize = pageSize

        let measuredLineHeight = ceil(("0" as NSString).size(withAttributes: [.font: bodyFont]).height)
        self.lineHeight = max(measuredLineHeight + 2, 14)

        let contentHeight = pageSize.height - marginTop - marginBottom - headerGap - footerGap
        self.rowsPerPage = max(1, Int(floor(contentHeight / self.lineHeight)))
        self.totalPages = max(1, Int(ceil(Double(lines.count) / Double(self.rowsPerPage))))

        let frame = NSRect(x: 0, y: 0, width: pageSize.width, height: pageSize.height * CGFloat(self.totalPages))
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        range.pointee = NSRange(location: 1, length: totalPages)
        return true
    }

    override func rectForPage(_ page: Int) -> NSRect {
        NSRect(x: 0, y: CGFloat(page - 1) * pageSize.height, width: pageSize.width, height: pageSize.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        let currentPage = max(1, NSPrintOperation.current?.currentPage ?? 1)
        drawPage(number: currentPage)
    }

    private func drawPage(number pageNumber: Int) {
        let pageOriginY = CGFloat(pageNumber - 1) * pageSize.height
        let pageRect = NSRect(x: 0, y: pageOriginY, width: pageSize.width, height: pageSize.height)

        NSColor.white.setFill()
        pageRect.fill()

        // Visual guide: border on configured print margins.
        let marginRect = NSRect(
            x: marginLeft,
            y: pageOriginY + marginTop,
            width: pageSize.width - marginLeft - marginRight,
            height: pageSize.height - marginTop - marginBottom
        ).insetBy(dx: -5, dy: -5)
        let marginPath = NSBezierPath(rect: marginRect)
        marginPath.lineWidth = 0.5
        NSColor(calibratedWhite: 0.2, alpha: 0.35).setStroke()
        marginPath.stroke()

        let headerTop = pageOriginY + (marginTop / 2)
        let contentTop = headerTop + headerGap
        let contentBottom = pageOriginY + pageSize.height - (marginBottom / 2) - footerGap

        let paragraphLeft = NSMutableParagraphStyle()
        paragraphLeft.alignment = .left
        let paragraphRight = NSMutableParagraphStyle()
        paragraphRight.alignment = .right
        let paragraphCenter = NSMutableParagraphStyle()
        paragraphCenter.alignment = .center

        let headerLeftAttributes: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphLeft
        ]
        let headerRightAttributes: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphRight
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphLeft
        ]
        let bodyNegativeAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: NSColor.systemRed,
            .paragraphStyle: paragraphLeft
        ]
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: footerFont,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphCenter
        ]

        let printableWidth = pageSize.width - marginLeft - marginRight
        let leftHeaderRect = NSRect(x: marginLeft, y: headerTop, width: printableWidth * 0.6, height: 12)
        let rightHeaderRect = NSRect(x: marginLeft + printableWidth * 0.4, y: headerTop, width: printableWidth * 0.6, height: 12)
        headerLeft.draw(in: leftHeaderRect, withAttributes: headerLeftAttributes)
        headerRight.draw(in: rightHeaderRect, withAttributes: headerRightAttributes)

        let firstLineIndex = (pageNumber - 1) * rowsPerPage
        let lastLineIndex = min(firstLineIndex + rowsPerPage, lines.count)

        var y = contentTop
        if firstLineIndex < lastLineIndex {
            for line in lines[firstLineIndex..<lastLineIndex] {
                let lineRect = NSRect(x: marginLeft, y: y, width: printableWidth, height: lineHeight)
                line.text.draw(in: lineRect, withAttributes: line.isNegative ? bodyNegativeAttributes : bodyAttributes)
                y += lineHeight
            }
        }

        let footerText = "Pag. \(pageNumber) di \(totalPages)"
        let footerRect = NSRect(x: marginLeft, y: max(contentBottom, pageOriginY + pageSize.height - marginBottom), width: printableWidth, height: 12)
        footerText.draw(in: footerRect, withAttributes: footerAttributes)
    }
}

@MainActor
public final class RollWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private struct PrintableTapeRow {
        let lineNumber: Int
        let calc: String
        let note: String
        let operand: String
    }

    private struct PercentTrace {
        let convertedValue: Decimal
        let pendingOperator: CalculatorOperator?
        let baseValue: Decimal?
    }

    private struct FullClearUndoSnapshot {
        let committedRows: [TapeRow]
        let draftInput: String
        let draftCursor: Int
        let hasPendingLeadingNegativeSign: Bool
        let isNoteModeActive: Bool
        let noteEditingRow: Int?
        let noteOriginalText: String
        let noteDraftInput: String
        let isTextModeActive: Bool
        let textEditingRow: Int?
        let textOriginalText: String
        let textDraftInput: String
        let pendingPercentTrace: PercentTrace?
        let selectedRow: Int
    }

    private let specialColumnChars = 3
    private let calcColumnChars = 20
    private let noteColumnChars = 12
    private let operandColumnChars = 3

    private let stateStore: AppStateStore
    private let settingsStore: AppSettingsStore
    private var engine: CalculatorEngine
    private var activeSettings: FastCalcFormatSettings
    private let scrollView: NSScrollView
    private let tableView: TapeTableView

    private var committedRows: [TapeRow] = []
    private var draftInput = ""
    private var draftCursor = 0
    private var hasPendingLeadingNegativeSign = false
    private var isNoteModeActive = false
    private var noteEditingRow: Int?
    private var noteOriginalText = ""
    private var noteDraftInput = ""
    private var isTextModeActive = false
    private var textEditingRow: Int?
    private var textOriginalText = ""
    private var textDraftInput = ""
    private var editingCommittedRow: Int?
    private var isEditingModeActive = false
    private var pendingPercentTrace: PercentTrace?
    private var lastFullClearSnapshot: FullClearUndoSnapshot?
    private var isAdjustingWindowHeight = false
    private var isOperandColumnLocked = true
    private let operandRightPadding: CGFloat = 16
    private var activeAlpha: CGFloat {
        CGFloat(max(0.1, min(1.0, activeSettings.activeWindowOpacity)))
    }

    private var inactiveAlpha: CGFloat {
        CGFloat(max(0.1, min(1.0, activeSettings.inactiveWindowOpacity)))
    }
    private let statusBarHeight: CGFloat = 22
    private let defaultRowHeight: CGFloat = 24
    private let separatorRowHeight: CGFloat = 12
    private let maxInlineNoteCharacters = 12
    private let maxTextRowCharacters = 20
    private let maxWindowHeightFraction: CGFloat = 0.80
    private var hasInputFocus = false
    private var markerSelectedRow = -1

    private let statusBarView = NSView(frame: .zero)
    private let statusLedView = StatusLedView(frame: .zero)
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let statusLabel = NSTextField(labelWithString: "")

    private static let resetBaselineRow = TapeRow(special: "", calc: "0", operand: "C", kind: .reset)
    private static let totalSeparatorMarker = "__SEP__"
    private static let totalSeparatorGlyph = "—"
    private static let defaultVersion = "1.0"

    public init(stateStore: AppStateStore) {
        self.stateStore = stateStore
        self.settingsStore = .shared
        self.engine = CalculatorEngine()
        self.activeSettings = settingsStore.loadFormattingSettings()

        let contentSize = WindowPlacement.minimumSize
        let initialScreen = RollWindowController.resolvePreferredScreen(from: activeSettings)
            ?? NSScreen.main
            ?? NSScreen.screens.first
        let frame = initialScreen.map { WindowPlacement.bottomRightFrame(on: $0, size: contentSize) }
            ?? NSRect(origin: .zero, size: contentSize)

        let styleMask: NSWindow.StyleMask = activeSettings.floatingWindowEnabled ? [.titled] : [.borderless]

        let window = RollWindow(
            contentRect: frame,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = activeSettings.floatingWindowEnabled ? "FastCalc" : ""
        window.titleVisibility = activeSettings.floatingWindowEnabled ? .visible : .hidden
        window.titlebarAppearsTransparent = !activeSettings.floatingWindowEnabled
        window.isReleasedWhenClosed = false
        window.level = activeSettings.alwaysOnTop ? .floating : .normal
        window.hasShadow = true
        window.isMovableByWindowBackground = activeSettings.floatingWindowEnabled
        window.minSize = WindowPlacement.minimumSize
        window.backgroundColor = NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.90, alpha: 1.0)
        window.isOpaque = false
        window.alphaValue = CGFloat(max(0.1, min(1.0, activeSettings.inactiveWindowOpacity)))

        self.scrollView = NSScrollView(frame: window.contentView?.bounds ?? .zero)
        self.tableView = TapeTableView(frame: .zero)

        super.init(window: window)
        self.window?.delegate = self

        setupView()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange),
            name: .fastCalcSettingsDidChange,
            object: nil
        )
        applyWindowBehaviorSettings(repositionToPreferredScreen: false)
        restoreState(stateStore.load())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .fastCalcSettingsDidChange, object: nil)
    }

    @objc
    private func settingsDidChange() {
        activeSettings = settingsStore.loadFormattingSettings()
        applyWindowBehaviorSettings(repositionToPreferredScreen: true)
        reloadTape(moveToDraft: false)
    }

    private static func resolvePreferredScreen(from settings: FastCalcFormatSettings) -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }

        if let preferredScreenIndex = settings.preferredScreenIndex,
           preferredScreenIndex >= 0,
           preferredScreenIndex < screens.count
        {
            return screens[preferredScreenIndex]
        }

        return NSScreen.main ?? screens.first
    }

    private static func frameOnScreenBottomRight(screen: NSScreen, currentSize: NSSize) -> NSRect {
        let maxWidth = max(WindowPlacement.minimumSize.width, screen.visibleFrame.width - WindowPlacement.margin * 2)
        let maxHeight = max(WindowPlacement.minimumSize.height, screen.visibleFrame.height - WindowPlacement.margin * 2)
        let constrainedSize = NSSize(width: min(currentSize.width, maxWidth), height: min(currentSize.height, maxHeight))
        return WindowPlacement.bottomRightFrame(on: screen, size: constrainedSize)
    }

    private func applyWindowBehaviorSettings(repositionToPreferredScreen: Bool) {
        guard let window else { return }

        window.styleMask = activeSettings.floatingWindowEnabled ? [.titled] : [.borderless]
        window.title = activeSettings.floatingWindowEnabled ? "FastCalc" : ""
        window.titleVisibility = activeSettings.floatingWindowEnabled ? .visible : .hidden
        window.titlebarAppearsTransparent = !activeSettings.floatingWindowEnabled
        window.level = activeSettings.alwaysOnTop ? .floating : .normal
        window.isMovableByWindowBackground = activeSettings.floatingWindowEnabled

        var behavior: NSWindow.CollectionBehavior = [.fullScreenAuxiliary]
        if activeSettings.showOnAllSpaces {
            behavior.insert(.canJoinAllSpaces)
        } else {
            behavior.insert(.moveToActiveSpace)
        }
        window.collectionBehavior = behavior

        if !activeSettings.floatingWindowEnabled {
            applyMinimalBottomRightPlacement()
        } else if repositionToPreferredScreen,
                  let preferredScreen = Self.resolvePreferredScreen(from: activeSettings)
        {
            let target = Self.frameOnScreenBottomRight(screen: preferredScreen, currentSize: window.frame.size)
            window.setFrame(target, display: true, animate: true)
            saveCurrentState(isVisible: window.isVisible)
        }
    }

    public var currentText: String {
        displayRows()
            .map { "\($0.special)\t\($0.calc)\t\($0.operand)" }
            .joined(separator: "\n")
    }

    public func copyTapeTextToClipboard() {
        let rows = makePrintableRows()
        let lines = makePrintableLines(from: rows)
        let payload = lines.map(\.text).joined(separator: "\n")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(payload, forType: .string)
    }

    public func copyPreferredNumericToClipboard() {
        let payload: String?

        if let selectedRow = selectedCommittedNumericRow(),
           let parsed = TapeFormatter.parseLocaleAwareDecimal(selectedRow.calc)
        {
            payload = localizedRawDecimalString(parsed)
        } else if let lastResultRow = lastResultCommittedRow(),
                  let parsed = TapeFormatter.parseLocaleAwareDecimal(lastResultRow.calc)
        {
            payload = localizedRawDecimalString(parsed)
        } else {
            payload = nil
        }

        guard let payload else {
            NSSound.beep()
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(payload, forType: .string)
    }

    private func localizedRawDecimalString(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 16

        if let localized = formatter.string(from: NSDecimalNumber(decimal: value)) {
            return localized
        }

        return NSDecimalNumber(decimal: value).stringValue
    }

    private func selectedCommittedNumericRow() -> TapeRow? {
        let selected = tableView.selectedRow
        guard selected >= 0, selected < committedRows.count else { return nil }
        let row = committedRows[selected]
        guard TapeFormatter.parseLocaleAwareDecimal(row.calc) != nil else { return nil }
        return row
    }

    private func speakSelectedNumericValue() {
        guard let row = selectedCommittedNumericRow(),
              let parsed = TapeFormatter.parseLocaleAwareDecimal(row.calc)
        else {
            NSSound.beep()
            return
        }

        speechSynthesizer.stopSpeaking(at: .immediate)
        let spoken = localizedRawDecimalString(parsed)
        let utterance = AVSpeechUtterance(string: spoken)
        let language = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        speechSynthesizer.speak(utterance)
    }

    private func lastResultCommittedRow() -> TapeRow? {
        for row in committedRows.reversed() {
            let role = classifyRowRole(row)
            if role == "result" || role == "totalResult" {
                return row
            }
        }
        return nil
    }

    public func copyVisibleWindowPNGToClipboard() {
        guard let window, let contentView = window.contentView else {
            NSSound.beep()
            return
        }

        let bounds = contentView.bounds
        guard let imageRep = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
            NSSound.beep()
            return
        }

        imageRep.size = bounds.size
        contentView.cacheDisplay(in: bounds, to: imageRep)

        guard let pngData = imageRep.representation(using: .png, properties: [:]) else {
            NSSound.beep()
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(pngData, forType: .png)
    }

    public func printTape() {
        let printInfo = makeA4PrintInfo()
        let pageView = makePrintablePageView(printInfo: printInfo)

        let operation = NSPrintOperation(view: pageView, printInfo: printInfo)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        _ = operation.run()
    }

    public func exportTapePDF() {
        let panel = NSSavePanel()
        panel.title = "Esporta PDF"
        panel.nameFieldStringValue = "\(exportDateFormatter.string(from: Date())) FastCalc.pdf"
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        let printInfo = makeA4PrintInfo()
        printInfo.jobDisposition = NSPrintInfo.JobDisposition.save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = destinationURL

        let pageView = makePrintablePageView(printInfo: printInfo)
        let operation = NSPrintOperation(view: pageView, printInfo: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = true

        if !operation.run() {
            let alert = NSAlert()
            alert.messageText = "Impossibile esportare il PDF"
            alert.informativeText = "Si e verificato un errore durante l'esportazione del tape."
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    private var exportDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private var dateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }

    private func appVersionString() -> String {
        if let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !short.isEmpty
        {
            return short
        }

        if let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
           !build.isEmpty
        {
            return build
        }

        return Self.defaultVersion
    }

    private func makeA4PrintInfo() -> NSPrintInfo {
        let printInfo = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo.shared
        printInfo.paperSize = NSSize(width: 595.276, height: 841.89)
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0
        printInfo.orientation = .portrait
        printInfo.horizontalPagination = .automatic
        printInfo.verticalPagination = .automatic
        return printInfo
    }

    private func makePrintablePageView(printInfo: NSPrintInfo) -> TapePrintPageView {
        let printableRows = makePrintableRows()
        let lines = makePrintableLines(from: printableRows)
        let versionHeader = "FastCalc ver. \(appVersionString())"
        let timestamp = dateTimeFormatter.string(from: Date())
        return TapePrintPageView(
            lines: lines,
            headerLeft: versionHeader,
            headerRight: timestamp,
            pageSize: printInfo.paperSize
        )
    }

    private func makePrintableRows() -> [PrintableTapeRow] {
        var rows: [PrintableTapeRow] = []
        rows.reserveCapacity(committedRows.count)

        for (index, row) in committedRows.enumerated() {
            if row.kind == .draft {
                continue
            }

            let calcValue: String
            if row.kind == .separator || row.operand == Self.totalSeparatorMarker {
                calcValue = separatorLineText(totalWidth: max(12, calcColumnChars))
            } else {
                calcValue = row.calc
            }

            let operandValue = row.operand == Self.totalSeparatorMarker ? "" : row.operand
            rows.append(PrintableTapeRow(lineNumber: index + 1, calc: calcValue, note: row.annotation, operand: operandValue))
        }

        return rows
    }

    private func makePrintableLines(from rows: [PrintableTapeRow]) -> [TapePrintableLine] {
        let calcColumnWidth = max(rows.map(\.calc.count).max() ?? 1, calcColumnChars)
        let noteColumnWidth = max(rows.map(\.note.count).max() ?? 1, noteColumnChars)
        let lineColumnWidth = max(rows.last.map { String($0.lineNumber).count } ?? 1, 2)

        var lines: [TapePrintableLine] = []
        lines.reserveCapacity(max(rows.count, 1))
        if rows.isEmpty {
            lines.append(TapePrintableLine(text: "0", isNegative: false))
            return lines
        }

        for row in rows {
            let lineNumber = leftPadded(String(row.lineNumber), toLength: lineColumnWidth)
            let note = leftPadded(row.note, toLength: noteColumnWidth)
            let calc = leftPadded(row.calc, toLength: calcColumnWidth)
            let operand = leftPadded(row.operand, toLength: 2)
            let lineText = "\(lineNumber)  \(note)  \(calc)  \(operand)"
            let isNegative = TapeFormatter.parseLocaleAwareDecimal(row.calc).map { $0 < 0 } ?? false
            lines.append(TapePrintableLine(text: lineText, isNegative: isNegative))
        }

        return lines
    }

    private func leftPadded(_ value: String, toLength target: Int, with pad: Character = " ") -> String {
        guard value.count < target else { return value }
        return String(repeating: String(pad), count: target - value.count) + value
    }

    private func classifyRowRole(_ row: TapeRow) -> String {
        if row.kind == .note {
            return "note"
        }
        if row.kind == .text || row.operand == "#" {
            return "textRow"
        }
        if row.operand == Self.totalSeparatorMarker {
            return "separator"
        }
        if row.operand == "C" {
            return "reset"
        }
        if "+-*/D".contains(row.operand) {
            return "operator"
        }
        if row.operand == "%" {
            return "percent"
        }
        if row.operand == "=" {
            return "valueForResult"
        }
        if row.operand == "T" {
            return "totalResult"
        }
        if row.operand == "↑" || row.operand == "↓" || row.operand == "~" {
            return "result"
        }
        if row.operand.isEmpty {
            return "result"
        }
        return "other"
    }

    private func rowKindFromStoredData(calc: String, operand: String) -> TapeRowKind {
        switch classifyRowRole(TapeRow(special: "", calc: calc, operand: operand, kind: .committed)) {
        case "note":
            return .note
        case "textRow":
            return .text
        case "separator":
            return .separator
        case "reset":
            return .reset
        case "totalResult":
            return .total
        case "result":
            return .result
        default:
            return .committed
        }
    }

    private func isEditableOperandRow(index: Int) -> Bool {
        guard index >= 0 && index < committedRows.count else { return false }
        let role = classifyRowRole(committedRows[index])
        return role == "operator" || role == "percent" || role == "valueForResult" || role == "textRow"
    }

    private func isSelectableSelectionRow(index: Int, rows: [TapeRow]? = nil) -> Bool {
        if index < 0 {
            return false
        }

        let currentRows = rows ?? displayRows()
        if index >= currentRows.count {
            return false
        }

        if index == draftRowIndex() {
            return true
        }

        let row = currentRows[index]
        if row.kind == .note || row.kind == .text {
            return true
        }
        return TapeFormatter.parseLocaleAwareDecimal(row.calc) != nil
    }

    private func beginEditingCommittedRow(_ index: Int) {
        guard !isEditingModeActive else { return }
        guard isEditableOperandRow(index: index) else { return }

        if classifyRowRole(committedRows[index]) == "textRow" {
            isTextModeActive = true
            textEditingRow = index
            textOriginalText = committedRows[index].calc
            textDraftInput = ""
            reloadTape(moveToDraft: false)
            focusTextEditor()
            return
        }

        editingCommittedRow = index
        isEditingModeActive = true
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)

        let calcColumn = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier("calc"))
        guard calcColumn >= 0 else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let cell = self.tableView.view(atColumn: calcColumn, row: index, makeIfNecessary: false) as? NSTableCellView,
                  let field = cell.textField
            else {
                return
            }

            self.window?.makeFirstResponder(field)
            if let editor = field.currentEditor() {
                editor.selectedRange = NSRange(location: 0, length: (field.stringValue as NSString).length)
            }
        }
    }

    private func commitEditingValue() {
        guard let row = editingCommittedRow else { return }
        guard row >= 0 && row < committedRows.count else {
            editingCommittedRow = nil
            isEditingModeActive = false
            return
        }
        let calcColumn = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier("calc"))
        guard calcColumn >= 0 else { return }

        guard let cell = tableView.view(atColumn: calcColumn, row: row, makeIfNecessary: false) as? NSTableCellView,
              let field = cell.textField
        else {
            editingCommittedRow = nil
            isEditingModeActive = false
            return
        }

        let raw = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = TapeFormatter.parseLocaleAwareDecimal(raw) else {
            NSSound.beep()
            field.stringValue = committedRows[row].calc
            return
        }

        let role = classifyRowRole(committedRows[row])
        let allowsNegative = (role == "valueForResult")
        if !allowsNegative && value < 0 {
            NSSound.beep()
            field.stringValue = committedRows[row].calc
            return
        }

        committedRows[row].calc = TapeFormatter.formatDecimalForColumn(value)
        editingCommittedRow = nil
        isEditingModeActive = false
        pendingPercentTrace = nil

        recomputeCommittedRows(editedRowIndex: row)
        reloadTape(moveToDraft: false)

        let target = min(max(0, row), max(0, committedRows.count - 1))
        if committedRows.count > 0 {
            tableView.selectRowIndexes(IndexSet(integer: target), byExtendingSelection: false)
            tableView.scrollRowToVisible(target)
        }
        window?.makeFirstResponder(tableView)
        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    private func cancelEditingValue() {
        guard let row = editingCommittedRow else { return }
        editingCommittedRow = nil
        isEditingModeActive = false

        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
        window?.makeFirstResponder(tableView)
    }

    private func feedDecimal(_ value: Decimal, to replayEngine: CalculatorEngine) {
        replayEngine.replaceCurrentInput(with: value)
    }

    private func normalizeContributionForEngine(_ editedSignedContribution: Decimal, op: CalculatorOperator?) -> Decimal {
        switch op {
        case .subtract:
            return editedSignedContribution < 0 ? -editedSignedContribution : editedSignedContribution
        default:
            return editedSignedContribution
        }
    }

    private func makeTotalSeparatorRow() -> TapeRow {
        let dashes = separatorLineText(totalWidth: max(8, calcColumnChars - 2))
        return TapeRow(special: "", calc: dashes, operand: Self.totalSeparatorMarker, kind: .separator)
    }

    private func separatorLineText(totalWidth: Int) -> String {
        let width = max(8, totalWidth)
        let dashCount = max(4, (width / 3) + 1)
        return Array(repeating: String(Self.totalSeparatorGlyph), count: dashCount).joined(separator: " ")
    }

    private func recomputeCommittedRows(editedRowIndex: Int?) {
        let originalRows = committedRows
        let preservedFIFO = engine.snapshot().totalizerFIFO
        let replayEngine = CalculatorEngine()
        var rebuiltRows: [TapeRow] = []
        var replayPercentTrace: PercentTrace?
        var pendingPercentRowIndex: Int?

        for (originalIndex, row) in originalRows.enumerated() {
            let role = classifyRowRole(row)
            switch role {
            case "separator":
                var separator = makeTotalSeparatorRow()
                separator.annotation = row.annotation
                rebuiltRows.append(separator)

            case "reset":
                _ = replayEngine.pressDelete()
                rebuiltRows.append(TapeRow(special: Self.resetBaselineRow.special, calc: Self.resetBaselineRow.calc, operand: Self.resetBaselineRow.operand, annotation: row.annotation, kind: .reset))
                replayPercentTrace = nil
                pendingPercentRowIndex = nil

            case "operator":
                guard let value = TapeFormatter.parseLocaleAwareDecimal(row.calc) else { continue }
                let formatted = TapeFormatter.formatDecimalForColumn(value)
                rebuiltRows.append(TapeRow(special: "", calc: formatted, operand: row.operand, annotation: row.annotation, kind: .committed))
                feedDecimal(value, to: replayEngine)
                if let op = row.operand.first {
                    _ = replayEngine.inputCharacter(op)
                }
                replayPercentTrace = nil
                pendingPercentRowIndex = nil

            case "percent":
                guard let value = TapeFormatter.parseLocaleAwareDecimal(row.calc) else { continue }
                let formatted = TapeFormatter.formatDecimalForColumn(value)
                rebuiltRows.append(TapeRow(special: "", calc: formatted, operand: "%", annotation: row.annotation, kind: .committed))
                pendingPercentRowIndex = rebuiltRows.count - 1
                feedDecimal(value, to: replayEngine)
                let snap = replayEngine.snapshot()
                if let converted = replayEngine.applyPercent() {
                    replayPercentTrace = PercentTrace(convertedValue: converted, pendingOperator: snap.pendingOperator, baseValue: snap.register)
                } else {
                    replayPercentTrace = nil
                    pendingPercentRowIndex = nil
                }

            case "valueForResult":
                if let trace = replayPercentTrace {
                    if editedRowIndex == originalIndex {
                        guard let editedSigned = TapeFormatter.parseLocaleAwareDecimal(row.calc) else {
                            continue
                        }

                        let converted = normalizeContributionForEngine(editedSigned, op: trace.pendingOperator)
                        replayEngine.replaceCurrentInput(with: converted)

                        if let percentRowIndex = pendingPercentRowIndex,
                           let base = trace.baseValue,
                           base != 0
                        {
                            var updatedPercent = (converted * 100) / base
                            if trace.pendingOperator == .subtract, updatedPercent < 0 {
                                updatedPercent *= -1
                            }
                            rebuiltRows[percentRowIndex].calc = TapeFormatter.formatDecimalForColumn(updatedPercent)
                        }

                        replayPercentTrace = PercentTrace(
                            convertedValue: converted,
                            pendingOperator: trace.pendingOperator,
                            baseValue: trace.baseValue
                        )
                    }
                    continue
                }

                guard let value = TapeFormatter.parseLocaleAwareDecimal(row.calc) else { continue }
                let formatted = TapeFormatter.formatDecimalForColumn(value)
                rebuiltRows.append(TapeRow(special: "", calc: formatted, operand: "=", annotation: row.annotation, kind: .committed))
                feedDecimal(value, to: replayEngine)

            case "result", "totalResult":
                if let trace = replayPercentTrace {
                    let signed = signedPercentContribution(trace)
                    rebuiltRows.append(
                        TapeRow(
                            special: "",
                            calc: TapeFormatter.formatDecimalForColumn(signed),
                            operand: "=",
                            kind: .committed
                        )
                    )
                    replayPercentTrace = nil
                }

                let key: ResultKey = role == "totalResult" ? .total : .enter
                let result = replayEngine.pressResult(key)
                if result.kind == .ignored {
                    continue
                }

                let op: String
                let kind: TapeRowKind
                if result.kind == .totalRecall {
                    op = "T"
                    kind = .total
                } else if key == .total {
                    op = "T"
                    kind = .total
                } else {
                    op = ""
                    kind = .result
                }

                rebuiltRows.append(
                    TapeRow(
                        special: "",
                        calc: TapeFormatter.formatDecimalForColumn(result.value),
                        operand: {
                            if kind == .result {
                                let marker = TapeFormatter.resultIndicator(for: result.value, settings: activeSettings)
                                return marker.isEmpty ? op : marker
                            }
                            return op
                        }(),
                        annotation: row.annotation,
                        kind: kind
                    )
                )
                pendingPercentRowIndex = nil

            default:
                rebuiltRows.append(row)
            }
        }

        committedRows = rebuiltRows
        replayEngine.replaceTotalizerFIFO(with: preservedFIFO)
        engine = replayEngine
    }

    public func currentPreviewValue() -> Decimal? {
        if !draftInput.isEmpty, let draftValue = TapeFormatter.parseLocaleAwareDecimal(draftInput) {
            return draftValue
        }

        for row in displayRows().reversed() {
            if row.calc.isEmpty { continue }
            if let value = TapeFormatter.parseLocaleAwareDecimal(row.calc) {
                return value
            }
        }

        return nil
    }

    public func setOperandColumnLocked(_ isLocked: Bool) {
        isOperandColumnLocked = isLocked
    }

    public func toggleVisibility() {
        guard let window else { return }
        if window.isVisible {
            if window.isKeyWindow {
                saveCurrentState(isVisible: false)
                window.orderOut(nil)
                hasInputFocus = false
                updateStatusRow()
            } else {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                focusDraftRow()
                saveCurrentState(isVisible: true)
                updateInputFocusState()
            }
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            focusDraftRow()
            saveCurrentState(isVisible: true)
            updateInputFocusState()
        }
    }

    public func applyMinimalBottomRightPlacement() {
        guard let window else { return }
        guard let screen = Self.resolvePreferredScreen(from: activeSettings) ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = WindowPlacement.bottomRightFrame(on: screen, size: WindowPlacement.minimumSize)
        window.setFrame(frame, display: true, animate: true)
    }

    public func moveWindowToScreen(_ screenIndex: Int, persistPreference: Bool) {
        guard let window else { return }
        let screens = NSScreen.screens
        guard screenIndex >= 0, screenIndex < screens.count else { return }

        let targetFrame = Self.frameOnScreenBottomRight(screen: screens[screenIndex], currentSize: window.frame.size)
        window.setFrame(targetFrame, display: true, animate: true)

        if persistPreference {
            activeSettings.preferredScreenIndex = screenIndex
            settingsStore.saveFormattingSettings(activeSettings)
        } else {
            saveCurrentState(isVisible: window.isVisible)
        }
    }

    public func persistState() {
        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    public func loadPersistedVisibility() {
        let state = stateStore.load()
        let shouldShowAtLaunch: Bool
        switch activeSettings.startupMode {
        case .visible:
            shouldShowAtLaunch = true
        case .hidden:
            shouldShowAtLaunch = false
        case .default:
            shouldShowAtLaunch = state.windowVisible
        }

        if shouldShowAtLaunch {
            window?.makeKeyAndOrderFront(nil)
            focusDraftRow()
            updateInputFocusState()
            saveCurrentState(isVisible: true)
        } else {
            window?.orderOut(nil)
            hasInputFocus = false
            updateStatusRow()
            saveCurrentState(isVisible: false)
        }
    }

    public func resetRollAndPlacement() {
        committedRows = [Self.resetBaselineRow]
        draftInput = ""
        draftCursor = 0
        hasPendingLeadingNegativeSign = false
        isNoteModeActive = false
        noteEditingRow = nil
        noteOriginalText = ""
        noteDraftInput = ""
        isTextModeActive = false
        textEditingRow = nil
        textOriginalText = ""
        textDraftInput = ""
        editingCommittedRow = nil
        isEditingModeActive = false
        pendingPercentTrace = nil
        reloadTape(moveToDraft: true)
        applyMinimalBottomRightPlacement()
        saveCurrentState(isVisible: true)
    }

    private func setupView() {
        guard let contentView = window?.contentView else { return }

        let calcFont = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        let smallFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let operandFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let textColor = NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.10, alpha: 1.0)
        let paperColor = NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.92, alpha: 1.0)

        tableView.headerView = nil
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.rowHeight = defaultRowHeight
        tableView.gridStyleMask = []
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.backgroundColor = paperColor
        tableView.focusRingType = .none
        tableView.selectionHighlightStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(handleTableDoubleClick(_:))

        let calcCharWidth = ("0" as NSString).size(withAttributes: [.font: calcFont]).width
        let smallCharWidth = ("0" as NSString).size(withAttributes: [.font: smallFont]).width
        let specialWidth = max(30, CGFloat(specialColumnChars) * smallCharWidth + 10)
        let noteWidth = max(68, CGFloat(noteColumnChars) * smallCharWidth + 8)
        let operandWidth = max(30, CGFloat(operandColumnChars) * smallCharWidth + 8)

        let specialCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("special"))
        specialCol.width = specialWidth
        specialCol.minWidth = specialWidth
        specialCol.maxWidth = specialWidth

        let operandCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("operand"))
        operandCol.width = operandWidth
        operandCol.minWidth = operandWidth
        operandCol.maxWidth = operandWidth

        let noteCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("note"))
        noteCol.width = noteWidth
        noteCol.minWidth = noteWidth
        noteCol.maxWidth = noteWidth

        let calcCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("calc"))
        calcCol.width = max(220, CGFloat(calcColumnChars) * calcCharWidth + 24)
        calcCol.minWidth = 1
        calcCol.resizingMask = .autoresizingMask

        tableView.addTableColumn(specialCol)
        tableView.addTableColumn(noteCol)
        tableView.addTableColumn(calcCol)
        tableView.addTableColumn(operandCol)
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        calcTableColumn = calcCol

        tableView.onKeyEvent = { [weak self] event in
            self?.handleKeyEvent(event) ?? false
        }

        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = paperColor
        scrollView.documentView = tableView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        statusBarView.translatesAutoresizingMaskIntoConstraints = false
        statusBarView.wantsLayer = true
        statusBarView.layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.08).cgColor

        statusLedView.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.alignment = .right

        contentView.addSubview(scrollView)
        contentView.addSubview(statusBarView)
        statusBarView.addSubview(statusLedView)
        statusBarView.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusBarView.topAnchor),

            statusBarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statusBarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            statusBarView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            statusBarView.heightAnchor.constraint(equalToConstant: statusBarHeight),

            statusLedView.leadingAnchor.constraint(equalTo: statusBarView.leadingAnchor, constant: 8),
            statusLedView.centerYAnchor.constraint(equalTo: statusBarView.centerYAnchor),
            statusLedView.widthAnchor.constraint(equalToConstant: 8),
            statusLedView.heightAnchor.constraint(equalToConstant: 8),

            statusLabel.centerYAnchor.constraint(equalTo: statusBarView.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: statusBarView.trailingAnchor, constant: -8)
        ])

        // Keep rendering attributes in one place for cell creation.
        calcCellFont = calcFont
        compactCellFont = smallFont
        operandCellFont = operandFont
        cellColor = textColor
        if committedRows.isEmpty {
            committedRows = [Self.resetBaselineRow]
        }
        updateStatusRow()
        reloadTape(moveToDraft: true)
        DispatchQueue.main.async { [weak self] in
            self?.updateCalcColumnWidth()
        }
    }

    private var calcCellFont: NSFont = .monospacedSystemFont(ofSize: 18, weight: .regular)
    private var compactCellFont: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
    private var operandCellFont: NSFont = .monospacedSystemFont(ofSize: 11, weight: .regular)
    private var cellColor: NSColor = .labelColor
    private var calcTableColumn: NSTableColumn?

    private func displayRows() -> [TapeRow] {
        var rows = committedRows
        if isTextModeActive, textEditingRow == nil {
            rows.append(TapeRow(special: "", calc: textDraftInput, operand: "#", kind: .text))
            return rows
        }
        if isNoteModeActive, noteEditingRow == nil {
            rows.append(TapeRow(special: "", calc: "", operand: "", annotation: noteDraftInput, kind: .note))
            return rows
        }
        let draftCalc = draftInput.isEmpty ? "" : (TapeFormatter.parseLocaleAwareDecimal(draftInput).map(TapeFormatter.formatDecimalForColumn) ?? draftInput)
        rows.append(TapeRow(special: "", calc: draftCalc, operand: "", kind: .draft))
        return rows
    }

    private func draftRowIndex() -> Int {
        max(0, displayRows().count - 1)
    }

    private func focusDraftRow() {
        let row = draftRowIndex()
        if row >= 0 {
            let previous = markerSelectedRow
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            markerSelectedRow = row
            refreshCursorMarker(previous: previous, current: markerSelectedRow)
            window?.makeFirstResponder(tableView)
            updateInputFocusState()
            DispatchQueue.main.async { [weak self] in
                self?.scrollToBottom()
            }
        }
    }

    private func reloadTape(moveToDraft: Bool) {
        tableView.reloadData()
        adjustWindowHeight(forDisplayedRows: displayRows().count)
        updateStatusRow()
        if moveToDraft {
            focusDraftRow()
        }
    }

    private func saveCurrentState(isVisible: Bool) {
        let text = committedRows
            .map { "\($0.special)\t\($0.calc)\t\($0.operand)\t\($0.annotation)\t\($0.kind.rawValue)" }
            .joined(separator: "\n")

        let state = FastCalcAppState(
            rollText: text,
            selectedLocation: tableView.selectedRow,
            scrollOffsetY: scrollView.contentView.bounds.origin.y,
            windowFrame: window?.frame,
            windowVisible: isVisible
        )
        stateStore.save(state)
    }

    private func restoreState(_ state: FastCalcAppState) {
        if let frame = state.windowFrame {
            window?.setFrame(frame, display: false)
        } else {
            applyMinimalBottomRightPlacement()
        }

        committedRows.removeAll()
        if !state.rollText.isEmpty {
            let lines = state.rollText.split(separator: "\n", omittingEmptySubsequences: false)
            for line in lines {
                let parts = String(line).split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                let special = parts.count > 0 ? parts[0] : ""
                let calc = parts.count > 1 ? parts[1] : ""
                let operand = parts.count > 2 ? parts[2] : ""
                let annotation = parts.count > 3 ? parts[3] : ""
                let kind = parts.count > 4
                    ? TapeRowKind(rawValue: parts[4]) ?? rowKindFromStoredData(calc: calc, operand: operand)
                    : rowKindFromStoredData(calc: calc, operand: operand)
                committedRows.append(TapeRow(special: special, calc: calc, operand: operand, annotation: annotation, kind: kind))
            }
        }

        if committedRows.isEmpty {
            committedRows = [Self.resetBaselineRow]
        }

        draftInput = ""
        draftCursor = 0
        hasPendingLeadingNegativeSign = false
        isNoteModeActive = false
        noteEditingRow = nil
        noteOriginalText = ""
        noteDraftInput = ""
        isTextModeActive = false
        textEditingRow = nil
        textOriginalText = ""
        textDraftInput = ""
        editingCommittedRow = nil
        isEditingModeActive = false
        pendingPercentTrace = nil
        reloadTape(moveToDraft: false)

        let selected = min(max(0, state.selectedLocation), max(0, displayRows().count - 1))
        if displayRows().count > 0 {
            let previous = markerSelectedRow
            tableView.selectRowIndexes(IndexSet(integer: selected), byExtendingSelection: false)
            markerSelectedRow = selected
            refreshCursorMarker(previous: previous, current: markerSelectedRow)
        }

        DispatchQueue.main.async { [weak self] in
            self?.scrollToBottom()
        }
    }

    public func windowDidResize(_ notification: Notification) {
        guard !isAdjustingWindowHeight else { return }
        updateCalcColumnWidth()
        tableView.reloadData()
        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    public func windowDidMove(_ notification: Notification) {
        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    public func windowDidBecomeKey(_ notification: Notification) {
        updateInputFocusState()
    }

    public func windowDidResignKey(_ notification: Notification) {
        hasInputFocus = false
        updateStatusRow()
    }

    private func updateInputFocusState() {
        hasInputFocus = window?.isKeyWindow ?? false
        updateStatusRow()
    }

    private func updateStatusRow() {
        statusLedView.setOn(hasInputFocus)
        let snapshot = engine.snapshot()
        let fifoCount = snapshot.totalizerFIFO.count
        let gtText = TapeFormatter.formatDecimalForColumn(snapshot.totalizer, settings: activeSettings)

        if fifoCount == 0, snapshot.totalizer == 0 {
            statusLabel.stringValue = ""
        } else if fifoCount > 0 {
            statusLabel.stringValue = "\(fifoCount) GT: \(gtText)"
        } else {
            statusLabel.stringValue = "GT: \(gtText)"
        }
        window?.alphaValue = hasInputFocus ? activeAlpha : inactiveAlpha
    }

    private func updateCalcColumnWidth() {
        guard let col = calcTableColumn else { return }
        let available = scrollView.contentSize.width
        let fixed = tableView.tableColumns.filter { $0 !== col }.reduce(0) { $0 + $1.width }
        let spacing = CGFloat(tableView.tableColumns.count - 1) * tableView.intercellSpacing.width
        let remaining = available - fixed - spacing - operandRightPadding
        let newWidth = max(1, remaining)
        if abs(col.width - newWidth) > 0.5 {
            col.width = newWidth
        }
    }

    private func markerHighlightColor(for row: TapeRow, index: Int) -> NSColor {
        let isEditableValue = index == draftRowIndex() || isEditableOperandRow(index: index)
        if isEditableValue {
            if let value = TapeFormatter.parseLocaleAwareDecimal(row.calc), value < 0 {
                return NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.62, alpha: 0.24)
            }
            return NSColor(calibratedRed: 0.68, green: 0.93, blue: 0.68, alpha: 0.26)
        }
        return NSColor(calibratedRed: 0.60, green: 0.82, blue: 1.0, alpha: 0.24)
    }

    private func refreshCursorMarker(previous: Int, current: Int) {
        let allColumns = tableView.tableColumns.indices
        guard !allColumns.isEmpty else {
            tableView.reloadData()
            return
        }

        var rows = IndexSet()
        if previous >= 0 {
            rows.insert(previous)
        }
        if current >= 0 {
            rows.insert(current)
        }

        if rows.isEmpty {
            return
        }

        tableView.reloadData(forRowIndexes: rows, columnIndexes: IndexSet(allColumns))
    }

    private func sanitizeNoteText(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private func sanitizeTextRowInput(_ raw: String) -> String {
        let linear = raw
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let scalars = linear.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        return String(String.UnicodeScalarView(scalars))
    }

    private func pasteNumericFromClipboardIfAvailable() -> Bool {
        guard !isNoteModeActive, !isTextModeActive, !isEditingModeActive else { return false }
        guard let raw = NSPasteboard.general.string(forType: .string) else { return false }

        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard let value = TapeFormatter.parseLocaleAwareDecimal(normalized) else { return false }

        engine.replaceCurrentInput(with: value)
        let plain = NSDecimalNumber(decimal: value).stringValue
        draftInput = plain.replacingOccurrences(of: ".", with: ",")
        draftCursor = draftInput.count
        hasPendingLeadingNegativeSign = draftInput == "-"
        pendingPercentTrace = nil

        reloadTape(moveToDraft: true)
        saveCurrentState(isVisible: window?.isVisible ?? false)
        return true
    }

    private func hasActiveCalculation() -> Bool {
        let snapshot = engine.snapshot()
        return !draftInput.isEmpty || snapshot.pendingOperator != nil || pendingPercentTrace != nil
    }

    private func toggleNoteMode() {
        if isTextModeActive {
            NSSound.beep()
            return
        }

        if isNoteModeActive {
            commitAndExitNoteMode()
            return
        }

        let selected = tableView.selectedRow
        if selected >= 0, selected < committedRows.count {
            isNoteModeActive = true
            noteEditingRow = selected
            noteOriginalText = committedRows[selected].annotation
            noteDraftInput = ""
            reloadTape(moveToDraft: false)
            focusNoteEditor()
            saveCurrentState(isVisible: window?.isVisible ?? false)
            return
        }

        guard selected == draftRowIndex(), !hasActiveCalculation() else {
            NSSound.beep()
            return
        }

        isNoteModeActive = true
        noteEditingRow = nil
        noteOriginalText = ""
        noteDraftInput = ""
        reloadTape(moveToDraft: true)
        focusNoteEditor()
        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    private func toggleTextMode() {
        if isNoteModeActive || isEditingModeActive {
            NSSound.beep()
            return
        }

        if isTextModeActive {
            commitAndExitTextMode()
            return
        }

        if TapeFormatter.parseLocaleAwareDecimal(draftInput) != nil {
            NSSound.beep()
            return
        }

        let selected = tableView.selectedRow
        if selected >= 0, selected < committedRows.count, classifyRowRole(committedRows[selected]) == "textRow" {
            isTextModeActive = true
            textEditingRow = selected
            textOriginalText = committedRows[selected].calc
            textDraftInput = ""
            reloadTape(moveToDraft: false)
            focusTextEditor()
            saveCurrentState(isVisible: window?.isVisible ?? false)
            return
        }

        let selectedIsResetRow = selected >= 0
            && selected < committedRows.count
            && classifyRowRole(committedRows[selected]) == "reset"

        guard selected == draftRowIndex() || (selectedIsResetRow && !hasActiveCalculation()) else {
            NSSound.beep()
            return
        }

        isTextModeActive = true
        textEditingRow = nil
        textOriginalText = ""
        textDraftInput = ""
        reloadTape(moveToDraft: true)
        focusTextEditor()
        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    private func syncTextEditorTextToModel() {
        if let row = textEditingRow, row >= 0, row < committedRows.count {
            let calcColumn = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier("calc"))
            if calcColumn >= 0,
               let cell = tableView.view(atColumn: calcColumn, row: row, makeIfNecessary: false) as? NSTableCellView,
               let value = cell.textField?.stringValue
            {
                committedRows[row].calc = String(sanitizeTextRowInput(value).prefix(maxTextRowCharacters))
            }
            return
        }

        let draftRow = draftRowIndex()
        let calcColumn = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier("calc"))
        if calcColumn >= 0,
           draftRow >= 0,
           let cell = tableView.view(atColumn: calcColumn, row: draftRow, makeIfNecessary: false) as? NSTableCellView,
           let value = cell.textField?.stringValue
        {
            textDraftInput = String(sanitizeTextRowInput(value).prefix(maxTextRowCharacters))
        }
    }

    private func focusTextEditor() {
        guard isTextModeActive else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let targetRow: Int
            if let row = self.textEditingRow, row >= 0, row < self.committedRows.count {
                targetRow = row
            } else {
                targetRow = self.draftRowIndex()
            }

            let calcColumn = self.tableView.column(withIdentifier: NSUserInterfaceItemIdentifier("calc"))
            guard calcColumn >= 0,
                  let cell = self.tableView.view(atColumn: calcColumn, row: targetRow, makeIfNecessary: false) as? NSTableCellView,
                  let field = cell.textField
            else {
                return
            }

            self.window?.makeFirstResponder(field)
            if let editor = field.currentEditor() {
                let length = (field.stringValue as NSString).length
                editor.selectedRange = NSRange(location: length, length: 0)
            }
        }
    }

    private func commitAndExitTextMode() {
        guard isTextModeActive else { return }
        let editedRow = textEditingRow

        syncTextEditorTextToModel()

        if let row = textEditingRow, row >= 0, row < committedRows.count {
            let sanitized = sanitizeTextRowInput(committedRows[row].calc)
            committedRows[row].calc = String(sanitized.prefix(maxTextRowCharacters))
            committedRows[row].operand = "#"
            committedRows[row].kind = .text
        } else {
            let sanitized = sanitizeTextRowInput(textDraftInput).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sanitized.isEmpty {
                committedRows.append(TapeRow(special: "", calc: String(sanitized.prefix(maxTextRowCharacters)), operand: "#", kind: .text))
            }
        }

        isTextModeActive = false
        textEditingRow = nil
        textOriginalText = ""
        textDraftInput = ""

        if let editedRow, editedRow >= 0, editedRow < committedRows.count {
            reloadTape(moveToDraft: false)
            tableView.selectRowIndexes(IndexSet(integer: editedRow), byExtendingSelection: false)
            tableView.scrollRowToVisible(editedRow)
            window?.makeFirstResponder(tableView)
        } else {
            reloadTape(moveToDraft: true)
        }
        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    private func cancelAndExitTextMode() {
        guard isTextModeActive else { return }
        let editedRow = textEditingRow

        if let row = textEditingRow, row >= 0, row < committedRows.count {
            committedRows[row].calc = textOriginalText
        }

        isTextModeActive = false
        textEditingRow = nil
        textOriginalText = ""
        textDraftInput = ""

        if let editedRow, editedRow >= 0, editedRow < committedRows.count {
            reloadTape(moveToDraft: false)
            tableView.selectRowIndexes(IndexSet(integer: editedRow), byExtendingSelection: false)
            tableView.scrollRowToVisible(editedRow)
            window?.makeFirstResponder(tableView)
        } else {
            reloadTape(moveToDraft: true)
        }
        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    private func handleTextModeKeyEvent(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case 53: // escape
            cancelAndExitTextMode()
            return true
        case 36, 76: // enter
            commitAndExitTextMode()
            return true
        default:
            break
        }
        return false
    }

    private func syncNoteEditorTextToModel() {
        if let row = noteEditingRow, row >= 0, row < committedRows.count {
            let targetColumn = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier("note"))
            if targetColumn >= 0,
               let cell = tableView.view(atColumn: targetColumn, row: row, makeIfNecessary: false) as? NSTableCellView,
               let value = cell.textField?.stringValue
            {
                committedRows[row].annotation = String(sanitizeNoteText(value).prefix(maxInlineNoteCharacters))
            }
            return
        }

        let draftRow = draftRowIndex()
        let noteColumn = tableView.column(withIdentifier: NSUserInterfaceItemIdentifier("note"))
        if noteColumn >= 0,
           draftRow >= 0,
           let cell = tableView.view(atColumn: noteColumn, row: draftRow, makeIfNecessary: false) as? NSTableCellView,
           let value = cell.textField?.stringValue
        {
            noteDraftInput = String(sanitizeNoteText(value).prefix(maxInlineNoteCharacters))
        }
    }

    private func focusNoteEditor() {
        guard isNoteModeActive else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let targetRow: Int
            let targetColumnId: String
            if let row = self.noteEditingRow, row >= 0, row < self.committedRows.count {
                targetRow = row
                targetColumnId = "note"
            } else {
                targetRow = self.draftRowIndex()
                targetColumnId = "note"
            }

            let targetColumn = self.tableView.column(withIdentifier: NSUserInterfaceItemIdentifier(targetColumnId))
            guard targetColumn >= 0,
                  let cell = self.tableView.view(atColumn: targetColumn, row: targetRow, makeIfNecessary: false) as? NSTableCellView,
                  let field = cell.textField
            else {
                return
            }

            self.window?.makeFirstResponder(field)
            if let editor = field.currentEditor() {
                let length = (field.stringValue as NSString).length
                editor.selectedRange = NSRange(location: length, length: 0)
            }
        }
    }

    private func commitAndExitNoteMode() {
        guard isNoteModeActive else { return }
        let editedRow = noteEditingRow

        syncNoteEditorTextToModel()

        if let row = noteEditingRow, row >= 0, row < committedRows.count {
            let sanitized = sanitizeNoteText(committedRows[row].annotation)
            committedRows[row].annotation = String(sanitized.prefix(maxInlineNoteCharacters))
        } else {
            let sanitized = sanitizeNoteText(noteDraftInput).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sanitized.isEmpty {
                committedRows.append(TapeRow(special: "", calc: "", operand: "", annotation: String(sanitized.prefix(maxInlineNoteCharacters)), kind: .note))
            }
        }

        isNoteModeActive = false
        noteEditingRow = nil
        noteOriginalText = ""
        noteDraftInput = ""

        if let editedRow, editedRow >= 0, editedRow < committedRows.count {
            reloadTape(moveToDraft: false)
            tableView.selectRowIndexes(IndexSet(integer: editedRow), byExtendingSelection: false)
            tableView.scrollRowToVisible(editedRow)
            window?.makeFirstResponder(tableView)
        } else {
            reloadTape(moveToDraft: true)
        }
        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    private func cancelAndExitNoteMode() {
        guard isNoteModeActive else { return }
        let editedRow = noteEditingRow

        if let row = noteEditingRow, row >= 0, row < committedRows.count {
            committedRows[row].annotation = noteOriginalText
        }

        isNoteModeActive = false
        noteEditingRow = nil
        noteOriginalText = ""
        noteDraftInput = ""

        if let editedRow, editedRow >= 0, editedRow < committedRows.count {
            reloadTape(moveToDraft: false)
            tableView.selectRowIndexes(IndexSet(integer: editedRow), byExtendingSelection: false)
            tableView.scrollRowToVisible(editedRow)
            window?.makeFirstResponder(tableView)
        } else {
            reloadTape(moveToDraft: true)
        }
        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    private func handleNoteModeKeyEvent(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case 53: // escape
            cancelAndExitNoteMode()
            return true
        case 36, 76: // enter
            commitAndExitNoteMode()
            return true
        default:
            break
        }
        return false
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers?.lowercased(),
           chars == "z"
        {
            handleUndoAfterFullClear()
            return true
        }

        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers?.lowercased(),
           chars == "v"
        {
            return pasteNumericFromClipboardIfAvailable()
        }

        if let rawChars = event.characters, rawChars.contains("%") {
            handlePercent()
            return true
        }

        if let rawChars = event.characters, rawChars.contains("#") {
            toggleTextMode()
            return true
        }

        if event.modifierFlags.intersection([.command, .option, .control]).isEmpty,
           let rawChars = event.charactersIgnoringModifiers?.lowercased(),
           rawChars.contains("s"),
           !isNoteModeActive,
           !isTextModeActive,
           !isEditingModeActive
        {
            speakSelectedNumericValue()
            return true
        }

        if isNoteModeActive {
            if handleNoteModeKeyEvent(event) {
                return true
            }
        }

        if isTextModeActive {
            if handleTextModeKeyEvent(event) {
                return true
            }
        }

        if isEditingModeActive {
            switch Int(event.keyCode) {
            case 36, 76:
                commitEditingValue()
                return true
            case 53: // escape
                cancelEditingValue()
                return true
            default:
                break
            }
        }

        switch Int(event.keyCode) {
        case 126: // up
            moveSelectionVertically(-1)
            return true
        case 125: // down
            moveSelectionVertically(1)
            return true
        case 116: // page up
            moveSelectionByPage(-1)
            return true
        case 121: // page down
            moveSelectionByPage(1)
            return true
        case 123: // left
            moveDraftCursor(-1)
            return true
        case 124: // right
            moveDraftCursor(1)
            return true
        case 115: // home
            moveSelectionToBoundary(first: true)
            return true
        case 119: // end
            moveSelectionToBoundary(first: false)
            return true
        case 51: // backspace
            handleBackspace()
            return true
        case 117: // forward delete
            handleDelete()
            return true
        case 36, 76: // enter
            let snapshot = engine.snapshot()
            let hasActiveCalculation = !draftInput.isEmpty || snapshot.pendingOperator != nil || pendingPercentTrace != nil
            if !hasActiveCalculation,
               let selected = tableView.selectedRow as Int?,
               isEditableOperandRow(index: selected)
            {
                beginEditingCommittedRow(selected)
                return true
            }
            handleResult(.enter)
            return true
        default:
            break
        }

        guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty else {
            return false
        }

        for ch in chars {
            if ch == "n" || ch == "N" {
                toggleNoteMode()
                continue
            }
            if ch == "=" {
                handleResult(.equals)
                continue
            }
            if ch == "%" {
                handlePercent()
                continue
            }
            if ch == "t" || ch == "T" {
                handleResult(.total)
                continue
            }
            if ch == "m" || ch == "M" {
                handleStoreTotalizerInFIFO()
                continue
            }
            if ch == "r" || ch == "R" {
                handleRecallFromFIFO()
                continue
            }
            if "+-*/xXdD".contains(ch) {
                handleOperator(ch)
                continue
            }
            if "0123456789,.".contains(ch) {
                handleDigitLike(ch)
                continue
            }
        }

        return true
    }

    private func handleStoreTotalizerInFIFO() {
        guard engine.enqueueTotalizerIfNeeded() != nil else { return }
        pendingPercentTrace = nil
        hasPendingLeadingNegativeSign = false
        updateStatusRow()
        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    private func handleRecallFromFIFO() {
        pendingPercentTrace = nil
        hasPendingLeadingNegativeSign = false
        guard let value = engine.recallNextEnqueuedTotalizer() else { return }
        let plain = NSDecimalNumber(decimal: value).stringValue
        draftInput = plain.replacingOccurrences(of: ".", with: ",")
        draftCursor = draftInput.count

        reloadTape(moveToDraft: true)
        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    @objc
    private func handleTableDoubleClick(_ sender: Any?) {
        let row = tableView.clickedRow
        guard row >= 0 else { return }
        beginEditingCommittedRow(row)
    }

    @objc
    private func commitEditingFromField(_ sender: NSTextField) {
        if isTextModeActive {
            commitAndExitTextMode()
            return
        }

        if isNoteModeActive {
            commitAndExitNoteMode()
            return
        }

        if isEditingModeActive {
            commitEditingValue()
        }
    }

    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard isNoteModeActive || isTextModeActive else { return false }

        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            if isTextModeActive {
                cancelAndExitTextMode()
            } else {
                cancelAndExitNoteMode()
            }
            return true
        }

        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if isTextModeActive {
                commitAndExitTextMode()
            } else {
                commitAndExitNoteMode()
            }
            return true
        }

        return false
    }

    public func controlTextDidChange(_ notification: Notification) {
        guard (isNoteModeActive || isTextModeActive),
              let field = notification.object as? NSTextField
        else {
            return
        }

        let row = tableView.row(for: field)
        let col = tableView.column(for: field)
        guard row >= 0, col >= 0,
              col < tableView.tableColumns.count
        else {
            return
        }

        let colId = tableView.tableColumns[col].identifier.rawValue
        let maxChars = isTextModeActive ? maxTextRowCharacters : maxInlineNoteCharacters
        let sanitized = isTextModeActive ? sanitizeTextRowInput(field.stringValue) : sanitizeNoteText(field.stringValue)

        if sanitized.count > maxChars {
            field.stringValue = String(sanitized.prefix(maxChars))
            NSSound.beep()
        } else if sanitized != field.stringValue {
            field.stringValue = sanitized
        }

        if isTextModeActive, colId == "calc", row >= 0, row < committedRows.count {
            committedRows[row].calc = field.stringValue
        } else if isTextModeActive, colId == "calc" {
            textDraftInput = field.stringValue
        } else if colId == "note", row >= 0, row < committedRows.count {
            committedRows[row].annotation = field.stringValue
        } else if colId == "note" {
            noteDraftInput = field.stringValue
        }

        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    private func handlePercent() {
        let snapshot = engine.snapshot()
        let originalValue = TapeFormatter.parseLocaleAwareDecimal(draftInput)
        guard let value = engine.applyPercent() else { return }
        hasPendingLeadingNegativeSign = false

        if let originalValue {
            committedRows.append(
                TapeRow(
                    special: "",
                    calc: TapeFormatter.formatDecimalForColumn(originalValue),
                    operand: "%",
                    kind: .committed
                )
            )
        }

        pendingPercentTrace = PercentTrace(
            convertedValue: value,
            pendingOperator: snapshot.pendingOperator,
            baseValue: snapshot.register
        )

        let plain = NSDecimalNumber(decimal: value).stringValue
        draftInput = plain.replacingOccurrences(of: ".", with: ",")
        draftCursor = draftInput.count

        reloadTape(moveToDraft: true)
        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    private func signedPercentContribution(_ trace: PercentTrace) -> Decimal {
        switch trace.pendingOperator {
        case .subtract:
            return -trace.convertedValue
        default:
            return trace.convertedValue
        }
    }

    private func handleDigitLike(_ ch: Character) {
        pendingPercentTrace = nil

        if hasPendingLeadingNegativeSign {
            _ = engine.inputCharacter("-")
            hasPendingLeadingNegativeSign = false
        }

        _ = engine.inputCharacter(ch)

        let index = min(max(0, draftCursor), draftInput.count)
        let strIndex = draftInput.index(draftInput.startIndex, offsetBy: index)
        draftInput.insert(ch, at: strIndex)
        draftCursor = index + 1

        reloadTape(moveToDraft: true)
        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    private func handleOperator(_ ch: Character) {
        pendingPercentTrace = nil
        let snapshot = engine.snapshot()

        if ch == "-", shouldStartLeadingNegativeDraft(snapshot: snapshot) {
            draftInput = "-"
            draftCursor = 1
            hasPendingLeadingNegativeSign = true

            reloadTape(moveToDraft: true)
            saveCurrentState(isVisible: window?.isVisible ?? false)
            return
        }

        if ch == "-", shouldInterpretMinusAsSignChange(snapshot: snapshot) {
            _ = engine.inputCharacter(ch)
            toggleDraftSign()

            reloadTape(moveToDraft: true)
            saveCurrentState(isVisible: window?.isVisible ?? false)
            return
        }

        let op: String
        if ch == "x" || ch == "X" {
            op = "*"
        } else if ch == "d" || ch == "D" {
            op = "D"
        } else {
            op = String(ch)
        }

        if let value = TapeFormatter.parseLocaleAwareDecimal(draftInput) {
            let visualValue = visualValueForOperatorCommit(from: value, snapshot: snapshot)
            committedRows.append(TapeRow(special: "", calc: TapeFormatter.formatDecimalForColumn(visualValue), operand: op, kind: .committed))
        } else if snapshot.pendingOperator == nil, let register = snapshot.register {
            // Keep the lhs explicit when continuing from a recalled total/register value.
            let continuationValue: Decimal
            if activeSettings.decimalMode == .fixed {
                continuationValue = TapeFormatter.normalizeForComputation(register, settings: activeSettings)
                engine.replaceCurrentInput(with: continuationValue)
            } else {
                continuationValue = register
            }
            committedRows.append(TapeRow(special: "", calc: TapeFormatter.formatDecimalForColumn(continuationValue), operand: op, kind: .committed))
        }

        _ = engine.inputCharacter(ch)
        draftInput = ""
        draftCursor = 0
        hasPendingLeadingNegativeSign = false

        reloadTape(moveToDraft: true)
        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    private func shouldStartLeadingNegativeDraft(snapshot: CalculatorSnapshot) -> Bool {
        guard draftInput.isEmpty else { return false }
        guard snapshot.pendingOperator == nil else { return false }
        return snapshot.register == nil
    }

    private func makeFullClearUndoSnapshot() -> FullClearUndoSnapshot {
        FullClearUndoSnapshot(
            committedRows: committedRows,
            draftInput: draftInput,
            draftCursor: draftCursor,
            hasPendingLeadingNegativeSign: hasPendingLeadingNegativeSign,
            isNoteModeActive: isNoteModeActive,
            noteEditingRow: noteEditingRow,
            noteOriginalText: noteOriginalText,
            noteDraftInput: noteDraftInput,
            isTextModeActive: isTextModeActive,
            textEditingRow: textEditingRow,
            textOriginalText: textOriginalText,
            textDraftInput: textDraftInput,
            pendingPercentTrace: pendingPercentTrace,
            selectedRow: tableView.selectedRow
        )
    }

    private func isMeaningfulFullClearUndoSnapshot(_ snapshot: FullClearUndoSnapshot) -> Bool {
        if !snapshot.draftInput.isEmpty || !snapshot.noteDraftInput.isEmpty || !snapshot.textDraftInput.isEmpty {
            return true
        }

        return snapshot.committedRows.contains { classifyRowRole($0) != "reset" }
    }

    private func restoreFromFullClearUndoSnapshot(_ snapshot: FullClearUndoSnapshot) {
        committedRows = snapshot.committedRows
        draftInput = snapshot.draftInput
        draftCursor = min(max(0, snapshot.draftCursor), draftInput.count)
        hasPendingLeadingNegativeSign = snapshot.hasPendingLeadingNegativeSign
        isNoteModeActive = snapshot.isNoteModeActive
        noteEditingRow = snapshot.noteEditingRow
        noteOriginalText = snapshot.noteOriginalText
        noteDraftInput = snapshot.noteDraftInput
        isTextModeActive = snapshot.isTextModeActive
        textEditingRow = snapshot.textEditingRow
        textOriginalText = snapshot.textOriginalText
        textDraftInput = snapshot.textDraftInput
        pendingPercentTrace = snapshot.pendingPercentTrace
        editingCommittedRow = nil
        isEditingModeActive = false

        recomputeCommittedRows(editedRowIndex: nil)
        replayDraftIntoEngineIfNeeded()

        reloadTape(moveToDraft: false)

        let rows = displayRows()
        guard !rows.isEmpty else { return }
        let target = min(max(0, snapshot.selectedRow), rows.count - 1)
        let previous = markerSelectedRow
        tableView.selectRowIndexes(IndexSet(integer: target), byExtendingSelection: false)
        markerSelectedRow = target
        refreshCursorMarker(previous: previous, current: markerSelectedRow)
        tableView.scrollRowToVisible(target)

        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    private func replayDraftIntoEngineIfNeeded() {
        guard !draftInput.isEmpty else { return }
        if hasPendingLeadingNegativeSign, draftInput == "-" {
            return
        }

        let normalized = draftInput.replacingOccurrences(of: ",", with: ".")
        for ch in normalized {
            _ = engine.inputCharacter(ch)
        }
        hasPendingLeadingNegativeSign = false
    }

    private func isDeletableCommittedRow(at index: Int) -> Bool {
        guard index >= 0, index < committedRows.count else { return false }

        let role = classifyRowRole(committedRows[index])
        if role == "reset" {
            // Keep at least one baseline reset row to avoid an empty invalid tape state.
            return committedRows.count > 1
        }

        return true
    }

    private func lastDeletableCommittedRowIndex() -> Int? {
        committedRows.indices.reversed().first { isDeletableCommittedRow(at: $0) }
    }

    private func deleteCommittedRow(at index: Int) {
        guard isDeletableCommittedRow(at: index) else {
            NSSound.beep()
            return
        }

        committedRows.remove(at: index)
        if committedRows.isEmpty {
            committedRows = [Self.resetBaselineRow]
        }

        pendingPercentTrace = nil
        hasPendingLeadingNegativeSign = false
        draftInput = ""
        draftCursor = 0

        recomputeCommittedRows(editedRowIndex: nil)
        reloadTape(moveToDraft: false)

        let rows = displayRows()
        guard !rows.isEmpty else { return }
        let draftIndex = draftRowIndex()
        let target = min(max(0, index), max(0, draftIndex))
        let previous = markerSelectedRow
        tableView.selectRowIndexes(IndexSet(integer: target), byExtendingSelection: false)
        markerSelectedRow = target
        refreshCursorMarker(previous: previous, current: markerSelectedRow)
        tableView.scrollRowToVisible(target)

        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    private func handleUndoAfterFullClear() {
        guard let snapshot = lastFullClearSnapshot else {
            NSSound.beep()
            return
        }

        lastFullClearSnapshot = nil
        restoreFromFullClearUndoSnapshot(snapshot)
    }

    private func visualValueForOperatorCommit(from value: Decimal, snapshot: CalculatorSnapshot) -> Decimal {
        let lastRole = committedRows.last.map(classifyRowRole)
        let shouldRenderAsLeadingNegative = snapshot.pendingOperator == .subtract
            && snapshot.register == 0
            && lastRole != "operator"

        guard shouldRenderAsLeadingNegative else { return value }
        return value < 0 ? value : -value
    }

    private func shouldInterpretMinusAsSignChange(snapshot: CalculatorSnapshot) -> Bool {
        guard snapshot.pendingOperator != nil else { return false }
        return draftInput.isEmpty || draftInput == "-"
    }

    private func toggleDraftSign() {
        if draftInput.hasPrefix("-") {
            draftInput.removeFirst()
            draftCursor = max(0, draftCursor - 1)
            return
        }

        draftInput.insert("-", at: draftInput.startIndex)
        draftCursor += 1
    }

    private func handleResult(_ key: ResultKey) {
        let preResultSnapshot = engine.snapshot()
        var pendingCommittedRows: [TapeRow] = []
        if let trace = pendingPercentTrace {
            // For multiplication-percent flow (e.g. 25 * 25 % =), the result row itself
            // is the standalone percentage value. Do not duplicate it as an intermediate "=" row.
            if trace.pendingOperator != .multiply {
                let signedValue = signedPercentContribution(trace)
                pendingCommittedRows.append(
                    TapeRow(
                        special: "",
                        calc: TapeFormatter.formatDecimalForColumn(signedValue),
                        operand: "=",
                        kind: .committed
                    )
                )
            }
        } else if let value = TapeFormatter.parseLocaleAwareDecimal(draftInput) {
            pendingCommittedRows.append(TapeRow(special: "", calc: TapeFormatter.formatDecimalForColumn(value), operand: "=", kind: .committed))
        }

        let result = engine.pressResult(key)
        if result.kind == .ignored {
            return
        }

        committedRows.append(contentsOf: pendingCommittedRows)

        if result.kind == .totalRecall {
            committedRows.append(makeTotalSeparatorRow())
        }

        let op: String
        let kind: TapeRowKind
        if result.kind == .totalRecall {
            op = "T"
            kind = .total
        } else {
            switch key {
            case .total:
                op = "T"
                kind = .total
            case .enter, .equals:
                op = preResultSnapshot.pendingOperator == .deltaPercent ? "%" : ""
                kind = .result
            }
        }

        let resultMarker = kind == .result ? TapeFormatter.resultIndicator(for: result.value, settings: activeSettings) : ""
        let resultOperand = resultMarker.isEmpty ? op : resultMarker
        committedRows.append(TapeRow(special: "", calc: TapeFormatter.formatDecimalForColumn(result.value), operand: resultOperand, kind: kind))

        if result.kind == .totalRecall {
            committedRows.append(makeTotalSeparatorRow())
        }

        draftInput = ""
        draftCursor = 0
        pendingPercentTrace = nil
        hasPendingLeadingNegativeSign = false

        reloadTape(moveToDraft: true)
        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    private func handleBackspace() {
        pendingPercentTrace = nil
        if draftInput.isEmpty {
            if tableView.selectedRow >= 0,
               tableView.selectedRow < committedRows.count,
               isDeletableCommittedRow(at: tableView.selectedRow)
            {
                deleteCommittedRow(at: tableView.selectedRow)
                return
            }

            if let fallbackIndex = lastDeletableCommittedRowIndex() {
                deleteCommittedRow(at: fallbackIndex)
                return
            }

            NSSound.beep()
            return
        }

        let index = min(max(0, draftCursor), draftInput.count)
        var removedCharacter: Character?
        if index > 0 {
            let removeIndex = draftInput.index(draftInput.startIndex, offsetBy: index - 1)
            removedCharacter = draftInput[removeIndex]
        }

        if !(hasPendingLeadingNegativeSign && removedCharacter == "-") {
            engine.backspace()
        }

        if index > 0 {
            let removeIndex = draftInput.index(draftInput.startIndex, offsetBy: index - 1)
            draftInput.remove(at: removeIndex)
            draftCursor = max(0, index - 1)
        }

        if draftInput.isEmpty {
            hasPendingLeadingNegativeSign = false
        }

        reloadTape(moveToDraft: true)
        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    private func handleDelete() {
        pendingPercentTrace = nil
        hasPendingLeadingNegativeSign = false
        let snapshotBeforeDelete = makeFullClearUndoSnapshot()
        let canCaptureSnapshot = isMeaningfulFullClearUndoSnapshot(snapshotBeforeDelete)
        isNoteModeActive = false
        noteEditingRow = nil
        noteOriginalText = ""
        noteDraftInput = ""
        isTextModeActive = false
        textEditingRow = nil
        textOriginalText = ""
        textDraftInput = ""
        let outcome = engine.pressDelete()
        if outcome == .fullClear {
            if canCaptureSnapshot {
                lastFullClearSnapshot = snapshotBeforeDelete
            }
            committedRows = [Self.resetBaselineRow]
            draftInput = ""
            draftCursor = 0
            applyMinimalBottomRightPlacement()
        } else {
            draftInput = ""
            draftCursor = 0
            committedRows.append(Self.resetBaselineRow)
        }

        reloadTape(moveToDraft: true)
        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    private func moveDraftCursor(_ delta: Int) {
        let selected = tableView.selectedRow
        guard selected == draftRowIndex() else { return }
        let next = min(max(0, draftCursor + delta), draftInput.count)
        draftCursor = next
    }

    private func moveSelectionVertically(_ delta: Int) {
        let rows = displayRows()
        guard !rows.isEmpty else { return }

        let current = tableView.selectedRow >= 0 ? tableView.selectedRow : draftRowIndex()
        var target = current

        if !isSelectableSelectionRow(index: target, rows: rows) {
            target = draftRowIndex()
        }

        while true {
            let candidate = target + delta
            if candidate < 0 || candidate >= rows.count {
                break
            }
            target = candidate
            if isSelectableSelectionRow(index: target, rows: rows) {
                break
            }
        }

        if !isSelectableSelectionRow(index: target, rows: rows) {
            target = current
        }

        tableView.selectRowIndexes(IndexSet(integer: target), byExtendingSelection: false)
        tableView.scrollRowToVisible(target)
        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    private func moveSelectionToBoundary(first: Bool) {
        let rows = displayRows()
        guard !rows.isEmpty else { return }

        if first {
            for i in rows.indices where isSelectableSelectionRow(index: i, rows: rows) {
                tableView.selectRowIndexes(IndexSet(integer: i), byExtendingSelection: false)
                tableView.scrollRowToVisible(i)
                break
            }
        } else {
            for i in rows.indices.reversed() where isSelectableSelectionRow(index: i, rows: rows) {
                tableView.selectRowIndexes(IndexSet(integer: i), byExtendingSelection: false)
                tableView.scrollRowToVisible(i)
                break
            }
        }

        saveCurrentState(isVisible: window?.isVisible ?? false)
    }

    private func moveSelectionByPage(_ direction: Int) {
        let rows = displayRows()
        guard !rows.isEmpty else { return }

        let current = tableView.selectedRow >= 0 ? tableView.selectedRow : draftRowIndex()
        let visibleRows = max(1, Int(floor(scrollView.contentView.bounds.height / max(1, tableView.rowHeight))) - 1)
        let rawTarget = current + (direction * visibleRows)
        var target = min(max(0, rawTarget), rows.count - 1)

        if isSelectableSelectionRow(index: target, rows: rows) {
            tableView.selectRowIndexes(IndexSet(integer: target), byExtendingSelection: false)
            tableView.scrollRowToVisible(target)
            saveCurrentState(isVisible: window?.isVisible ?? false)
            return
        }

        let step = direction < 0 ? -1 : 1
        while target >= 0 && target < rows.count {
            target += step
            if target < 0 || target >= rows.count {
                break
            }
            if isSelectableSelectionRow(index: target, rows: rows) {
                tableView.selectRowIndexes(IndexSet(integer: target), byExtendingSelection: false)
                tableView.scrollRowToVisible(target)
                saveCurrentState(isVisible: window?.isVisible ?? false)
                return
            }
        }
    }

    private func adjustWindowHeight(forDisplayedRows count: Int) {
        guard let window else { return }
        guard let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }

        let requiredRowsHeight = totalHeightForDisplayRows(max(count, 1))
        let requiredContentHeight = max(WindowPlacement.minimumSize.height, requiredRowsHeight + 20 + statusBarHeight)

        let currentFrame = window.frame
        let maxHeight = max(
            WindowPlacement.minimumSize.height,
            min(
                screen.visibleFrame.height * maxWindowHeightFraction,
                (screen.visibleFrame.maxY - currentFrame.minY) - WindowPlacement.margin
            )
        )
        let targetHeight = min(maxHeight, requiredContentHeight)

        if abs(currentFrame.height - targetHeight) < 0.5 {
            return
        }

        isAdjustingWindowHeight = true
        let newFrame = NSRect(
            x: currentFrame.maxX - currentFrame.width,
            y: currentFrame.minY,
            width: currentFrame.width,
            height: targetHeight
        )
        window.setFrame(newFrame, display: true, animate: false)
        isAdjustingWindowHeight = false
        updateCalcColumnWidth()
    }

    private func totalHeightForDisplayRows(_ count: Int) -> CGFloat {
        let rows = displayRows()
        guard !rows.isEmpty else { return defaultRowHeight }

        let upperBound = min(max(count, 1), rows.count)
        var total: CGFloat = 0
        for index in 0..<upperBound {
            total += rowHeight(for: rows[index])
        }
        return total
    }

    private func rowHeight(for row: TapeRow) -> CGFloat {
        row.kind == .separator ? separatorRowHeight : defaultRowHeight
    }

    public func numberOfRows(in tableView: NSTableView) -> Int {
        displayRows().count
    }

    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let rows = displayRows()
        guard row >= 0 && row < rows.count else { return defaultRowHeight }
        return rowHeight(for: rows[row])
    }

    public func tableViewSelectionDidChange(_ notification: Notification) {
        let previous = markerSelectedRow
        markerSelectedRow = tableView.selectedRow
        refreshCursorMarker(previous: previous, current: markerSelectedRow)
    }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let rows = displayRows()
        guard row >= 0 && row < rows.count else { return nil }
        let data = rows[row]
        let isCursorRow = markerSelectedRow == row && isSelectableSelectionRow(index: row, rows: rows)
        let baseRowColor: NSColor = data.kind == .separator
            ? NSColor(calibratedRed: 0.90, green: 0.86, blue: 0.78, alpha: 0.35)
            : .clear
        let highlightColor = isCursorRow ? markerHighlightColor(for: data, index: row) : baseRowColor

        let text: String
        let alignment: NSTextAlignment

        switch tableColumn?.identifier.rawValue {
        case "special":
            let cursorMark = isCursorRow ? ">" : ""
            if data.kind != .draft {
                let allRows = displayRows()
                let count = allRows[0...row].filter { $0.kind != .draft }.count
                text = cursorMark + String(count)
            } else {
                text = cursorMark
            }
            alignment = .left
        case "operand":
            text = data.kind == .separator ? "" : data.operand
            alignment = .right
        case "note":
            text = data.annotation
            alignment = .right
        default:
            text = data.kind == .separator ? separatorLineText(totalWidth: max(8, calcColumnChars - 2)) : data.calc
            alignment = (data.kind == .note || data.kind == .text) ? .left : .right
        }

        let id = NSUserInterfaceItemIdentifier("cell-\(tableColumn?.identifier.rawValue ?? "calc")")
        let cell: NSTableCellView

        if let reused = tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView,
           let label = reused.textField {
            label.stringValue = text
            label.alignment = alignment
            let colId = tableColumn?.identifier.rawValue
            let isEditingCalcCell = (colId == "calc") && (editingCommittedRow == row)
            let isEditingExistingNoteRow = isNoteModeActive
                && noteEditingRow == row
                && row >= 0
                && row < committedRows.count
            let isExistingNoteEditingCell = isEditingExistingNoteRow
                && colId == "note"
            let isDraftNoteEditingCell = isNoteModeActive && noteEditingRow == nil && row == draftRowIndex() && colId == "note"
            let isEditingExistingTextRow = isTextModeActive
                && textEditingRow == row
                && row >= 0
                && row < committedRows.count
            let isExistingTextEditingCell = isEditingExistingTextRow && colId == "calc"
            let isDraftTextEditingCell = isTextModeActive && textEditingRow == nil && row == draftRowIndex() && colId == "calc"
            let isEditingTextCell = isEditingCalcCell || isExistingNoteEditingCell || isDraftNoteEditingCell || isExistingTextEditingCell || isDraftTextEditingCell
            label.isEditable = isEditingTextCell
            label.isSelectable = isEditingTextCell
            label.isBordered = false
            label.focusRingType = .none
            label.delegate = self
            label.target = self
            label.action = #selector(commitEditingFromField(_:))
            if colId == "calc" {
                label.font = (data.kind == .separator || data.kind == .note || data.kind == .text) ? compactCellFont : calcCellFont
            } else if colId == "note" {
                label.font = compactCellFont
            } else if colId == "operand" {
                label.font = operandCellFont
            } else {
                label.font = compactCellFont
            }
            if tableColumn?.identifier.rawValue == "special" {
                label.textColor = .secondaryLabelColor
            } else if data.kind == .separator {
                label.textColor = NSColor(calibratedWhite: 0.22, alpha: 0.72)
            } else if tableColumn?.identifier.rawValue == "note" || data.kind == .note || data.kind == .text {
                label.textColor = NSColor(calibratedWhite: 0.22, alpha: 1.0)
            } else if colId == "calc", let parsed = TapeFormatter.parseLocaleAwareDecimal(data.calc), parsed < 0 {
                label.textColor = NSColor.systemRed
            } else {
                label.textColor = cellColor
            }
            if isEditingTextCell {
                label.drawsBackground = true
                label.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.96)
                label.textColor = .labelColor
            } else {
                label.drawsBackground = false
                label.backgroundColor = .clear
            }
            reused.wantsLayer = true
            reused.layer?.backgroundColor = highlightColor.cgColor
            cell = reused
        } else {
            let label = NSTextField(string: text)
            let colId = tableColumn?.identifier.rawValue
            let isEditingCalcCell = (colId == "calc") && (editingCommittedRow == row)
            let isEditingExistingNoteRow = isNoteModeActive
                && noteEditingRow == row
                && row >= 0
                && row < committedRows.count
            let isExistingNoteEditingCell = isEditingExistingNoteRow
                && colId == "note"
            let isDraftNoteEditingCell = isNoteModeActive && noteEditingRow == nil && row == draftRowIndex() && colId == "note"
            let isEditingExistingTextRow = isTextModeActive
                && textEditingRow == row
                && row >= 0
                && row < committedRows.count
            let isExistingTextEditingCell = isEditingExistingTextRow && colId == "calc"
            let isDraftTextEditingCell = isTextModeActive && textEditingRow == nil && row == draftRowIndex() && colId == "calc"
            let isEditingTextCell = isEditingCalcCell || isExistingNoteEditingCell || isDraftNoteEditingCell || isExistingTextEditingCell || isDraftTextEditingCell
            label.isEditable = isEditingTextCell
            label.isSelectable = isEditingTextCell
            label.isBordered = false
            label.focusRingType = .none
            label.delegate = self
            label.target = self
            label.action = #selector(commitEditingFromField(_:))
            if colId == "calc" {
                label.font = (data.kind == .separator || data.kind == .note || data.kind == .text) ? compactCellFont : calcCellFont
            } else if colId == "note" {
                label.font = compactCellFont
            } else if colId == "operand" {
                label.font = operandCellFont
            } else {
                label.font = compactCellFont
            }
            if colId == "special" {
                label.textColor = .secondaryLabelColor
            } else if data.kind == .separator {
                label.textColor = NSColor(calibratedWhite: 0.22, alpha: 0.72)
            } else if colId == "note" || data.kind == .note || data.kind == .text {
                label.textColor = NSColor(calibratedWhite: 0.22, alpha: 1.0)
            } else if colId == "calc", let parsed = TapeFormatter.parseLocaleAwareDecimal(data.calc), parsed < 0 {
                label.textColor = NSColor.systemRed
            } else {
                label.textColor = cellColor
            }
            if isEditingTextCell {
                label.drawsBackground = true
                label.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.96)
                label.textColor = .labelColor
            } else {
                label.drawsBackground = false
                label.backgroundColor = .clear
            }
            label.alignment = alignment
            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byClipping

            let created = NSTableCellView()
            created.identifier = id
            created.textField = label
            created.wantsLayer = true
            created.layer?.backgroundColor = highlightColor.cgColor
            created.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: created.leadingAnchor, constant: 6),
                label.trailingAnchor.constraint(equalTo: created.trailingAnchor, constant: -6),
                label.topAnchor.constraint(equalTo: created.topAnchor, constant: 1),
                label.bottomAnchor.constraint(equalTo: created.bottomAnchor, constant: -1)
            ])
            cell = created
        }

        return cell
    }

    private func scrollToBottom() {
        guard let documentView = scrollView.documentView else { return }
        let clipView = scrollView.contentView
        let visibleHeight = clipView.bounds.height
        let documentHeight = documentView.bounds.height
        let bottomY = max(0, documentHeight - visibleHeight)
        clipView.scroll(to: NSPoint(x: 0, y: bottomY))
        scrollView.reflectScrolledClipView(clipView)
    }
}
