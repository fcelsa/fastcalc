import Foundation

public final class CalculatorEngine: @unchecked Sendable {
    private var currentInput = ""
    private var register: Decimal?
    private var pendingOperator: CalculatorOperator?
    private var totalizer: Decimal = 0
    private var roll: [RollEntry] = []
    private var canRecallTotalizer = false
    private var lastResultHadOperator = false
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
            setOperator(.subtract)
            return true
        case "*", "x", "X":
            setOperator(.multiply)
            return true
        case "/":
            setOperator(.divide)
            return true
        default:
            return false
        }
    }

    @discardableResult
    public func applyPercent() -> Decimal? {
        let result: Decimal

        if let inputValue = parseCurrentInput() {
            if pendingOperator != nil, let lhs = register {
                result = lhs * inputValue / 100
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
        deleteTracker.reset()
        return result
    }

    public func appendDecimalSeparator() {
        if currentInput.isEmpty {
            currentInput = "0."
        } else if !currentInput.contains(".") {
            currentInput.append(".")
        }
        canRecallTotalizer = false
        lastResultHadOperator = false
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
        deleteTracker.reset()
    }

    public func backspace() {
        guard !currentInput.isEmpty else { return }
        currentInput.removeLast()
        canRecallTotalizer = false
        lastResultHadOperator = false
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
        deleteTracker.reset()
    }

    public func snapshot() -> CalculatorSnapshot {
        CalculatorSnapshot(
            currentInput: currentInput,
            pendingOperator: pendingOperator,
            register: register,
            totalizer: totalizer,
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
    }

    private func fullClear() {
        currentInput = ""
        register = nil
        pendingOperator = nil
        totalizer = 0
        roll = []
        canRecallTotalizer = false
        lastResultHadOperator = false
        deleteTracker.reset()
    }

    private func computeResultValue() -> Decimal {
        let inputValue = parseCurrentInput()

        if let pending = pendingOperator, let lhs = register {
            let rhs = inputValue ?? lhs
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

    private func expressionForResult(key: ResultKey) -> String {
        let left = register.map(format) ?? "0"
        let right = currentInput.isEmpty ? left : currentInput

        if let op = pendingOperator {
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
        }
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
