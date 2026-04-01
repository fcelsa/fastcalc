import Foundation

public enum DecimalDisplayMode: String, Sendable {
    case floating
    case fixed
}

public enum DecimalRoundingMode: String, Sendable {
    case down
    case nearest
    case up

    var decimalMode: NSDecimalNumber.RoundingMode {
        switch self {
        case .down:
            return .down
        case .nearest:
            return .plain
        case .up:
            return .up
        }
    }
}

public enum WindowStartupMode: String, Sendable {
    case `default`
    case hidden
    case visible
}

public struct FastCalcFormatSettings: Equatable, Sendable {
    public var decimalMode: DecimalDisplayMode
    public var fixedDecimalPlaces: Int
    public var roundingMode: DecimalRoundingMode
    public var showOnAllSpaces: Bool
    public var preferredScreenIndex: Int?
    public var floatingWindowEnabled: Bool
    public var alwaysOnTop: Bool
    public var startupMode: WindowStartupMode
    public var activeWindowOpacity: Double
    public var inactiveWindowOpacity: Double

    public init(
        decimalMode: DecimalDisplayMode = .floating,
        fixedDecimalPlaces: Int = 4,
        roundingMode: DecimalRoundingMode = .nearest,
        showOnAllSpaces: Bool = false,
        preferredScreenIndex: Int? = nil,
        floatingWindowEnabled: Bool = false,
        alwaysOnTop: Bool = true,
        startupMode: WindowStartupMode = .hidden,
        activeWindowOpacity: Double = 1.0,
        inactiveWindowOpacity: Double = 0.5
    ) {
        self.decimalMode = decimalMode
        self.fixedDecimalPlaces = max(0, min(8, fixedDecimalPlaces))
        self.roundingMode = roundingMode
        self.showOnAllSpaces = showOnAllSpaces
        if let preferredScreenIndex {
            self.preferredScreenIndex = max(0, preferredScreenIndex)
        } else {
            self.preferredScreenIndex = nil
        }
        self.floatingWindowEnabled = floatingWindowEnabled
        self.alwaysOnTop = alwaysOnTop
        self.startupMode = startupMode
        self.activeWindowOpacity = max(0.1, min(1.0, activeWindowOpacity))
        self.inactiveWindowOpacity = max(0.1, min(1.0, inactiveWindowOpacity))
    }
}

extension Notification.Name {
    static let fastCalcSettingsDidChange = Notification.Name("fastcalc.settings.changed")
}

public final class AppSettingsStore: @unchecked Sendable {
    public static let shared = AppSettingsStore()
    public static let defaultFormattingSettings = FastCalcFormatSettings(
        decimalMode: .floating,
        fixedDecimalPlaces: 4,
        roundingMode: .nearest,
        showOnAllSpaces: false,
        preferredScreenIndex: nil,
        floatingWindowEnabled: false,
        alwaysOnTop: true,
        startupMode: .hidden,
        activeWindowOpacity: 1.0,
        inactiveWindowOpacity: 0.5
    )

    private let defaults: UserDefaults
    private let prefix = "fastcalc.settings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadFormattingSettings() -> FastCalcFormatSettings {
        let defaultsSettings = AppSettingsStore.defaultFormattingSettings
        let modeRaw = defaults.string(forKey: "\(prefix).decimalMode") ?? defaultsSettings.decimalMode.rawValue
        let roundingRaw = defaults.string(forKey: "\(prefix).roundingMode") ?? defaultsSettings.roundingMode.rawValue
        let fixedPlaces = defaults.object(forKey: "\(prefix).fixedPlaces") as? Int ?? defaultsSettings.fixedDecimalPlaces
        let showOnAllSpaces = defaults.object(forKey: "\(prefix).showOnAllSpaces") as? Bool ?? defaultsSettings.showOnAllSpaces
        let floatingWindowEnabled = defaults.object(forKey: "\(prefix).floatingWindowEnabled") as? Bool ?? defaultsSettings.floatingWindowEnabled
        let alwaysOnTop = defaults.object(forKey: "\(prefix).alwaysOnTop") as? Bool ?? defaultsSettings.alwaysOnTop
        let startupModeRaw = defaults.string(forKey: "\(prefix).startupMode") ?? defaultsSettings.startupMode.rawValue
        let activeWindowOpacity = defaults.object(forKey: "\(prefix).activeWindowOpacity") as? Double ?? defaultsSettings.activeWindowOpacity
        let inactiveWindowOpacity = defaults.object(forKey: "\(prefix).inactiveWindowOpacity") as? Double ?? defaultsSettings.inactiveWindowOpacity
        let preferredScreenIndex: Int?
        if let storedIndex = defaults.object(forKey: "\(prefix).preferredScreenIndex") as? Int, storedIndex >= 0 {
            preferredScreenIndex = storedIndex
        } else {
            preferredScreenIndex = nil
        }

        return FastCalcFormatSettings(
            decimalMode: DecimalDisplayMode(rawValue: modeRaw) ?? .floating,
            fixedDecimalPlaces: fixedPlaces,
            roundingMode: DecimalRoundingMode(rawValue: roundingRaw) ?? .nearest,
            showOnAllSpaces: showOnAllSpaces,
            preferredScreenIndex: preferredScreenIndex,
            floatingWindowEnabled: floatingWindowEnabled,
            alwaysOnTop: alwaysOnTop,
            startupMode: WindowStartupMode(rawValue: startupModeRaw) ?? .default,
            activeWindowOpacity: activeWindowOpacity,
            inactiveWindowOpacity: inactiveWindowOpacity
        )
    }

    public func saveFormattingSettings(_ settings: FastCalcFormatSettings) {
        defaults.set(settings.decimalMode.rawValue, forKey: "\(prefix).decimalMode")
        defaults.set(max(0, min(8, settings.fixedDecimalPlaces)), forKey: "\(prefix).fixedPlaces")
        defaults.set(settings.roundingMode.rawValue, forKey: "\(prefix).roundingMode")
        defaults.set(settings.showOnAllSpaces, forKey: "\(prefix).showOnAllSpaces")
        defaults.set(settings.floatingWindowEnabled, forKey: "\(prefix).floatingWindowEnabled")
        defaults.set(settings.alwaysOnTop, forKey: "\(prefix).alwaysOnTop")
        defaults.set(settings.startupMode.rawValue, forKey: "\(prefix).startupMode")
        defaults.set(max(0.1, min(1.0, settings.activeWindowOpacity)), forKey: "\(prefix).activeWindowOpacity")
        defaults.set(max(0.1, min(1.0, settings.inactiveWindowOpacity)), forKey: "\(prefix).inactiveWindowOpacity")
        if let preferredScreenIndex = settings.preferredScreenIndex {
            defaults.set(max(0, preferredScreenIndex), forKey: "\(prefix).preferredScreenIndex")
        } else {
            defaults.removeObject(forKey: "\(prefix).preferredScreenIndex")
        }
        NotificationCenter.default.post(name: .fastCalcSettingsDidChange, object: nil)
    }

    public func resetFormattingSettingsToDefaults() {
        saveFormattingSettings(AppSettingsStore.defaultFormattingSettings)
    }
}
