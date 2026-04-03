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

    // Con moltiplicazione + percento, il risultato deve restituire il valore percentuale puro
    @Test func multiplyPercentThenResultReturnsStandalonePercentage() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("5")
        _ = engine.inputCharacter("*")
        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("5")
        _ = engine.inputCharacter("%")

        let result = engine.pressResult(.equals)
        #expect(result.kind == .result)
        #expect(result.value == Decimal(string: "6.25"))
    }

    // Dopo il risultato percentuale standalone, + e - devono continuare dal valore percentuale
    @Test func standalonePercentageCanBeUsedForSubsequentAddition() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("5")
        _ = engine.inputCharacter("*")
        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("5")
        _ = engine.inputCharacter("%")
        _ = engine.pressResult(.equals)

        _ = engine.inputCharacter("+")
        _ = engine.inputCharacter("1")
        let result = engine.pressResult(.enter)

        #expect(result.kind == .result)
        #expect(result.value == Decimal(string: "7.25"))
    }

    // Con divisione + percento, il risultato deve dividere per la percentuale convertita
    @Test func dividePercentThenResultDividesByConvertedPercentage() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("5")
        _ = engine.inputCharacter("/")
        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("5")
        _ = engine.inputCharacter("%")

        let result = engine.pressResult(.equals)
        #expect(result.kind == .result)
        #expect(result.value == Decimal(string: "100"))
    }

    // Dopo divisione con percento, + e - devono continuare dal risultato calcolato
    @Test func divisionPercentResultCanBeUsedForSubsequentAddition() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("5")
        _ = engine.inputCharacter("/")
        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("5")
        _ = engine.inputCharacter("%")
        _ = engine.pressResult(.equals)

        _ = engine.inputCharacter("+")
        _ = engine.inputCharacter("5")
        let result = engine.pressResult(.enter)

        #expect(result.kind == .result)
        #expect(result.value == Decimal(string: "105"))
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

    // Regressione: catena divisione->moltiplicazione non deve perdere la parte frazionaria nel valore interno
    @Test func chainedDivisionThenMultiplicationKeepsFractionalInternalValue() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter(".")
        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("/")
        _ = engine.inputCharacter("3")
        let first = engine.pressResult(.enter)

        #expect(first.kind == .result)
        #expect(first.value > Decimal(string: "0.7333")!)
        #expect(first.value < Decimal(string: "0.7334")!)

        _ = engine.inputCharacter("*")
        _ = engine.inputCharacter("1")
        _ = engine.inputCharacter("5")
        let second = engine.pressResult(.enter)

        #expect(second.kind == .result)
        #expect(second.value > Decimal(string: "10.999")!)
        #expect(second.value < Decimal(11))
    }

    // Il formato roll deve restare coerente con il limite massimo di 8 decimali
    @Test func divisionResultUsesEightFractionDigitsInRollOutput() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter(".")
        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("/")
        _ = engine.inputCharacter("3")
        _ = engine.pressResult(.enter)

        let snapshot = engine.snapshot()
        #expect(snapshot.roll.count == 1)
        #expect(snapshot.roll[0].output == "0.73333333")
    }

    // Con operatore pendente e nessun nuovo input, invio deve confermare il parziale corrente
    @Test func pendingAdditionWithoutRightOperandKeepsCurrentPartial() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("1")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("+")
        _ = engine.inputCharacter("1")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("+")

        let result = engine.pressResult(.enter)
        #expect(result.kind == .result)
        #expect(result.value == Decimal(200))
    }

    // Delta percentuale: variazione tra P1 e P2
    @Test func deltaPercentComputesRelativeChange() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("9")
        _ = engine.inputCharacter("5")
        _ = engine.inputCharacter("D")
        _ = engine.inputCharacter("8")
        _ = engine.inputCharacter("5")

        let result = engine.pressResult(.equals)
        #expect(result.kind == .result)
        #expect(result.value > Decimal(string: "-10.53")!)
        #expect(result.value < Decimal(string: "-10.52")!)
    }

    // Delta percentuale può essere usato come base per operazioni successive
    @Test func deltaPercentResultCanBeUsedForSubsequentAddition() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("1")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("D")
        _ = engine.inputCharacter("1")
        _ = engine.inputCharacter("1")
        _ = engine.inputCharacter("0")
        _ = engine.pressResult(.enter)

        _ = engine.inputCharacter("+")
        _ = engine.inputCharacter("5")
        let result = engine.pressResult(.enter)
        #expect(result.kind == .result)
        #expect(result.value == Decimal(15))
    }

    // Con sottrazione pendente e nessun nuovo input, invio deve confermare il parziale corrente
    @Test func pendingSubtractionWithoutRightOperandKeepsCurrentPartial() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("1")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("-")
        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("5")
        _ = engine.inputCharacter("-")

        let result = engine.pressResult(.enter)
        #expect(result.kind == .result)
        #expect(result.value == Decimal(75))
    }

    // Con moltiplicazione pendente e nessun nuovo input, invio deve confermare il parziale corrente
    @Test func pendingMultiplicationWithoutRightOperandKeepsCurrentPartial() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("1")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("*")
        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("*")

        let result = engine.pressResult(.enter)
        #expect(result.kind == .result)
        #expect(result.value == Decimal(200))
    }

    // Dopo un operatore pendente, '-' deve avviare il cambio segno del secondo operando
    @Test func minusAfterPendingOperatorCreatesSignedRightOperand() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("1")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("*")
        _ = engine.inputCharacter("-")

        let afterMinus = engine.snapshot()
        #expect(afterMinus.pendingOperator == .multiply)
        #expect(afterMinus.currentInput == "-")

        _ = engine.inputCharacter("1")
        let result = engine.pressResult(.enter)

        #expect(result.kind == .result)
        #expect(result.value == Decimal(-100))
    }

    // Doppio '-' in attesa del secondo operando deve fare toggle del segno
    @Test func repeatedMinusAfterPendingOperatorTogglesSign() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("1")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("*")
        _ = engine.inputCharacter("-")
        _ = engine.inputCharacter("-")

        let afterSecondMinus = engine.snapshot()
        #expect(afterSecondMinus.pendingOperator == .multiply)
        #expect(afterSecondMinus.currentInput == "")

        _ = engine.inputCharacter("1")
        let result = engine.pressResult(.enter)

        #expect(result.kind == .result)
        #expect(result.value == Decimal(100))
    }

    // Con divisione pendente e nessun nuovo input, invio deve confermare il parziale corrente
    @Test func pendingDivisionWithoutRightOperandKeepsCurrentPartial() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("1")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("/")
        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("/")

        let result = engine.pressResult(.enter)
        #expect(result.kind == .result)
        #expect(result.value == Decimal(50))
    }

    // M deve accodare GT (se non zero), azzerare GT e preservare il segno
    @Test func enqueueTotalizerMovesSignedValueToFIFOAndResetsGT() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("1")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("-")
        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("5")
        _ = engine.pressResult(.enter)

        #expect(engine.snapshot().totalizer == Decimal(75))
        let enqueued = engine.enqueueTotalizerIfNeeded()

        #expect(enqueued == Decimal(75))
        #expect(engine.snapshot().totalizer == Decimal(0))
        #expect(engine.snapshot().totalizerFIFO == [Decimal(75)])

        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("-")
        _ = engine.inputCharacter("3")
        _ = engine.inputCharacter("0")
        _ = engine.inputCharacter("0")
        _ = engine.pressResult(.enter)

        #expect(engine.snapshot().totalizer == Decimal(-100))
        let enqueuedNegative = engine.enqueueTotalizerIfNeeded()
        #expect(enqueuedNegative == Decimal(-100))
        #expect(engine.snapshot().totalizerFIFO == [Decimal(75), Decimal(-100)])
    }

    // M su GT zero/non presente non deve produrre effetti
    @Test func enqueueTotalizerWithZeroDoesNothing() {
        let engine = CalculatorEngine()

        let enqueuedAtStartup = engine.enqueueTotalizerIfNeeded()
        #expect(enqueuedAtStartup == nil)
        #expect(engine.snapshot().totalizerFIFO.isEmpty)

        _ = engine.inputCharacter("9")
        _ = engine.pressResult(.enter)
        _ = engine.enqueueTotalizerIfNeeded()

        let enqueuedAgain = engine.enqueueTotalizerIfNeeded()
        #expect(enqueuedAgain == nil)
        #expect(engine.snapshot().totalizerFIFO == [Decimal(9)])
    }

    // R deve richiamare valori in ordine FIFO e rimuoverli dalla coda
    @Test func recallFromFIFOUsesQueueOrderAndConsumesValues() {
        let engine = CalculatorEngine()

        _ = engine.inputCharacter("1")
        _ = engine.inputCharacter("0")
        _ = engine.pressResult(.enter)
        _ = engine.enqueueTotalizerIfNeeded()

        _ = engine.inputCharacter("2")
        _ = engine.inputCharacter("0")
        _ = engine.pressResult(.enter)
        _ = engine.enqueueTotalizerIfNeeded()

        let firstRecall = engine.recallNextEnqueuedTotalizer()
        #expect(firstRecall == Decimal(10))
        #expect(engine.snapshot().totalizerFIFO == [Decimal(20)])

        _ = engine.inputCharacter("+")
        _ = engine.inputCharacter("5")
        let result = engine.pressResult(.enter)
        #expect(result.value == Decimal(15))

        let secondRecall = engine.recallNextEnqueuedTotalizer()
        #expect(secondRecall == Decimal(20))
        #expect(engine.snapshot().totalizerFIFO.isEmpty)

        let none = engine.recallNextEnqueuedTotalizer()
        #expect(none == nil)
    }
}
