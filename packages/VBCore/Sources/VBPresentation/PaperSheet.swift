// A game copied from paper, laid out for correcting.
//
// Every decision a correction screen would otherwise make itself lives here: who gets a row,
// what a blank box means, and which rows are complete enough to save. The screen draws the
// rows and sends what this hands it.
//
// The rule this exists to protect is the oldest one in the project. A figure nobody wrote
// down is a dash, never a nought -- and on a sheet being corrected that matters more than
// anywhere else, because a nought typed into an empty box would claim a player served and
// missed serves they never took.
import Foundation
import VBCore

/// One player's line on a paper sheet being corrected.
public struct PaperRow: Equatable, Sendable, Identifiable {
    public var id: String { playerId }

    public var playerId: String
    public var name: String
    public var number: String

    /// Nil where the sheet said nothing about this player. A nought is a figure somebody
    /// wrote down; nil is the absence of one, and the two must never be confused.
    public var servesIn: Int?
    public var servesOut: Int?

    public init(playerId: String, name: String, number: String, servesIn: Int?, servesOut: Int?) {
        self.playerId = playerId
        self.name = name
        self.number = number
        self.servesIn = servesIn
        self.servesOut = servesOut
    }

    /// True once both counts are filled in, which is when the row can be saved.
    ///
    /// Half a row is not half a figure: a player with serves in and no serves out has not
    /// been recorded, they have been started.
    public var isComplete: Bool { servesIn != nil && servesOut != nil }
}

public enum PaperSheet {
    /// A row for every player on the season's roster, carrying whatever the sheet recorded.
    ///
    /// Every player, not only the ones already on the sheet: correcting a game very often
    /// means adding somebody the transcription missed, and a roster member with no row is a
    /// player the screen offers no way to record.
    public static func rows(roster: [RosterEntry], entries: [HistoricalEntry]) -> [PaperRow] {
        roster.map { member in
            let recorded = entries.first { $0.playerId == member.id }
            return PaperRow(
                playerId: member.id,
                name: member.name,
                number: member.number,
                servesIn: recorded?.servesIn,
                servesOut: recorded?.servesOut
            )
        }
    }

    /// The rows complete enough to be saved, in roster order.
    ///
    /// A half-typed row is left out rather than saved as a nought, so a correction abandoned
    /// mid-thought cannot invent serves nobody took.
    public static func entries(from rows: [PaperRow]) -> [RawHistoricalEntry] {
        rows.filter(\.isComplete).map {
            RawHistoricalEntry(playerId: $0.playerId, servesIn: $0.servesIn, servesOut: $0.servesOut)
        }
    }

    /// True when the rows say something the record does not already say.
    ///
    /// Asked before saving so that opening a game and closing it again writes no event. A log
    /// that grows every time somebody looks at a game makes undo meaningless.
    public static func hasChanges(_ rows: [PaperRow], against recorded: [HistoricalEntry]) -> Bool {
        let proposed = entries(from: rows)
        guard proposed.count == recorded.count else { return true }

        for entry in proposed {
            guard let existing = recorded.first(where: { $0.playerId == entry.playerId }) else { return true }
            if existing.servesIn != entry.servesIn || existing.servesOut != entry.servesOut { return true }
        }
        return false
    }
}
