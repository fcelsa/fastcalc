import AppKit

@MainActor
final class HelpPopoverController: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private let contentController = HelpPopoverContentController()
    private var localKeyMonitor: Any?

    override init() {
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = contentController
    }

    var isShown: Bool {
        popover.isShown
    }

    func show(title: String, lines: [String], relativeTo anchorRect: NSRect, of view: NSView) {
        contentController.configure(title: title, lines: lines)
        if popover.isShown {
            popover.performClose(nil)
        }
        installLocalKeyMonitor()
        popover.show(relativeTo: anchorRect, of: view, preferredEdge: .maxX)
    }

    func close() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        removeLocalKeyMonitor()
    }

    private func installLocalKeyMonitor() {
        removeLocalKeyMonitor()
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            let keyCode = Int(event.keyCode)
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
            if keyCode == 53 || chars == "h" {
                self.close()
                return nil
            }
            return event
        }
    }

    private func removeLocalKeyMonitor() {
        guard let localKeyMonitor else { return }
        NSEvent.removeMonitor(localKeyMonitor)
        self.localKeyMonitor = nil
    }
}

private final class HelpPopoverContentController: NSViewController {
    private let titleLabel = NSTextField(labelWithString: L10n.Help.title)
    private let textView = NSTextView(frame: .zero)

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 270))
        root.translatesAutoresizingMaskIntoConstraints = false
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(calibratedRed: 0.99, green: 0.98, blue: 0.94, alpha: 1.0).cgColor

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = NSColor(calibratedRed: 0.25, green: 0.24, blue: 0.20, alpha: 1.0)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView(frame: .zero)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textColor = NSColor(calibratedRed: 0.27, green: 0.25, blue: 0.19, alpha: 1.0)
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView

        root.addSubview(titleLabel)
        root.addSubview(scrollView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12)
        ])

        view = root
    }

    func configure(title: String, lines: [String]) {
        titleLabel.stringValue = title
        let visibleLines: [String]
        if lines.isEmpty {
            visibleLines = [L10n.Help.empty]
        } else {
            visibleLines = lines
        }
        textView.string = visibleLines.joined(separator: "\n")
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        textView.scrollToBeginningOfDocument(nil)
    }
}
