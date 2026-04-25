//
// This file contains number and tape formatting helpers.
// It keeps calculator column formatting deterministic.
//

import Foundation

enum TapeFormatter {
    private static let periodicTruncationPlaces = 8

    static func resultIndicator(for value: Decimal, settings: FastCalcFormatSettings) -> String {
        switch settings.decimalMode {
        case .floating:
            let truncated = truncateTowardZero(value, places: periodicTruncationPlaces)
            return truncated == value ? "" : "~"
        case .fixed:
            let truncated = truncateTowardZero(value, places: periodicTruncationPlaces)
            let rounded = normalizeForComputation(value, settings: settings)
            guard rounded != truncated else { return "" }

            switch settings.roundingMode {
            case .up:
                return "↑"
            case .down:
                return "↓"
            case .nearest:
                return rounded >= truncated ? "↑" : "↓"
            }
        }
    }

    static func formatDecimalForColumn(_ value: Decimal) -> String {
        let settings = AppSettingsStore.shared.loadFormattingSettings()
        return formatDecimalForColumn(value, settings: settings)
    }

    static func formatDecimalForColumn(_ value: Decimal, settings: FastCalcFormatSettings) -> String {
        var working = value
        if working < 0 {
            working *= -1
        }

        let intDigits = integerDigits(in: working)
        if intDigits > 14 {
            return "OVERFLOW"
        }

        let maxDecimals: Int
        switch settings.decimalMode {
        case .floating:
            // Floating mode keeps as many decimals as available, capped to 8.
            maxDecimals = 8
        case .fixed:
            maxDecimals = settings.fixedDecimalPlaces
        }

        let rounded = normalizeForComputation(value, settings: settings)

        let signed = NSDecimalNumber(decimal: rounded).stringValue
        let parts = signed.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        var intPart = String(parts.first ?? "0")
        let isNegative = intPart.hasPrefix("-")
        if isNegative {
            intPart.removeFirst()
        }

        let groupedInt = groupThousands(intPart)
        let sign = isNegative ? "-" : ""

        guard parts.count == 2 else {
            if settings.decimalMode == .fixed && maxDecimals > 0 {
                return sign + groupedInt + "," + String(repeating: "0", count: maxDecimals)
            }
            return sign + groupedInt
        }

        var fraction = String(parts[1])
        if fraction.count > maxDecimals {
            fraction = String(fraction.prefix(maxDecimals))
        }

        if settings.decimalMode == .fixed {
            while fraction.count < maxDecimals {
                fraction.append("0")
            }

            if maxDecimals == 0 {
                return sign + groupedInt
            }

            return sign + groupedInt + "," + fraction
        }

        while fraction.last == "0" {
            fraction.removeLast()
        }

        if fraction.isEmpty {
            return sign + groupedInt
        }

        return sign + groupedInt + "," + fraction
    }

    static func normalizeForComputation(_ value: Decimal, settings: FastCalcFormatSettings) -> Decimal {
        let targetDecimals: Int
        switch settings.decimalMode {
        case .floating:
            targetDecimals = periodicTruncationPlaces
        case .fixed:
            targetDecimals = max(0, min(periodicTruncationPlaces, settings.fixedDecimalPlaces))
        }

        let truncated = truncateTowardZero(value, places: periodicTruncationPlaces)

        var rounded = Decimal()
        var mutable = truncated
        NSDecimalRound(&rounded, &mutable, targetDecimals, settings.roundingMode.decimalMode)
        return rounded
    }

    static func parseLocaleAwareDecimal(_ raw: String) -> Decimal? {
        guard let normalized = normalizedDecimalString(from: raw) else {
            return nil
        }
        return Decimal(string: normalized)
    }

    static func normalizedDecimalString(from raw: String) -> String? {
        let stripped = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "'", with: "")

        guard !stripped.isEmpty else { return nil }

        let sign: String
        let unsigned: String
        if stripped.hasPrefix("-") {
            sign = "-"
            unsigned = String(stripped.dropFirst())
        } else if stripped.hasPrefix("+") {
            sign = ""
            unsigned = String(stripped.dropFirst())
        } else {
            sign = ""
            unsigned = stripped
        }

        guard !unsigned.isEmpty else { return nil }
        guard unsigned.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," }) else {
            return nil
        }

        let separatorIndexes = unsigned.indices.filter { unsigned[$0] == "." || unsigned[$0] == "," }
        let decimalIndex = inferredDecimalSeparatorIndex(in: unsigned, separatorIndexes: separatorIndexes)

        var digits = ""
        var hasDecimalSeparator = false

        for index in unsigned.indices {
            let char = unsigned[index]
            if char.isNumber {
                digits.append(char)
            } else if index == decimalIndex, !hasDecimalSeparator {
                digits.append(".")
                hasDecimalSeparator = true
            }
        }

        guard !digits.isEmpty else { return nil }

        if digits.hasPrefix(".") {
            digits = "0" + digits
        }

        if digits.hasSuffix(".") {
            digits.removeLast()
        }

        guard !digits.isEmpty else { return nil }
        return sign + digits
    }

    private static func inferredDecimalSeparatorIndex(in raw: String, separatorIndexes: [String.Index]) -> String.Index? {
        guard !separatorIndexes.isEmpty else { return nil }

        let commaIndexes = separatorIndexes.filter { raw[$0] == "," }
        let dotIndexes = separatorIndexes.filter { raw[$0] == "." }

        if let lastComma = commaIndexes.last, let lastDot = dotIndexes.last {
            return lastComma > lastDot ? lastComma : lastDot
        }

        guard let separator = separatorIndexes.first.map({ raw[$0] }) else {
            return nil
        }

        if separatorIndexes.count == 1 {
            return separatorIndexes[0]
        }

        let parts = raw.split(separator: separator, omittingEmptySubsequences: false)
        guard let lastPart = parts.last else { return separatorIndexes.last }
        let middleParts = parts.dropFirst().dropLast()
        let middleLookLikeGroups = middleParts.allSatisfy { $0.count == 3 }

        if lastPart.count == 3, middleLookLikeGroups {
            return nil
        }

        if middleLookLikeGroups {
            return separatorIndexes.last
        }

        return separatorIndexes.last
    }

    private static func integerDigits(in value: Decimal) -> Int {
        let absString = NSDecimalNumber(decimal: value).stringValue
        let cleaned = absString
            .replacingOccurrences(of: "-", with: "")
            .split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? "0"
        let trimmed = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "0"))
        return max(trimmed.count, 1)
    }

    private static func groupThousands(_ digits: String) -> String {
        guard digits.count > 3 else { return digits }
        var output: [Character] = []
        output.reserveCapacity(digits.count + digits.count / 3)

        for (idx, ch) in digits.reversed().enumerated() {
            if idx > 0 && idx % 3 == 0 {
                output.append("'")
            }
            output.append(ch)
        }

        return String(output.reversed())
    }

    private static func truncateTowardZero(_ value: Decimal, places: Int) -> Decimal {
        var truncated = Decimal()
        var mutable = value
        let mode: NSDecimalNumber.RoundingMode = value < 0 ? .up : .down
        NSDecimalRound(&truncated, &mutable, places, mode)
        return truncated
    }
}
