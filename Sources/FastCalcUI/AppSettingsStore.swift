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

    public init(
        decimalMode: DecimalDisplayMode = .floating,
        fixedDecimalPlaces: Int = 2,
        roundingMode: DecimalRoundingMode = .nearest
    ) {
        self.decimalMode = decimalMode
        self.fixedDecimalPlaces = max(0, min(8, fixedDecimalPlaces))
        self.roundingMode = roundingMode
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

        return FastCalcFormatSettings(
            decimalMode: DecimalDisplayMode(rawValue: modeRaw) ?? .floating,
            fixedDecimalPlaces: fixedPlaces,
            roundingMode: DecimalRoundingMode(rawValue: roundingRaw) ?? .nearest
        )
    }

    public func saveFormattingSettings(_ settings: FastCalcFormatSettings) {
        defaults.set(settings.decimalMode.rawValue, forKey: "\(prefix).decimalMode")
        defaults.set(max(0, min(8, settings.fixedDecimalPlaces)), forKey: "\(prefix).fixedPlaces")
        defaults.set(settings.roundingMode.rawValue, forKey: "\(prefix).roundingMode")
        NotificationCenter.default.post(name: .fastCalcSettingsDidChange, object: nil)
    }
}
