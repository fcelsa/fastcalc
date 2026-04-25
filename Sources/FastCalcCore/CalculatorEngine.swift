import Foundation

public final class CalculatorEngine: @unchecked Sendable {
    private var currentInput = ""
    private var register: Decimal?
    private var pendingOperator: CalculatorOperator?
    private var totalizer: Decimal = 0
    private var totalizerFIFO: [Decimal] = []
    private var roll: [RollEntry] = []
    private var canRecallTotalizer = false
    private var lastResultHadOperator = false
    private var pendingStandalonePercentResult = false
    private var deleteTracker: DeletePressTracker

    public init(deleteThreshold: TimeInterval = 0.7) {
        self.deleteTracker = DeletePressTracker(threshold: deleteThreshold)
    }

    @discardableResult
    public func inputCharacter(_ character: Character) -> Bool {
        switch character {
        case "0"..."9":
            currentInput.append(character)
            canRecallTotalizer = false
            lastResultHadOperator = false
            pendingStandalonePercentResult = false
            return true
        case ".", ",":
            appendDecimalSeparator()
            return true
        case "%":
            _ = applyPercent()
            return true
        case "+":
            setOperator(.add)
            return true
        case "-":
            if shouldToggleInputSignOnMinus() {
                toggleCurrentInputSign()
                return true
            }
            setOperator(.subtract)
            return true
        case "*", "x", "X":
            setOperator(.multiply)
            return true
        case "/":
            setOperator(.divide)
            return true
        case "^":
            setOperator(.power)
            return true
        case "√":
            setOperator(.squareRoot)
            return true
        case "d", "D":
            setOperator(.deltaPercent)
            return true
        default:
            return false
        }
    }

    @discardableResult
    public func applyPercent() -> Decimal? {
        let result: Decimal

        if let inputValue = parseCurrentInput() {
            if let pending = pendingOperator, let lhs = register {
                switch pending {
                case .add, .subtract, .multiply:
                    result = lhs * inputValue / 100
                case .divide:
                    result = inputValue / 100
                case .deltaPercent:
                    result = inputValue / 100
                case .power:
                    result = inputValue / 100
                case .squareRoot:
                    result = inputValue / 100
                }
            } else {
                result = inputValue / 100
            }
        } else if let lhs = register {
            result = lhs / 100
        } else {
            return nil
        }

        currentInput = NSDecimalNumber(decimal: result).stringValue
        canRecallTotalizer = false
        lastResultHadOperator = false
        pendingStandalonePercentResult = pendingOperator == .multiply
        deleteTracker.reset()
        return result
    }

    public func appendDecimalSeparator() {
        if currentInput.isEmpty {
            currentInput = "0."
        } else if currentInput == "-" {
            currentInput = "-0."
        } else if !currentInput.contains(".") {
            currentInput.append(".")
        }
        canRecallTotalizer = false
        lastResultHadOperator = false
        pendingStandalonePercentResult = false
    }

    public func setOperator(_ op: CalculatorOperator) {
        if let value = parseCurrentInput() {
            if let pending = pendingOperator, let lhs = register {
                register = apply(pending, lhs: lhs, rhs: value)
            } else {
                register = value
            }
            currentInput = ""
        }

        if register == nil {
            register = 0
        }

        pendingOperator = op
        canRecallTotalizer = false
        lastResultHadOperator = false
        pendingStandalonePercentResult = false
        deleteTracker.reset()
    }

    public func backspace() {
        guard !currentInput.isEmpty else { return }
        currentInput.removeLast()
        canRecallTotalizer = false
        lastResultHadOperator = false
        pendingStandalonePercentResult = false
    }

    @discardableResult
    public func pressDelete(at now: Date = Date()) -> DeleteOutcome {
        let isDoublePress = deleteTracker.registerPress(at: now)
        if isDoublePress {
            fullClear()
            return .fullClear
        }

        singleReset()
        return .singleReset
    }

