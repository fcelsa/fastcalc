import AppKit

private enum MultiFunctionPopoverTheme {
    static let contentBackground = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedRed: 0.21, green: 0.20, blue: 0.18, alpha: 1.0)
        }
        // Slightly lighter than FastCalc main window paper tone.
        return NSColor(calibratedRed: 0.99, green: 0.98, blue: 0.94, alpha: 1.0)
    }

    static let titleText = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedWhite: 0.88, alpha: 1.0)
        }
        return NSColor(calibratedRed: 0.25, green: 0.24, blue: 0.20, alpha: 1.0)
    }

    static let selectionFill = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedRed: 0.44, green: 0.39, blue: 0.25, alpha: 0.36)
        }
        return NSColor(calibratedRed: 0.78, green: 0.70, blue: 0.42, alpha: 0.34)
    }

    static let buttonFill = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedRed: 0.25, green: 0.24, blue: 0.22, alpha: 0.92)
        }
        return NSColor(calibratedRed: 0.96, green: 0.94, blue: 0.88, alpha: 0.95)
    }

    static let buttonBorder = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedRed: 0.40, green: 0.37, blue: 0.29, alpha: 0.70)
        }
        return NSColor(calibratedRed: 0.77, green: 0.70, blue: 0.52, alpha: 0.90)
    }

    static let selectionBorder = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedRed: 0.84, green: 0.74, blue: 0.44, alpha: 0.98)
        }
        return NSColor(calibratedRed: 0.63, green: 0.51, blue: 0.18, alpha: 0.98)
    }

    static let buttonText = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedWhite: 0.88, alpha: 1.0)
        }
        return NSColor(calibratedRed: 0.27, green: 0.25, blue: 0.19, alpha: 1.0)
    }

    static let selectionText = NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(calibratedRed: 0.98, green: 0.92, blue: 0.72, alpha: 1.0)
        }
        return NSColor(calibratedRed: 0.42, green: 0.31, blue: 0.07, alpha: 1.0)
    }
}

@MainActor
final class MultiFunctionPopoverController: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private let contentController = MultiFunctionPopoverContentController()
    private var localKeyMonitor: Any?

    var onSelectAction: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    override init() {
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = contentController

        contentController.onSelectAction = { [weak self] action in
            self?.onSelectAction?(action)
            self?.close()
        }
    }

    var isShown: Bool {
        popover.isShown
    }

    func show(actionSet: MultiFunctionActionSet, relativeTo anchorRect: NSRect, of view: NSView) {
        contentController.configure(with: actionSet)
        if popover.isShown {
            popover.performClose(nil)
        }
        popover.show(relativeTo: anchorRect, of: view, preferredEdge: .minY)
        installLocalKeyMonitorIfNeeded()
    }

    @discardableResult
    func handleKeyboardEvent(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case 53: // escape
            close()
            return true
        case 126: // up
            contentController.moveSelection(delta: -1)
            return true
        case 125: // down
            contentController.moveSelection(delta: 1)
            return true
        case 36, 76: // enter
            if let action = contentController.selectedActionID() {
                onSelectAction?(action)
                close()
            }
            return true
        default:
            break
        }

        guard let chars = event.charactersIgnoringModifiers?.lowercased(), !chars.isEmpty else {
            return false
        }

        for ch in chars {
            if let value = ch.wholeNumberValue,
               value >= 1,
               let action = contentController.actionID(atShortcutIndex: value - 1)
            {
                onSelectAction?(action)
                close()
                return true
            }
        }

        return false
    }

    func close() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        removeLocalKeyMonitor()
        onDismiss?()
    }

    private func installLocalKeyMonitorIfNeeded() {
        guard localKeyMonitor == nil else { return }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard self.popover.isShown else { return event }

            _ = self.handleKeyboardEvent(event)
            // While the popover is open, swallow all keyDown events to avoid beeps
            // from responders that do not handle the key.
            return nil
        }
    }

    private func removeLocalKeyMonitor() {
        guard let localKeyMonitor else { return }
        NSEvent.removeMonitor(localKeyMonitor)
        self.localKeyMonitor = nil
    }
}

