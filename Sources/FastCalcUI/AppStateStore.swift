import AppKit

public struct FastCalcAppState: Equatable {
    public var rollText: String
    public var selectedLocation: Int
    public var scrollOffsetY: CGFloat
    public var windowFrame: NSRect?
    public var windowVisible: Bool

    public init(
        rollText: String = "",
        selectedLocation: Int = 0,
        scrollOffsetY: CGFloat = 0,
        windowFrame: NSRect? = nil,
        windowVisible: Bool = false
    ) {
        self.rollText = rollText
        self.selectedLocation = selectedLocation
        self.scrollOffsetY = scrollOffsetY
        self.windowFrame = windowFrame
        self.windowVisible = windowVisible
    }
}

public final class AppStateStore {
    private let defaults: UserDefaults
    private let prefix = "fastcalc.appstate"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> FastCalcAppState {
        let rollText = defaults.string(forKey: "\(prefix).rollText") ?? ""
        let selectedLocation = defaults.integer(forKey: "\(prefix).selectedLocation")
        let scrollOffsetY = defaults.double(forKey: "\(prefix).scrollOffsetY")
        let windowVisible = defaults.bool(forKey: "\(prefix).windowVisible")

        var frame: NSRect?
        if let frameString = defaults.string(forKey: "\(prefix).windowFrame") {
            frame = NSRectFromString(frameString)
        }

        return FastCalcAppState(
            rollText: rollText,
            selectedLocation: selectedLocation,
            scrollOffsetY: scrollOffsetY,
            windowFrame: frame,
            windowVisible: windowVisible
        )
    }

    public func save(_ state: FastCalcAppState) {
        defaults.set(state.rollText, forKey: "\(prefix).rollText")
        defaults.set(state.selectedLocation, forKey: "\(prefix).selectedLocation")
        defaults.set(state.scrollOffsetY, forKey: "\(prefix).scrollOffsetY")
        defaults.set(state.windowVisible, forKey: "\(prefix).windowVisible")

        if let windowFrame = state.windowFrame {
            defaults.set(NSStringFromRect(windowFrame), forKey: "\(prefix).windowFrame")
        } else {
            defaults.removeObject(forKey: "\(prefix).windowFrame")
        }
    }

    public func clearAll() {
        [
            "\(prefix).rollText",
            "\(prefix).selectedLocation",
            "\(prefix).scrollOffsetY",
            "\(prefix).windowVisible",
            "\(prefix).windowFrame"
        ].forEach(defaults.removeObject(forKey:))
    }
}
