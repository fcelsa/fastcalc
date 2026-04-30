import AppKit

@MainActor
public final class AboutWindowController: NSWindowController {
    private let appIconView = NSImageView(frame: .zero)
    private let appNameLabel = NSTextField(labelWithString: "")
    private let descriptionLabel = NSTextField(labelWithString: "")
    private let versionLabel = NSTextField(labelWithString: "")

    public init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Informazioni su FastCalc"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        setupView()
        refreshContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func present() {
        refreshContent()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupView() {
        guard let contentView = window?.contentView else { return }

        appIconView.imageAlignment = .alignCenter
        appIconView.imageScaling = .scaleProportionallyUpOrDown
        appIconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            appIconView.widthAnchor.constraint(equalToConstant: 72),
            appIconView.heightAnchor.constraint(equalToConstant: 72)
        ])

        appNameLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        appNameLabel.alignment = .center

        descriptionLabel.font = .systemFont(ofSize: 13)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.alignment = .center

        versionLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        versionLabel.alignment = .center

        let stack = NSStackView(views: [appIconView, appNameLabel, descriptionLabel, versionLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 28, left: 20, bottom: 24, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func refreshContent() {
        let bundle = Bundle.main
        let appName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? ProcessInfo.processInfo.processName

        let shortVersion = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "Debug session"
        let buildVersion = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "swift run"

        appIconView.image = resolvedAppIcon()
        appNameLabel.stringValue = appName
        descriptionLabel.stringValue = "Calcolatrice veloce con tape e stampa PDF"
        versionLabel.stringValue = "Versione \(shortVersion) (build \(buildVersion))"
    }

    private func resolvedAppIcon() -> NSImage {
        if let appIcon = NSApp.applicationIconImage,
           appIcon.size.width > 0,
           appIcon.size.height > 0
        {
            return appIcon
        }

        return NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }
}