    public func pressResult(_ key: ResultKey) -> ResultEvent {
        if canRecallTotalizer {
            if !lastResultHadOperator {
                deleteTracker.reset()
                return ResultEvent(kind: .ignored, value: register ?? 0)
            }

            let recalledTotal = totalizer
            let totalText = format(recalledTotal)
            roll.append(RollEntry(expression: "TOTAL [\(key.rawValue)]", output: totalText))

            // After printing the grand total, start a new accumulation cycle.
            register = recalledTotal
            pendingOperator = nil
            currentInput = ""
            totalizer = 0
            canRecallTotalizer = false
            lastResultHadOperator = false
            pendingStandalonePercentResult = false
            deleteTracker.reset()
            return ResultEvent(kind: .totalRecall, value: recalledTotal)
        }

        // Repeated result keys with no pending operation and no fresh input must do nothing.
        if pendingOperator == nil, parseCurrentInput() == nil {
            deleteTracker.reset()
            return ResultEvent(kind: .ignored, value: register ?? 0)
        }

        let expression = expressionForResult(key: key)
        let hadPendingOperator = pendingOperator != nil
        let value = computeResultValue()
        totalizer += value
        let output = format(value)
        roll.append(RollEntry(expression: expression, output: output))

        register = value
        pendingOperator = nil
        currentInput = ""
        canRecallTotalizer = true
        lastResultHadOperator = hadPendingOperator
        pendingStandalonePercentResult = false
        deleteTracker.reset()

        return ResultEvent(kind: .result, value: value)
    }

    public func replaceRoll(with entries: [RollEntry]) {
        roll = entries
    }

    public func replaceCurrentInput(with value: Decimal) {
        currentInput = NSDecimalNumber(decimal: value).stringValue
        canRecallTotalizer = false
        lastResultHadOperator = false
        pendingStandalonePercentResult = false
        deleteTracker.reset()
    }

    public func clearCurrentInput() {
        currentInput = ""
        canRecallTotalizer = false
        lastResultHadOperator = false
        pendingStandalonePercentResult = false
        deleteTracker.reset()
    }

    @discardableResult
    public func enqueueTotalizerIfNeeded() -> Decimal? {
        guard totalizer != 0 else { return nil }
        let enqueued = totalizer
        totalizerFIFO.append(enqueued)
        totalizer = 0
        canRecallTotalizer = false
        lastResultHadOperator = false
        pendingStandalonePercentResult = false
        deleteTracker.reset()
        return enqueued
    }

    @discardableResult
    public func recallNextEnqueuedTotalizer() -> Decimal? {
        guard !totalizerFIFO.isEmpty else { return nil }
        let value = totalizerFIFO.removeFirst()
        replaceCurrentInput(with: value)
        return value
    }

    public func replaceTotalizerFIFO(with values: [Decimal]) {
        totalizerFIFO = values
    }

    public func snapshot() -> CalculatorSnapshot {
        CalculatorSnapshot(
            currentInput: currentInput,
            pendingOperator: pendingOperator,
            register: register,
            totalizer: totalizer,
            totalizerFIFO: totalizerFIFO,
            roll: roll
        )
    }

    private func singleReset() {
        currentInput = ""
        register = nil
        pendingOperator = nil
        totalizer = 0
        canRecallTotalizer = false
        lastResultHadOperator = false
        pendingStandalonePercentResult = false
    }

    private func fullClear() {
        currentInput = ""
        register = nil
        pendingOperator = nil
        totalizer = 0
        totalizerFIFO = []
        roll = []
        canRecallTotalizer = false
        lastResultHadOperator = false
        pendingStandalonePercentResult = false
        deleteTracker.reset()
    }

    private func computeResultValue() -> Decimal {
        let inputValue = parseCurrentInput()

        if shouldUseStandalonePercentResult(), let inputValue {
            return inputValue
        }

        if let pending = pendingOperator, let lhs = register {
            if pending == .squareRoot {
                return sqrtDecimal(lhs) ?? lhs
            }

            guard let rhs = inputValue else {
                // Confirm current partial when operator is pending but rhs is missing.
                return lhs
            }
            return apply(pending, lhs: lhs, rhs: rhs)
        }

        if let inputValue {
            return inputValue
        }

        if let register {
            return register
        }

        return 0
    }

