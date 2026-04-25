import Foundation

enum MultiFunctionTrigger: String {
    case p
    case f
    case h

    var displayTitle: String {
        switch self {
        case .p:
            return "P"
        case .f:
            return "F"
        case .h:
            return "H"
        }
    }
}

enum MultiFunctionActionKey {
    static let square = "square"
    static let cube = "cube"
    static let powerN = "powerN"
    static let squareRoot = "squareRoot"

    static func customFunction(_ id: String) -> String {
        "function:\(id)"
    }

    static func customFunctionID(from key: String) -> String? {
        guard key.hasPrefix("function:") else { return nil }
        return String(key.dropFirst("function:".count))
    }
}

struct MultiFunctionActionDescriptor {
    let id: String
    let title: String
    let detail: String
}

struct MultiFunctionActionSet {
    let trigger: MultiFunctionTrigger
    let title: String
    let actions: [MultiFunctionActionDescriptor]

    static let pMVP = MultiFunctionActionSet(
        trigger: .p,
        title: "Potenze e radice",
        actions: [
            MultiFunctionActionDescriptor(id: MultiFunctionActionKey.square, title: "x²", detail: "Potenza di 2"),
            MultiFunctionActionDescriptor(id: MultiFunctionActionKey.cube, title: "x³", detail: "Potenza di 3"),
            MultiFunctionActionDescriptor(id: MultiFunctionActionKey.powerN, title: "xⁿ", detail: "^n solo interi"),
            MultiFunctionActionDescriptor(id: MultiFunctionActionKey.squareRoot, title: "\u{221A}", detail: "Radice quadrata")
        ]
    )

    static func fActions(_ functions: [UserDefinedFunction]) -> MultiFunctionActionSet {
        let mapped = functions.enumerated().map { _, function in
            let detail = function.note.isEmpty ? function.expression : function.note
            return MultiFunctionActionDescriptor(
                id: MultiFunctionActionKey.customFunction(function.id),
                title: function.label,
                detail: detail
            )
        }
        return MultiFunctionActionSet(trigger: .f, title: "Funzioni utente", actions: mapped)
    }

    struct HelpContent {
        let title: String
        let lines: [String]
    }

    static func localizedHelpContent() -> HelpContent {
        let title = localized(
            "help.title",
            fallback: "Quick help",
            comment: "Keyboard help popover title"
        )

        let lines: [String] = [
            localized("help.section.input", fallback: "INPUT", comment: "Input section title"),
            localized("help.line.numeric", fallback: "- 0-9 , . : numeric input", comment: "Numeric input help line"),
            localized("help.line.operators", fallback: "- + - * / D % : operators and percentages", comment: "Operators help line"),
            "",
            localized("help.section.multifunction", fallback: "MULTI-FUNCTION", comment: "Multi-function section title"),
            localized("help.line.p", fallback: "- P : powers and square root popover", comment: "P key help line"),
            localized("help.line.f", fallback: "- F : user functions popover", comment: "F key help line"),
            localized("help.line.h", fallback: "- H : show/hide this help", comment: "H key toggle help line"),
            localized("help.line.popover.select", fallback: "- 1..9 / arrows / Enter / Esc : popover selection", comment: "Popover selection help line"),
            "",
            localized("help.section.calc", fallback: "CALCULATION & MEMORY", comment: "Calculation and memory section title"),
            localized("help.line.result", fallback: "- Enter or = or T : result", comment: "Result key help line"),
            localized("help.line.fifo", fallback: "- M / R : FIFO totalizer", comment: "FIFO memory help line"),
            "",
            localized("help.section.edit", fallback: "EDIT", comment: "Edit section title"),
            localized("help.line.backspace", fallback: "- Backspace : delete one character", comment: "Backspace help line"),
            localized("help.line.delete", fallback: "- Delete x2 : full reset", comment: "Double delete help line"),
            localized("help.line.optionDelete", fallback: "- Option + Delete x2 : reset + position", comment: "Option delete help line"),
            localized("help.line.undo", fallback: "- Cmd+Z : undo full clear", comment: "Undo full clear help line")
        ]

        return HelpContent(title: title, lines: lines)
    }

    private static func localized(_ key: String, fallback: String, comment: String) -> String {
        NSLocalizedString(
            key,
            tableName: nil,
            bundle: .main,
            value: fallback,
            comment: comment
        )
    }
}
