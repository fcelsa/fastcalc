//
// This file defines tape rows used by the paper-roll UI.
// It models committed and draft rows with column-level data.
//

import Foundation

enum TapeRowKind: String, Codable {
    case committed
    case result
    case total
    case reset
    case separator
    case note
    case text
    case draft
}

struct TapeRow: Equatable, Codable {
    var special: String
    var calc: String
    var operand: String
    var annotation: String
    var kind: TapeRowKind

    init(
        special: String,
        calc: String,
        operand: String,
        annotation: String = "",
        kind: TapeRowKind
    ) {
        self.special = special
        self.calc = calc
        self.operand = operand
        self.annotation = annotation
        self.kind = kind
    }

    var isEditable: Bool {
        switch kind {
        case .committed, .note, .text, .draft:
            return true
        default:
            return false
        }
    }
}