    private func shouldUseStandalonePercentResult() -> Bool {
        guard pendingStandalonePercentResult else { return false }
        guard pendingOperator == .multiply else { return false }
        return register != nil && parseCurrentInput() != nil
    }

    private func shouldToggleInputSignOnMinus() -> Bool {
        guard pendingOperator != nil else { return false }
        return currentInput.isEmpty || currentInput == "-"
    }

    private func toggleCurrentInputSign() {
        if currentInput == "-" {
            currentInput = ""
        } else if currentInput.hasPrefix("-") {
            currentInput.removeFirst()
        } else {
            currentInput = "-" + currentInput
        }

        canRecallTotalizer = false
        lastResultHadOperator = false
        pendingStandalonePercentResult = false
    }

    private func expressionForResult(key: ResultKey) -> String {
        let left = register.map(format) ?? "0"
        let right = currentInput.isEmpty ? left : currentInput

        if let op = pendingOperator {
            if currentInput.isEmpty {
                return "\(left) [\(key.rawValue)]"
            }
            return "\(left) \(op.rawValue) \(right) [\(key.rawValue)]"
        }

        return "\(right) [\(key.rawValue)]"
    }

    private func parseCurrentInput() -> Decimal? {
        guard !currentInput.isEmpty else { return nil }
        return Decimal(string: currentInput.replacingOccurrences(of: ",", with: "."))
    }

    private func apply(_ op: CalculatorOperator, lhs: Decimal, rhs: Decimal) -> Decimal {
        switch op {
        case .add:
            return lhs + rhs
        case .subtract:
            return lhs - rhs
        case .multiply:
            return lhs * rhs
        case .divide:
            if rhs == 0 {
                return 0
            }
            return lhs / rhs
        case .power:
            guard let exponent = integerExponent(from: rhs) else {
                return lhs
            }
            guard let result = powDecimal(base: lhs, exponent: exponent) else {
                return lhs
            }
            return result
        case .squareRoot:
            return sqrtDecimal(lhs) ?? lhs
        case .deltaPercent:
            if lhs == 0 {
                return 0
            }
            return ((rhs - lhs) / lhs) * 100
        }
    }

    private func sqrtDecimal(_ value: Decimal) -> Decimal? {
        guard value >= 0 else { return nil }
        let asDouble = NSDecimalNumber(decimal: value).doubleValue
        return Decimal(sqrt(asDouble))
    }

    private func integerExponent(from value: Decimal) -> Int? {
        var rounded = Decimal()
        var mutableValue = value
        NSDecimalRound(&rounded, &mutableValue, 0, .plain)
        guard rounded == value else { return nil }

        let roundedNumber = NSDecimalNumber(decimal: rounded)
        let int64Value = roundedNumber.int64Value
        let int64AsDecimal = NSDecimalNumber(value: int64Value).decimalValue
        guard int64AsDecimal == rounded else { return nil }
        return Int(exactly: int64Value)
    }

    private func powDecimal(base: Decimal, exponent: Int) -> Decimal? {
        if exponent == 0 {
            return 1
        }
        if base == 0, exponent < 0 {
            return nil
        }

        var absExponent = exponent < 0 ? -exponent : exponent
        var result: Decimal = 1
        var factor = base

        while absExponent > 0 {
            if absExponent % 2 == 1 {
                result *= factor
            }
            absExponent /= 2
            if absExponent > 0 {
                factor *= factor
            }
        }

        if exponent < 0 {
            guard result != 0 else { return nil }
            return 1 / result
        }
        return result
    }

    private func format(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 0
        formatter.minimumIntegerDigits = 1
        formatter.numberStyle = .decimal
        return formatter.string(from: number) ?? number.stringValue
    }
}
