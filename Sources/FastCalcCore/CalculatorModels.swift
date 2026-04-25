import Foundation

public enum CalculatorOperator: String, Sendable {
    case add = "+"
    case subtract = "-"
    case multiply = "*"
    case divide = "/"
    case power = "^"
    case squareRoot = "√"
    case deltaPercent = "D"
}

public enum ResultKey: String, Sendable {
    case enter
    case equals
    case total
}

public struct RollEntry: Equatable, Sendable {
    public let expression: String
    public let output: String

    public init(expression: String, output: String) {
        self.expression = expression
        self.output = output
    }
}

public enum DeleteOutcome: Equatable, Sendable {
    case singleReset
    case fullClear
}

public struct ResultEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case ignored
        case result
        case totalRecall
    }

    public let kind: Kind
    public let value: Decimal

    public init(kind: Kind, value: Decimal) {
        self.kind = kind
        self.value = value
    }
}

public struct CalculatorSnapshot: Equatable, Sendable {
    public let currentInput: String
    public let pendingOperator: CalculatorOperator?
    public let register: Decimal?
    public let totalizer: Decimal
    public let totalizerFIFO: [Decimal]
    public let roll: [RollEntry]

    public init(
        currentInput: String,
        pendingOperator: CalculatorOperator?,
        register: Decimal?,
        totalizer: Decimal,
        totalizerFIFO: [Decimal],
        roll: [RollEntry]
    ) {
        self.currentInput = currentInput
        self.pendingOperator = pendingOperator
        self.register = register
        self.totalizer = totalizer
        self.totalizerFIFO = totalizerFIFO
        self.roll = roll
    }
}
