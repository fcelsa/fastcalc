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
    case draft
}

struct TapeRow: Equatable, Codable {
    var special: String
    var calc: String
    var operand: String
    var kind: TapeRowKind

    var isEditable: Bool {
        switch kind {
        case .committed, .draft:
            return true
        default:
            return false
        }
    }
}
