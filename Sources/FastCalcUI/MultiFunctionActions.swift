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
        title: L10n.MultiFunction.powersAndRootTitle,
        actions: [
            MultiFunctionActionDescriptor(id: MultiFunctionActionKey.square, title: L10n.MultiFunction.squareTitle, detail: L10n.MultiFunction.squareDetail),
            MultiFunctionActionDescriptor(id: MultiFunctionActionKey.cube, title: L10n.MultiFunction.cubeTitle, detail: L10n.MultiFunction.cubeDetail),
            MultiFunctionActionDescriptor(id: MultiFunctionActionKey.powerN, title: L10n.MultiFunction.powerNTitle, detail: L10n.MultiFunction.powerNDetail),
            MultiFunctionActionDescriptor(id: MultiFunctionActionKey.squareRoot, title: L10n.MultiFunction.squareRootTitle, detail: L10n.MultiFunction.squareRootDetail)
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
        return MultiFunctionActionSet(trigger: .f, title: L10n.MultiFunction.userFunctionsTitle, actions: mapped)
    }

    struct HelpContent {
        let title: String
        let lines: [String]
    }

    static func localizedHelpContent() -> HelpContent {
        let title = L10n.Help.title

        let lines: [String] = [
            L10n.Help.sectionInput,
            L10n.Help.lineNumeric,
            L10n.Help.lineOperators,
            "",
            L10n.Help.sectionMultiFunction,
            L10n.Help.lineP,
            L10n.Help.lineF,
            L10n.Help.lineH,
            L10n.Help.linePopoverSelect,
            "",
            L10n.Help.sectionCalc,
            L10n.Help.lineResult,
            L10n.Help.lineFifo,
            "",
            L10n.Help.sectionEdit,
            L10n.Help.lineBackspace,
            L10n.Help.lineDelete,
            L10n.Help.lineOptionDelete,
            L10n.Help.lineUndo
        ]

        return HelpContent(title: title, lines: lines)
    }
}
