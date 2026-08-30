// How the tally board is laid out: one row per player, their turns along it.
//
// The row order and the colour both come from here rather than from the view, because both
// are decisions — who appears where, and which colour means which person — and a decision a
// view makes for itself cannot be tested on a machine with no Mac.
import Foundation
import VBCore

/// One player's row on the tally board.
public struct TallyRow: Equatable, Sendable {
    /// Where this player sits in the order they first served, which is what their colour
    /// comes from. Stable for as long as the match lasts.
    public var playerIndex: Int

    public var playerId: String

    /// Their turns, in the order they took them.
    public var turns: [Turn]

    /// Their totals across those turns, so the row can say them without recounting.
    public var figures: Figures

    public init(playerIndex: Int, playerId: String, turns: [Turn], figures: Figures) {
        self.playerIndex = playerIndex
        self.playerId = playerId
        self.turns = turns
        self.figures = figures
    }

    /// The colour of one of this player's turns: their hue, at that turn's shade.
    public func color(ofTurnAt position: Int) -> String {
        colorForTurn(playerIndex: playerIndex, turnIndex: position)
    }

    /// The player's own colour, for anything that names them rather than a turn.
    public var color: String { colorForPlayer(playerIndex) }
}

/// The board, grouped by player.
///
/// Rows are in the order the players first served, which is the order the coach watched
/// them go — and, because it never changes once a player has served, the order that keeps a
/// colour attached to the same person all match.
public func tallyRows(of match: Match?) -> [TallyRow] {
    guard let match else { return [] }

    var order: [String] = []
    var byPlayer: [String: [Turn]] = [:]

    for turn in match.turns where !turn.serves.isEmpty {
        if byPlayer[turn.playerId] == nil { order.append(turn.playerId) }
        byPlayer[turn.playerId, default: []].append(turn)
    }

    return order.enumerated().map { index, playerId in
        let turns = byPlayer[playerId] ?? []
        return TallyRow(
            playerIndex: index,
            playerId: playerId,
            turns: turns,
            figures: totals(of: turns)
        )
    }
}

/// What a colour on the board can be looked up against: every player who has served, and
/// the colour that is theirs.
public func tallyKey(of match: Match?) -> [(playerId: String, color: String)] {
    tallyRows(of: match).map { ($0.playerId, $0.color) }
}

/// The colour of a single turn, found by which player took it.
///
/// For the correction screens, which show one turn at a time and have no row to ask.
public func color(ofTurn turn: Turn, in match: Match?) -> String {
    guard let row = tallyRows(of: match).first(where: { $0.playerId == turn.playerId }),
        let position = row.turns.firstIndex(where: { $0.ordinal == turn.ordinal })
    else {
        // A turn with no serves in it is not on the board; give it the first hue rather
        // than nothing, so an editor still has something to draw.
        return colorForPlayer(0)
    }
    return row.color(ofTurnAt: position)
}

/// Adds up a set of turns.
private func totals(of turns: [Turn]) -> Figures {
    turns.reduce(into: Figures()) { running, turn in
        let figures = turn.figures
        running.serves += figures.serves
        running.servesIn += figures.servesIn
        running.points += figures.points
    }
}
