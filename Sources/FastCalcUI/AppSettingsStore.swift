import Carbon.HIToolbox
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

public struct UserDefinedFunction: Equatable, Codable, Sendable {
    public var id: String
    public var label: String
    public var note: String
    public var expression: String
    public var resultOnly: Bool

    public init(id: String = UUID().uuidString, label: String, note: String = "", expression: String, resultOnly: Bool = true) {
        self.id = id
        self.label = label
        self.note = String(note.prefix(12))
        self.expression = expression
        self.resultOnly = resultOnly
    }
}

public struct GlobalHotKey: Equatable, Sendable {
    public var keyCode: UInt32
    public var carbonModifiers: UInt32

    public init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers & Self.supportedModifierMask
    }

    public static let f16 = GlobalHotKey(keyCode: UInt32(kVK_F16), carbonModifiers: 0)

    public var hasModifiers: Bool {
        (carbonModifiers & Self.supportedModifierMask) != 0
    }

    public var isFunctionKey: Bool {
        Self.functionKeyDisplayNames[keyCode] != nil
    }

    public var displayName: String {
        let key = Self.keyDisplayName(for: keyCode)
        let modifiers = Self.modifierDisplayNames(for: carbonModifiers)
        guard !modifiers.isEmpty else { return key }
        return modifiers.joined(separator: "+") + "+" + key
    }

    private static let supportedModifierMask: UInt32 = UInt32(cmdKey | optionKey | controlKey | shiftKey)

    private static let functionKeyDisplayNames: [UInt32: String] = [
        UInt32(kVK_F1): "F1",
        UInt32(kVK_F2): "F2",
        UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4",
        UInt32(kVK_F5): "F5",
        UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7",
        UInt32(kVK_F8): "F8",
        UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10",
        UInt32(kVK_F11): "F11",
        UInt32(kVK_F12): "F12",
        UInt32(kVK_F13): "F13",
        UInt32(kVK_F14): "F14",
        UInt32(kVK_F15): "F15",
        UInt32(kVK_F16): "F16",
        UInt32(kVK_F17): "F17",
        UInt32(kVK_F18): "F18",
        UInt32(kVK_F19): "F19",
        UInt32(kVK_F20): "F20"
    ]

    private static let keyDisplayNames: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C", UInt32(kVK_ANSI_D): "D",
        UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F", UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H",
        UInt32(kVK_ANSI_I): "I", UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O", UInt32(kVK_ANSI_P): "P",
        UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R", UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T",
        UInt32(kVK_ANSI_U): "U", UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2", UInt32(kVK_ANSI_3): "3",
        UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5", UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7",
        UInt32(kVK_ANSI_8): "8", UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_ANSI_Minus): "-", UInt32(kVK_ANSI_Equal): "=", UInt32(kVK_ANSI_LeftBracket): "[", UInt32(kVK_ANSI_RightBracket): "]",
        UInt32(kVK_ANSI_Semicolon): ";", UInt32(kVK_ANSI_Quote): "'", UInt32(kVK_ANSI_Comma): ",", UInt32(kVK_ANSI_Period): ".",
        UInt32(kVK_ANSI_Slash): "/", UInt32(kVK_ANSI_Backslash): "\\", UInt32(kVK_ANSI_Grave): "`",
        UInt32(kVK_Space): "Space", UInt32(kVK_Return): "Return", UInt32(kVK_Escape): "Esc",
        UInt32(kVK_Delete): "Delete", UInt32(kVK_ForwardDelete): "ForwardDelete", UInt32(kVK_Tab): "Tab"
    ]

    private static func modifierDisplayNames(for carbonModifiers: UInt32) -> [String] {
        var result: [String] = []
        if (carbonModifiers & UInt32(controlKey)) != 0 { result.append("Ctrl") }
        if (carbonModifiers & UInt32(optionKey)) != 0 { result.append("Opt") }
        if (carbonModifiers & UInt32(shiftKey)) != 0 { result.append("Shift") }
        if (carbonModifiers & UInt32(cmdKey)) != 0 { result.append("Cmd") }
        return result
    }

    private static func keyDisplayName(for keyCode: UInt32) -> String {
        if let function = functionKeyDisplayNames[keyCode] {
            return function
        }
        if let key = keyDisplayNames[keyCode] {
            return key
        }
        if let localizedKeyName = localizedKeyDisplayName(for: keyCode) {
            return localizedKeyName
        }
        return "KeyCode \(keyCode)"
    }

    private static func localizedKeyDisplayName(for keyCode: UInt32) -> String? {
        guard let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else {
            return nil
        }
        guard let rawLayoutData = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let layoutData = unsafeBitCast(rawLayoutData, to: CFData.self)
        guard let layoutBytes = CFDataGetBytePtr(layoutData) else {
            return nil
        }

        let keyboardLayout = UnsafePointer<UCKeyboardLayout>(OpaquePointer(layoutBytes))
        let keyboardType = UInt32(LMGetKbdType())
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)

        let status = UCKeyTranslate(
            keyboardLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            keyboardType,
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            characters.count,
            &length,
            &characters
        )

        guard status == noErr, length > 0 else {
            return nil
        }

        return String(utf16CodeUnits: characters, count: length).uppercased()
    }
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
    public var globalHotKey: GlobalHotKey
    public var menuBarIconEnabled: Bool
    public var dockIconEnabled: Bool
    public var activeWindowOpacity: Double
    public var inactiveWindowOpacity: Double
    public var userFunctions: [UserDefinedFunction]

    public init(
        decimalMode: DecimalDisplayMode = .floating,
        fixedDecimalPlaces: Int = 4,
        roundingMode: DecimalRoundingMode = .nearest,
        showOnAllSpaces: Bool = false,
        preferredScreenIndex: Int? = nil,
        floatingWindowEnabled: Bool = false,
        alwaysOnTop: Bool = true,
        startupMode: WindowStartupMode = .hidden,
        globalHotKey: GlobalHotKey = .f16,
        menuBarIconEnabled: Bool = true,
        dockIconEnabled: Bool = false,
        activeWindowOpacity: Double = 1.0,
        inactiveWindowOpacity: Double = 0.5,
        userFunctions: [UserDefinedFunction] = []
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
        self.globalHotKey = globalHotKey
        self.menuBarIconEnabled = menuBarIconEnabled
        self.dockIconEnabled = dockIconEnabled
        self.activeWindowOpacity = max(0.1, min(1.0, activeWindowOpacity))
        self.inactiveWindowOpacity = max(0.1, min(1.0, inactiveWindowOpacity))
        self.userFunctions = userFunctions
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
        globalHotKey: .f16,
        menuBarIconEnabled: true,
        dockIconEnabled: false,
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
        let hotKeyCodeRaw = defaults.object(forKey: "\(prefix).globalHotKey.keyCode") as? Int
        let hotKeyModifiersRaw = defaults.object(forKey: "\(prefix).globalHotKey.modifiers") as? Int
        let menuBarIconEnabled = defaults.object(forKey: "\(prefix).menuBarIconEnabled") as? Bool ?? defaultsSettings.menuBarIconEnabled
        let dockIconEnabled = defaults.object(forKey: "\(prefix).dockIconEnabled") as? Bool ?? defaultsSettings.dockIconEnabled
        let activeWindowOpacity = defaults.object(forKey: "\(prefix).activeWindowOpacity") as? Double ?? defaultsSettings.activeWindowOpacity
        let inactiveWindowOpacity = defaults.object(forKey: "\(prefix).inactiveWindowOpacity") as? Double ?? defaultsSettings.inactiveWindowOpacity
        let userFunctions: [UserDefinedFunction]
        if let data = defaults.data(forKey: "\(prefix).userFunctions"),
           let decoded = try? JSONDecoder().decode([UserDefinedFunction].self, from: data)
        {
            userFunctions = decoded
        } else {
            userFunctions = defaultsSettings.userFunctions
        }
        let preferredScreenIndex: Int?
        if let storedIndex = defaults.object(forKey: "\(prefix).preferredScreenIndex") as? Int, storedIndex >= 0 {
            preferredScreenIndex = storedIndex
        } else {
            preferredScreenIndex = nil
        }

        let loadedHotKey: GlobalHotKey
        if let hotKeyCodeRaw {
            loadedHotKey = GlobalHotKey(
                keyCode: UInt32(max(0, hotKeyCodeRaw)),
                carbonModifiers: UInt32(max(0, hotKeyModifiersRaw ?? 0))
            )
        } else if let legacyRaw = defaults.string(forKey: "\(prefix).globalHotKey") {
            switch legacyRaw {
            case "f13": loadedHotKey = GlobalHotKey(keyCode: UInt32(kVK_F13), carbonModifiers: 0)
            case "f14": loadedHotKey = GlobalHotKey(keyCode: UInt32(kVK_F14), carbonModifiers: 0)
            case "f15": loadedHotKey = GlobalHotKey(keyCode: UInt32(kVK_F15), carbonModifiers: 0)
            case "f16": loadedHotKey = GlobalHotKey(keyCode: UInt32(kVK_F16), carbonModifiers: 0)
            case "f17": loadedHotKey = GlobalHotKey(keyCode: UInt32(kVK_F17), carbonModifiers: 0)
            case "f18": loadedHotKey = GlobalHotKey(keyCode: UInt32(kVK_F18), carbonModifiers: 0)
            case "f19": loadedHotKey = GlobalHotKey(keyCode: UInt32(kVK_F19), carbonModifiers: 0)
            default: loadedHotKey = defaultsSettings.globalHotKey
            }
        } else {
            loadedHotKey = defaultsSettings.globalHotKey
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
            globalHotKey: loadedHotKey,
            menuBarIconEnabled: menuBarIconEnabled,
            dockIconEnabled: dockIconEnabled,
            activeWindowOpacity: activeWindowOpacity,
            inactiveWindowOpacity: inactiveWindowOpacity,
            userFunctions: userFunctions
        )
    }

    public func saveFormattingSettings(_ settings: FastCalcFormatSettings) {
        saveFormattingSettings(settings, postNotification: true)
    }

    public func saveUserFunctions(_ functions: [UserDefinedFunction]) {
        if let encodedFunctions = try? JSONEncoder().encode(functions) {
            defaults.set(encodedFunctions, forKey: "\(prefix).userFunctions")
        }
    }

    private func saveFormattingSettings(_ settings: FastCalcFormatSettings, postNotification: Bool) {
        defaults.set(settings.decimalMode.rawValue, forKey: "\(prefix).decimalMode")
        defaults.set(max(0, min(8, settings.fixedDecimalPlaces)), forKey: "\(prefix).fixedPlaces")
        defaults.set(settings.roundingMode.rawValue, forKey: "\(prefix).roundingMode")
        defaults.set(settings.showOnAllSpaces, forKey: "\(prefix).showOnAllSpaces")
        defaults.set(settings.floatingWindowEnabled, forKey: "\(prefix).floatingWindowEnabled")
        defaults.set(settings.alwaysOnTop, forKey: "\(prefix).alwaysOnTop")
        defaults.set(settings.startupMode.rawValue, forKey: "\(prefix).startupMode")
        defaults.set(Int(settings.globalHotKey.keyCode), forKey: "\(prefix).globalHotKey.keyCode")
        defaults.set(Int(settings.globalHotKey.carbonModifiers), forKey: "\(prefix).globalHotKey.modifiers")
        defaults.removeObject(forKey: "\(prefix).globalHotKey")
        defaults.set(settings.menuBarIconEnabled, forKey: "\(prefix).menuBarIconEnabled")
        defaults.set(settings.dockIconEnabled, forKey: "\(prefix).dockIconEnabled")
        defaults.set(max(0.1, min(1.0, settings.activeWindowOpacity)), forKey: "\(prefix).activeWindowOpacity")
        defaults.set(max(0.1, min(1.0, settings.inactiveWindowOpacity)), forKey: "\(prefix).inactiveWindowOpacity")
        if let encodedFunctions = try? JSONEncoder().encode(settings.userFunctions) {
            defaults.set(encodedFunctions, forKey: "\(prefix).userFunctions")
        }
        if let preferredScreenIndex = settings.preferredScreenIndex {
            defaults.set(max(0, preferredScreenIndex), forKey: "\(prefix).preferredScreenIndex")
        } else {
            defaults.removeObject(forKey: "\(prefix).preferredScreenIndex")
        }
        if postNotification {
            NotificationCenter.default.post(name: .fastCalcSettingsDidChange, object: nil)
        }
    }

    public func resetFormattingSettingsToDefaults() {
        saveFormattingSettings(AppSettingsStore.defaultFormattingSettings)
    }
}
