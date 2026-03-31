import Foundation
import Testing
@testable import FastCalcCore

@Suite("CalculatorEngine")
struct CalculatorEngineTests {
    // Accumulo e richiamo totale dopo sequenze di operazioni
    @Test func automaticAccumulationAndTotalRecall() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("1")
        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("+")
        _ = engine.inputCharacter("8")
        let first = engine.pressResult(.enter)

        #expect(first.kind == .result)
        #expect(first.value == Decimal(20))

        _ = engine.inputCharacter("+")
        _ = engine.inputCharacter("5")
        let second = engine.pressResult(.equals)
        #expect(second.kind == .result)
        #expect(second.value == Decimal(25))

        let total = engine.pressResult(.total)
        #expect(total.kind == .totalRecall)
        #expect(total.value == Decimal(45))
        #expect(engine.snapshot().totalizer == Decimal(0))

        #expect(engine.snapshot().roll.count == 3)
    }

    // Diversi tasti risultato producono lo stesso stato
    @Test func equivalentResultKeysProduceSameState() {
        let enterEngine = CalculatorEngine()
        _ = enterEngine.inputCharacter("7")
        _ = enterEngine.inputCharacter("+")
        _ = enterEngine.inputCharacter("3")
        _ = enterEngine.pressResult(.enter)

        let equalsEngine = CalculatorEngine()
        _ = equalsEngine.inputCharacter("7")
        _ = equalsEngine.inputCharacter("+")
        _ = equalsEngine.inputCharacter("3")
        _ = equalsEngine.pressResult(.equals)

        let totalEngine = CalculatorEngine()
        _ = totalEngine.inputCharacter("7")
        _ = totalEngine.inputCharacter("+")
        _ = totalEngine.inputCharacter("3")
        _ = totalEngine.pressResult(.total)

        #expect(enterEngine.snapshot().totalizer == Decimal(10))
        #expect(equalsEngine.snapshot().totalizer == Decimal(10))
        #expect(totalEngine.snapshot().totalizer == Decimal(10))
    }

    // Backspace modifica solo l'input corrente
    @Test func backspaceAffectsOnlyCurrentInput() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("1")
        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("3")
        engine.backspace()

        #expect(engine.snapshot().currentInput == "12")

        _ = engine.pressResult(.enter)
        #expect(engine.snapshot().roll.count == 1)

        engine.backspace()
        #expect(engine.snapshot().roll.count == 1)
    }

    // Singola cancellazione resetta l'input mantenendo la storia
    @Test func singleDeleteResetsCurrentCalculationButKeepsHistory() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("4")
        _ = engine.pressResult(.enter)
        #expect(engine.snapshot().roll.count == 1)
        #expect(engine.snapshot().totalizer == Decimal(4))

        _ = engine.inputCharacter("9")
        _ = engine.inputCharacter("+")
        _ = engine.inputCharacter("1")

        let outcome = engine.pressDelete()
        #expect(outcome == .singleReset)
        #expect(engine.snapshot().roll.count == 1)
        #expect(engine.snapshot().currentInput == "")
        #expect(engine.snapshot().pendingOperator == nil)
        #expect(engine.snapshot().totalizer == Decimal(0))
    }

    // Doppia cancellazione pulisce tutto
    @Test func doubleDeleteClearsEverything() {
        let engine = CalculatorEngine(deleteThreshold: 1.0)

        _ = engine.inputCharacter("4")
        _ = engine.pressResult(.enter)
        #expect(engine.snapshot().roll.count == 1)

        let firstDelete = engine.pressDelete(at: Date(timeIntervalSince1970: 100))
        let secondDelete = engine.pressDelete(at: Date(timeIntervalSince1970: 100.3))

        #expect(firstDelete == .singleReset)
        #expect(secondDelete == .fullClear)
        #expect(engine.snapshot().roll.count == 0)
        #expect(engine.snapshot().totalizer == Decimal(0))
    }

    // Percent senza operatore divide per 100
    @Test func percentWithoutPendingOperatorDividesByHundred() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("0")
        let percent = engine.applyPercent()

        #expect(percent == Decimal(string: "0.2"))
        #expect(engine.snapshot().currentInput == "0.2")
    }

    // Percent con operatore usa il registro come base
    @Test func percentWithPendingOperatorUsesRegisterAsBase() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("+")
        _ = engine.inputCharacter("1")
        _ = engine.inputCharacter("0")

        let percent = engine.applyPercent()
        #expect(percent == Decimal(2))

        let result = engine.pressResult(.enter)
        #expect(result.value == Decimal(22))
    }

    // Richiamo totale avvia nuova operazione e resetta l'accumulatore
    @Test func recalledTotalCanStartNewOperationAndResetsAccumulator() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("1")
        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("+")
        _ = engine.inputCharacter("8")
        _ = engine.pressResult(.enter)

        let total = engine.pressResult(.equals)
        #expect(total.kind == .totalRecall)
        #expect(total.value == Decimal(20))
        #expect(engine.snapshot().totalizer == Decimal(0))

        _ = engine.inputCharacter("+")
        _ = engine.inputCharacter("5")
        let next = engine.pressResult(.enter)

        #expect(next.value == Decimal(25))
        #expect(engine.snapshot().totalizer == Decimal(25))
    }

    // Risultato ripetuto senza operatore viene ignorato
    @Test func repeatedResultWithoutOperatorIsIgnored() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("9")
        let first = engine.pressResult(.enter)
        #expect(first.kind == .result)

        let second = engine.pressResult(.equals)
        #expect(second.kind == .ignored)
        #expect(engine.snapshot().roll.count == 1)
    }

    // Risultato all'avvio è ignorato
    @Test func resultAtStartupIsIgnored() {
        let engine = CalculatorEngine()

        let event = engine.pressResult(.enter)
        #expect(event.kind == .ignored)
        #expect(engine.snapshot().roll.isEmpty)
        #expect(engine.snapshot().totalizer == Decimal(0))
    }
}
