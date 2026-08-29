// Derived statistics. Nothing here is ever stored.
//
// Every figure is computed from the recorded serves on read, which is why an undo cannot
// leave a total out of step with the record underneath it.
import Foundation

/// The score a match is played to. Reaching it is advisory only — see `hasReachedTarget`.
public let targetScore = 21

/// Serves, serves in, points, and in-percentage.
///
/// `inPercentage` is nil rather than zero when nothing was served: a player who has not
/// served has no percentage, and reporting 0% would say they served and missed.
public struct Figures: Equatable, Sendable {
    public var serves: Int
    public var servesIn: Int
    public var points: Int
    public var turnsTaken: Int
    public var inPercentage: Double?

    public init(serves: Int = 0, servesIn: Int = 0, points: Int = 0, turnsTaken: Int = 0) {
        self.serves = serves
        self.servesIn = servesIn
        self.points = points
        self.turnsTaken = turnsTaken
        self.inPercentage = serves == 0 ? nil : Double(servesIn) / Double(serves)
    }
}

extension Turn {
    /// Serves, serves in, points and in-percentage for this single serve turn.
    public var figures: Figures {
        Figures(
            serves: serves.count,
            servesIn: serves.filter(\.outcome.isIn).count,
            points: serves.filter { $0.outcome == .inPoint }.count,
            turnsTaken: 1
        )
    }

    /// True when the turn ran past the expected rotation limit — usually a referee
    /// miscount. Nothing is capped; the extra serves are all recorded.
    public var isOverServeLimit: Bool {
        serves.count > serveLimit
    }
}

extension Match {
    /// Per-player figures for this match, keyed by player id.
    public var statistics: [String: Figures] {
        aggregateTurns(turns)
    }

    /// The match score as this app can know it: points earned on serve.
    ///
    /// The opponent's score is deliberately not tracked, so this is not the full
    /// rally-scoring total.
    public var score: Int {
        turns.reduce(0) { $0 + $1.figures.points }
    }

    /// True when points on serve have reached the target.
    ///
    /// Advisory only: the opponent's score is not tracked, so the app cannot know whether
    /// the two-point margin has been met. The operator ends the match from the scoreboard.
    public func hasReachedTarget(_ target: Int = targetScore) -> Bool {
        score >= target
    }
}

extension Game {
    /// Per-player figures across every match of this game, keyed by player id.
    public var statistics: [String: Figures] {
        aggregateTurns(allTurns)
    }
}

/// How many serve turns elapsed while this player was on court, whether or not they served.
///
/// Read from each turn's lineup snapshot rather than folded from substitution history: it
/// distinguishes a player who sat the match out from one who was on court the whole time
/// and simply never reached the service position.
public func turnsOnCourt(_ turns: [Turn], playerId: String) -> Int {
    turns
        .filter { !$0.serves.isEmpty }
        .filter { ($0.lineupSnapshot ?? []).contains(playerId) }
        .count
}

/// Figures per player over a list of turns.
///
/// Turns that recorded nothing are left out. A turn opened by a server selection or by the
/// rotation holds no serves until one is recorded; counting it would put a player on the
/// table with nothing to their name, and credit them a turn they have not taken.
func aggregateTurns(_ turns: [Turn]) -> [String: Figures] {
    var byPlayer: [String: Figures] = [:]

    for turn in turns where !turn.serves.isEmpty {
        let figures = turn.figures
        var running = byPlayer[turn.playerId] ?? Figures()
        running.serves += figures.serves
        running.servesIn += figures.servesIn
        running.points += figures.points
        running.turnsTaken += 1
        byPlayer[turn.playerId] = running
    }

    for (playerId, figures) in byPlayer {
        var finalised = figures
        finalised.inPercentage = figures.serves == 0
            ? nil
            : Double(figures.servesIn) / Double(figures.serves)
        byPlayer[playerId] = finalised
    }
    return byPlayer
}
