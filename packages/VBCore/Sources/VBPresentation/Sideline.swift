// The whole picture, for a phone propped up beside the court.
//
// Six on court and everybody else beside them, each carrying the figures that decide a
// substitution. The wrist cannot hold this much and does not try -- it answers one question,
// who serves next. A phone lying on the scorer's table can answer the wider one: given
// everybody available, who should be on.
//
// Pure, like everything else here. The screen draws what this decides and decides nothing.
import Foundation
import VBCore

/// One player who is not on court, and what they have done tonight.
public struct BenchPlayer: Equatable, Sendable, Identifiable {
    public var id: String { playerId }

    public var playerId: String
    public var name: String
    public var number: String

    /// Nil when this player has not served in this match: they have no percentage, and
    /// reporting 0% would say they served and missed.
    public var inPercentage: Double?

    /// Nil where points were never recorded at all.
    public var points: Int?

    public init(playerId: String, name: String, number: String, inPercentage: Double?, points: Int?) {
        self.playerId = playerId
        self.name = name
        self.number = number
        self.inPercentage = inPercentage
        self.points = points
    }
}

/// The court and the bench, as one thing to draw.
public struct Sideline: Equatable, Sendable {
    public var court: [CourtSlot]
    public var bench: [BenchPlayer]

    /// Which match the figures cover, in words.
    public var scopeLabel: String

    /// Nil when no match is in progress: a screen showing an empty court and an empty bench
    /// looks like a team that has nobody, rather than like a match that has not started.
    public init?(state: AppState) {
        guard let view = state.courtView() else { return nil }

        self.court = view.slots
        self.scopeLabel = view.scopeLabel

        let onCourt = Set(view.slots.compactMap(\.playerId))
        let figures = state.currentMatch?.statistics ?? [:]

        self.bench = state.roster
            .filter { !onCourt.contains($0.id) }
            .map { entry in
                BenchPlayer(
                    playerId: entry.id,
                    name: entry.name,
                    number: entry.number,
                    inPercentage: figures[entry.id]?.inPercentage,
                    points: figures[entry.id]?.points
                )
            }
            .sorted(by: benchOrder)
    }
}

/// Jersey order, read as numbers.
///
/// Sorted as text, 21 comes before 9 -- and a bench that reorders itself as the night goes on
/// is a bench nobody can find anybody on. A number that is not a number sorts last rather
/// than crashing: a jersey can be anything somebody wrote on a shirt.
private func benchOrder(_ first: BenchPlayer, _ second: BenchPlayer) -> Bool {
    switch (Int(first.number), Int(second.number)) {
    case let (left?, right?): return left < right
    case (nil, _?): return false
    case (_?, nil): return true
    default: return first.number < second.number
    }
}
