import Foundation

public enum DecimalDisplayMode: String {
    case floating
    case fixed
}

public enum DecimalRoundingMode: String {
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

public struct FastCalcFormatSettings: Equatable {
    public var decimalMode: DecimalDisplayMode
    public var fixedDecimalPlaces: Int
    public var roundingMode: DecimalRoundingMode
    public var showOnAllSpaces: Bool
    public var preferredScreenIndex: Int?
    public var floatingWindowEnabled: Bool

    public init(
        decimalMode: DecimalDisplayMode = .floating,
        fixedDecimalPlaces: Int = 2,
        roundingMode: DecimalRoundingMode = .nearest,
        showOnAllSpaces: Bool = false,
        preferredScreenIndex: Int? = nil,
        floatingWindowEnabled: Bool = true
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
    }
}

extension Notification.Name {
    static let fastCalcSettingsDidChange = Notification.Name("fastcalc.settings.changed")
}

public final class AppSettingsStore: @unchecked Sendable {
    public static let shared = AppSettingsStore()

    private let defaults: UserDefaults
    private let prefix = "fastcalc.settings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadFormattingSettings() -> FastCalcFormatSettings {
        let modeRaw = defaults.string(forKey: "\(prefix).decimalMode") ?? DecimalDisplayMode.floating.rawValue
        let roundingRaw = defaults.string(forKey: "\(prefix).roundingMode") ?? DecimalRoundingMode.nearest.rawValue
        let fixedPlaces = defaults.object(forKey: "\(prefix).fixedPlaces") as? Int ?? 2
        let showOnAllSpaces = defaults.object(forKey: "\(prefix).showOnAllSpaces") as? Bool ?? false
        let floatingWindowEnabled = defaults.object(forKey: "\(prefix).floatingWindowEnabled") as? Bool ?? true
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
            floatingWindowEnabled: floatingWindowEnabled
        )
    }

    public func saveFormattingSettings(_ settings: FastCalcFormatSettings) {
        defaults.set(settings.decimalMode.rawValue, forKey: "\(prefix).decimalMode")
        defaults.set(max(0, min(8, settings.fixedDecimalPlaces)), forKey: "\(prefix).fixedPlaces")
        defaults.set(settings.roundingMode.rawValue, forKey: "\(prefix).roundingMode")
        defaults.set(settings.showOnAllSpaces, forKey: "\(prefix).showOnAllSpaces")
        defaults.set(settings.floatingWindowEnabled, forKey: "\(prefix).floatingWindowEnabled")
        if let preferredScreenIndex = settings.preferredScreenIndex {
            defaults.set(max(0, preferredScreenIndex), forKey: "\(prefix).preferredScreenIndex")
        } else {
            defaults.removeObject(forKey: "\(prefix).preferredScreenIndex")
        }
        NotificationCenter.default.post(name: .fastCalcSettingsDidChange, object: nil)
    }
}