private final class MultiFunctionPopoverContentController: NSViewController {
    var onSelectAction: ((String) -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let stackView = NSStackView()
    private var actionButtons: [NSButton] = []
    private var currentActionSet: MultiFunctionActionSet?
    private var selectedIndex = 0

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 288, height: 168))
        root.translatesAutoresizingMaskIntoConstraints = false
        root.wantsLayer = true
        root.layer?.backgroundColor = MultiFunctionPopoverTheme.contentBackground.cgColor

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = MultiFunctionPopoverTheme.titleText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        stackView.orientation = .vertical
        stackView.spacing = 10
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(titleLabel)
        root.addSubview(stackView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -14),

            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            stackView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            stackView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14)
        ])

        view = root
    }

    func configure(with actionSet: MultiFunctionActionSet) {
        currentActionSet = actionSet
        titleLabel.stringValue = actionSet.title
        rebuildActionButtons(for: actionSet)
        selectedIndex = 0
        updateSelectionAppearance()
    }

    func moveSelection(delta: Int) {
        guard !actionButtons.isEmpty else { return }
        selectedIndex = max(0, min(actionButtons.count - 1, selectedIndex + delta))
        updateSelectionAppearance()
    }

    func selectedActionID() -> String? {
        guard let actionSet = currentActionSet,
              selectedIndex >= 0,
              selectedIndex < actionSet.actions.count
        else {
            return nil
        }
        return actionSet.actions[selectedIndex].id
    }

    func actionID(atShortcutIndex index: Int) -> String? {
        guard let actionSet = currentActionSet,
              index >= 0,
              index < actionSet.actions.count
        else {
            return nil
        }
        return actionSet.actions[index].id
    }

    private func rebuildActionButtons(for actionSet: MultiFunctionActionSet) {
        for arranged in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(arranged)
            arranged.removeFromSuperview()
        }
        actionButtons = []

        for (index, action) in actionSet.actions.enumerated() {
            let button = NSButton(title: "  \(index + 1). \(action.title)   \(action.detail)  ", target: self, action: #selector(actionButtonPressed(_:)))
            button.bezelStyle = .rounded
            button.setButtonType(.momentaryPushIn)
            button.isBordered = false
            button.alignment = .left
            button.font = .systemFont(ofSize: 14, weight: .regular)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.identifier = NSUserInterfaceItemIdentifier(action.id)
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 248).isActive = true
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
            button.wantsLayer = true
            button.layer?.cornerRadius = 6
            button.layer?.masksToBounds = true
            button.focusRingType = .none
            stackView.addArrangedSubview(button)
            actionButtons.append(button)
        }
    }

    private func updateSelectionAppearance() {
        for (index, button) in actionButtons.enumerated() {
            let isSelected = index == selectedIndex
            button.layer?.backgroundColor = isSelected ? MultiFunctionPopoverTheme.selectionFill.cgColor : MultiFunctionPopoverTheme.buttonFill.cgColor
            button.layer?.borderWidth = isSelected ? 0.85 : 0.6
            button.layer?.borderColor = isSelected ? MultiFunctionPopoverTheme.selectionBorder.cgColor : MultiFunctionPopoverTheme.buttonBorder.cgColor
            button.contentTintColor = isSelected ? MultiFunctionPopoverTheme.selectionText : MultiFunctionPopoverTheme.buttonText
        }
    }

    @objc
    private func actionButtonPressed(_ sender: NSButton) {
        guard let action = sender.identifier?.rawValue
        else {
            return
        }

        if let idx = actionButtons.firstIndex(of: sender) {
            selectedIndex = idx
            updateSelectionAppearance()
        }

        onSelectAction?(action)
    }
}
