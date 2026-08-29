// Figures across a list of games — one game, a season, or a whole career.
//
// Season and career are the same question asked over different sets, so there is one
// aggregation and three callers. Writing them separately would put the tracked-versus-
// from-paper rule in three places, and that is exactly the rule that must not drift.
import Foundation

/// Per-player figures across several games.
///
/// Serves, serves in, and the percentage span every game. Points and turns exist only where
/// play was tracked serve by serve, so a player with no tracked games gets nil for those —
/// never zero, which would report worse figures than they actually earned.
public struct CareerFigures: Equatable, Sendable {
    public var serves: Int = 0
    public var servesIn: Int = 0
    public var inPercentage: Double?
    public var points: Int?
    public var turnsTaken: Int?
    public var turnsOnCourt: Int?
    public var games: Int = 0
    public var trackedGames: Int = 0

    public init() {}
}

/// How many of a set of games recorded play serve by serve.
///
/// Carried alongside every aggregate so a screen can say which figures the numbers cover,
/// rather than leaving the reader to assume they cover everything.
public struct Coverage: Equatable, Sendable {
    public var totalGames: Int
    public var trackedGames: Int

    public init(totalGames: Int, trackedGames: Int) {
        self.totalGames = totalGames
        self.trackedGames = trackedGames
    }
}

/// Figures per player, and what they cover.
public struct Aggregate: Equatable, Sendable {
    public var byPlayer: [String: CareerFigures]
    public var coverage: Coverage

    public init(byPlayer: [String: CareerFigures], coverage: Coverage) {
        self.byPlayer = byPlayer
        self.coverage = coverage
    }
}

/// Wins, losses, and games left unrecorded. Undecided is counted, never folded into losses.
public struct Record: Equatable, Sendable {
    public var won: Int = 0
    public var lost: Int = 0
    public var undecided: Int = 0

    public init(won: Int = 0, lost: Int = 0, undecided: Int = 0) {
        self.won = won
        self.lost = lost
        self.undecided = undecided
    }
}

/// The two figures tallied by hand at the bottom of every paper sheet.
public struct GameSummary: Equatable, Sendable {
    public var serves: Int
    public var servesIn: Int
    public var topScorer: (playerId: String, servesIn: Int)?
    public var topPercentage: (playerId: String, inPercentage: Double)?

    public static func == (lhs: GameSummary, rhs: GameSummary) -> Bool {
        lhs.serves == rhs.serves
            && lhs.servesIn == rhs.servesIn
            && lhs.topScorer?.playerId == rhs.topScorer?.playerId
            && lhs.topScorer?.servesIn == rhs.topScorer?.servesIn
            && lhs.topPercentage?.playerId == rhs.topPercentage?.playerId
            && lhs.topPercentage?.inPercentage == rhs.topPercentage?.inPercentage
    }
}

/// One player's whole career: each season separately, and everything combined.
public struct CareerSeason: Equatable, Sendable {
    public var seasonId: String
    public var name: String
    public var team: String
    public var number: String?
    public var games: Int
    public var record: Record
    public var figures: CareerFigures?
    public var coverage: Coverage
}

/// One player across every season they appear in.
public struct Career: Equatable, Sendable {
    public var seasons: [CareerSeason]
    public var total: CareerFigures?
    public var coverage: Coverage
}

extension Game {
    /// How a game turned out.
    ///
    /// A tracked game's result follows from its matches; a match ended without a marked
    /// result counts toward neither side, because silence is not a defeat.
    public var result: MatchResult {
        if kind == .historical { return recordedResult }

        let ended = matches.filter { $0.status == .ended }
        let won = ended.filter { $0.result == .won }.count
        let lost = ended.filter { $0.result == .lost }.count

        if won > lost { return .won }
        if lost > won { return .lost }
        return .undecided
    }

    /// Who served most in, and who served most accurately.
    public var summary: GameSummary {
        let byPlayer = aggregate([self]).byPlayer
        guard !byPlayer.isEmpty else {
            return GameSummary(serves: 0, servesIn: 0, topScorer: nil, topPercentage: nil)
        }

        let serves = byPlayer.values.reduce(0) { $0 + $1.serves }
        let servesIn = byPlayer.values.reduce(0) { $0 + $1.servesIn }

        // In the order the players appear in the game -- first to serve, or the order the
        // paper sheet listed them. A tie then resolves to whoever got there first, which
        // is both stable across reads and the same answer the web app gives.
        let ordered = appearanceOrder.compactMap { playerId in
            byPlayer[playerId].map { (key: playerId, value: $0) }
        }
        let scorer = firstMaximum(ordered) { $0.value.servesIn }
        let accurate = firstMaximum(ordered.filter { $0.value.serves > 0 }) {
            $0.value.inPercentage ?? 0
        }

        return GameSummary(
            serves: serves,
            servesIn: servesIn,
            topScorer: scorer.map { (playerId: $0.key, servesIn: $0.value.servesIn) },
            topPercentage: accurate.flatMap { entry in
                entry.value.inPercentage.map { (playerId: entry.key, inPercentage: $0) }
            }
        )
    }

    /// The players of this game in the order they appear in it.
    ///
    /// For a tracked game that is the order they first served; for one copied from paper it
    /// is the order the sheet listed them. It exists so that a tie for top scorer resolves
    /// to whoever got there first rather than to whichever way a dictionary happened to be
    /// ordered on the day.
    var appearanceOrder: [String] {
        var seen: [String] = []
        if kind == .historical {
            for entry in entries where !seen.contains(entry.playerId) {
                seen.append(entry.playerId)
            }
            return seen
        }
        for turn in allTurns where !turn.serves.isEmpty && !seen.contains(turn.playerId) {
            seen.append(turn.playerId)
        }
        return seen
    }

