//
// This file contains number and tape formatting helpers.
// It keeps calculator column formatting deterministic.
//

import Foundation

enum TapeFormatter {
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
            maxDecimals = max(0, 6 - max(0, intDigits - 10))
        case .fixed:
            maxDecimals = settings.fixedDecimalPlaces
        }

        var rounded = Decimal()
        var mutable = value
        NSDecimalRound(&rounded, &mutable, maxDecimals, settings.roundingMode.decimalMode)

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

    static func parseLocaleAwareDecimal(_ raw: String) -> Decimal? {
        let normalized = raw
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
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
}