    /// True when the player took any part in the game — served, or was on court.
    public func hasPlayer(_ playerId: String) -> Bool {
        if kind == .historical {
            return entries.contains { $0.playerId == playerId }
        }
        return matches.contains { match in
            match.turns.contains { turn in
                turn.playerId == playerId || (turn.lineupSnapshot ?? []).contains(playerId)
            }
        }
    }
}

/// Wins, losses and undecided games across a list.
public func record(of games: [Game]) -> Record {
    var record = Record()
    for game in games {
        switch game.result {
        case .won: record.won += 1
        case .lost: record.lost += 1
        case .undecided: record.undecided += 1
        }
    }
    return record
}

/// The same record, grouped by who was played.
public func recordByOpponent(_ games: [Game]) -> [String: Record] {
    var byOpponent: [String: [Game]] = [:]
    for game in games {
        let opponent = game.context.opponent.trimmed.isEmpty
            ? "Unnamed opponent"
            : game.context.opponent.trimmed
        byOpponent[opponent, default: []].append(game)
    }
    return byOpponent.mapValues(record(of:))
}

/// Per-player figures across a list of games, and how many of them were tracked.
public func aggregate(_ games: [Game]) -> Aggregate {
    var byPlayer: [String: CareerFigures] = [:]

    for game in games {
        if game.kind == .historical {
            addFromPaper(&byPlayer, game)
        } else {
            addTracked(&byPlayer, game)
        }
    }

    for (playerId, figures) in byPlayer {
        byPlayer[playerId] = finalised(figures)
    }

    return Aggregate(
        byPlayer: byPlayer,
        coverage: Coverage(
            totalGames: games.count,
            trackedGames: games.filter { $0.kind != .historical }.count
        )
    )
}

extension AppState {
    /// Per-player figures for one season.
    public func seasonStatistics(_ seasonId: String) -> Aggregate {
        aggregate(games(inSeason: seasonId))
    }

    /// One player across every season they appear in.
    ///
    /// This is what career identity is for — the same child, two teams, two numbers.
    public func career(of playerId: String) -> Career {
        let perSeason = seasons(forPlayer: playerId).map { season -> CareerSeason in
            let played = games(inSeason: season.id).filter { $0.hasPlayer(playerId) }
            let figures = aggregate(played)
            return CareerSeason(
                seasonId: season.id,
                name: season.name,
                team: season.team,
                number: number(inSeason: season.id, playerId: playerId),
                games: played.count,
                record: record(of: played),
                figures: figures.byPlayer[playerId],
                coverage: figures.coverage
            )
        }

        let everything = aggregate(games(forPlayer: playerId))
        return Career(
            seasons: perSeason,
            total: everything.byPlayer[playerId],
            coverage: everything.coverage
        )
    }
}

// MARK: - Internals

private func addFromPaper(_ byPlayer: inout [String: CareerFigures], _ game: Game) {
    for entry in game.entries {
        var figures = byPlayer[entry.playerId] ?? CareerFigures()
        figures.serves += entry.servesIn + entry.servesOut
        figures.servesIn += entry.servesIn
        figures.games += 1
        byPlayer[entry.playerId] = figures
    }
}

private func addTracked(_ byPlayer: inout [String: CareerFigures], _ game: Game) {
    let turns = game.allTurns
    let served = aggregateTurns(turns)

    for (playerId, stats) in served {
        var figures = byPlayer[playerId] ?? CareerFigures()
        figures.serves += stats.serves
        figures.servesIn += stats.servesIn
        figures.points = (figures.points ?? 0) + stats.points
        figures.turnsTaken = (figures.turnsTaken ?? 0) + stats.turnsTaken
        figures.turnsOnCourt = (figures.turnsOnCourt ?? 0) + turnsOnCourt(turns, playerId: playerId)
        figures.games += 1
        figures.trackedGames += 1
        byPlayer[playerId] = figures
    }

    // Someone on court who never reached the service position still played the game.
    for playerId in onCourt(turns) where served[playerId] == nil {
        var figures = byPlayer[playerId] ?? CareerFigures()
        figures.turnsOnCourt = (figures.turnsOnCourt ?? 0) + turnsOnCourt(turns, playerId: playerId)
        figures.games += 1
        figures.trackedGames += 1
        byPlayer[playerId] = figures
    }
}

private func onCourt(_ turns: [Turn]) -> Set<String> {
    var seen: Set<String> = []
    for turn in turns {
        for playerId in turn.lineupSnapshot ?? [] where !playerId.isEmpty {
            seen.insert(playerId)
        }
    }
    return seen
}

/// A figure that was never recorded is nil, never zero.
///
/// Zero would say the player served and won nothing; nil says the game did not record it.
private func finalised(_ figures: CareerFigures) -> CareerFigures {
    var next = figures
    next.inPercentage = figures.serves == 0
        ? nil
        : Double(figures.servesIn) / Double(figures.serves)

    if figures.trackedGames == 0 {
        next.points = nil
        next.turnsTaken = nil
        next.turnsOnCourt = nil
    } else {
        next.points = figures.points ?? 0
        next.turnsTaken = figures.turnsTaken ?? 0
        next.turnsOnCourt = figures.turnsOnCourt ?? 0
    }
    return next
}

/// The first of the highest-scoring entries.
///
/// Deliberately not `max(by:)`: that leaves a tie to the collection's own order, and the
/// answer to "who is top scorer" must not change between reads or between languages.
private func firstMaximum<Element>(
    _ entries: [Element],
    by score: (Element) -> some Comparable
) -> Element? {
    entries.reduce(nil) { leader, entry in
        guard let leader else { return entry }
        return score(entry) > score(leader) ? entry : leader
    }
}
