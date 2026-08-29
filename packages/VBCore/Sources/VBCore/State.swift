// The shape the log replays into.
//
// None of this is stored. It is rebuilt from the event log every time, which is what makes
// undo a matter of dropping an event rather than of knowing how to reverse one. Every type
// here is a value type for the same reason: nothing is mutated in place, so a state handed
// to a view cannot change underneath it.
import Foundation

/// A person, who outlives any roster, team or season.
///
/// There is deliberately no jersey number here. A number belongs to a season membership,
/// because next season the same child may wear a different one for a different team. This
/// is the one thing in the model that cannot be retrofitted.
public struct Player: Equatable, Sendable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// A player's place on one season's roster, and the number they wore that season.
public struct SeasonMember: Equatable, Sendable {
    public var playerId: String
    public var number: String

    public init(playerId: String, number: String) {
        self.playerId = playerId
        self.number = number
    }
}

/// A named season, for a named team, played under a recorded format.
public struct Season: Equatable, Sendable {
    public var id: String
    public var name: String
    public var team: String
    public var format: SeasonFormat
    public var members: [SeasonMember]

    public init(
        id: String,
        name: String,
        team: String,
        format: SeasonFormat = .standard,
        members: [SeasonMember] = []
    ) {
        self.id = id
        self.name = name
        self.team = team
        self.format = format
        self.members = members
    }
}

/// A player on the active season's roster: who they are, and this season's number.
public struct RosterEntry: Equatable, Sendable {
    public var id: String
    public var name: String
    public var number: String

    public init(id: String, name: String, number: String) {
        self.id = id
        self.name = name
        self.number = number
    }
}

/// One serve, and the only thing ever recorded about it.
public struct Serve: Equatable, Sendable {
    public var outcome: Outcome

    public init(outcome: Outcome) {
        self.outcome = outcome
    }
}

/// One player's turn at serving.
public struct Turn: Equatable, Sendable {
    public var playerId: String
    public var ordinal: Int
    public var colorIndex: Int

    /// The rotation position this turn consumed, or nil where there is no order to consume
    /// from — and for a turn added as a correction, which must not move who serves next.
    public var lineupPosition: Int?

    /// True when the referee let someone outside the order take the ball.
    public var isOffLineup: Bool

    /// Who was on court when this turn was taken. This is what makes "time on court"
    /// answerable at all, and it distinguishes a player who sat out from one who was on
    /// court the whole match and never reached the service position.
    public var lineupSnapshot: [String]?

    public var serves: [Serve]

    /// True while this turn is still accepting serves. At most one per match.
    public var isOpen: Bool

    public init(
        playerId: String,
        ordinal: Int,
        colorIndex: Int,
        lineupPosition: Int? = nil,
        isOffLineup: Bool = false,
        lineupSnapshot: [String]? = nil,
        serves: [Serve] = [],
        isOpen: Bool = true
    ) {
        self.playerId = playerId
        self.ordinal = ordinal
        self.colorIndex = colorIndex
        self.lineupPosition = lineupPosition
        self.isOffLineup = isOffLineup
        self.lineupSnapshot = lineupSnapshot
        self.serves = serves
        self.isOpen = isOpen
    }
}

/// One player replacing another, at that player's exact position in the order.
public struct Substitution: Equatable, Sendable {
    public var outPlayerId: String
    public var inPlayerId: String
    public var position: Int
    public var afterTurnOrdinal: Int

    public init(outPlayerId: String, inPlayerId: String, position: Int, afterTurnOrdinal: Int) {
        self.outPlayerId = outPlayerId
        self.inPlayerId = inPlayerId
        self.position = position
        self.afterTurnOrdinal = afterTurnOrdinal
    }
}

/// One match of a game.
public struct Match: Equatable, Sendable {
    public var index: Int
    public var status: MatchStatus
    public var result: MatchResult

    /// The six on court in serving order, or nil when each server is picked by hand.
    /// A slot can be nil where a player was removed from the roster mid-match.
    public var lineup: [String?]?

    public var substitutions: [Substitution]
    public var turns: [Turn]

    public init(
        index: Int,
        status: MatchStatus = .inProgress,
        result: MatchResult = .undecided,
        lineup: [String?]? = nil,
        substitutions: [Substitution] = [],
        turns: [Turn] = []
    ) {
        self.index = index
        self.status = status
        self.result = result
        self.lineup = lineup
        self.substitutions = substitutions
        self.turns = turns
    }

    /// The serve turn accepting serves right now, or nil between servers.
    public var openTurn: Turn? {
        turns.first { $0.isOpen }
    }
}

/// A game: either tracked serve by serve, or copied from paper.
///
/// The two kinds share their context and notes and differ in what was recorded. A game
/// from paper has no matches and no turns because that detail was never written down;
/// synthesising them would report turns that never happened.
public struct Game: Equatable, Sendable {
    public var id: String
    public var seasonId: String
    public var kind: GameKind
    public var context: GameContext
    public var notes: GameNotes

    /// Tracked games only.
    public var matches: [Match]

    /// Whether the league's serve limit ends a turn in this game.
    ///
    /// Read from the event that started the game, never from the code. A rule read from the
    /// code would apply to games already recorded and silently move their serves.
    public var rotatesAtServeLimit: Bool

    /// Games from paper only: serves in and out, per player, at game level.
    public var entries: [HistoricalEntry]

    /// Games from paper only. A tracked game's result is derived from its matches.
    public var recordedResult: MatchResult

    public init(
        id: String,
        seasonId: String,
        kind: GameKind,
        context: GameContext = GameContext(),
        notes: GameNotes = GameNotes(),
        matches: [Match] = [],
        rotatesAtServeLimit: Bool = false,
        entries: [HistoricalEntry] = [],
        recordedResult: MatchResult = .undecided
    ) {
        self.id = id
        self.seasonId = seasonId
        self.kind = kind
        self.context = context
        self.notes = notes
        self.matches = matches
        self.rotatesAtServeLimit = rotatesAtServeLimit
        self.entries = entries
        self.recordedResult = recordedResult
    }

    /// Every turn in the game, across every match.
    public var allTurns: [Turn] {
        matches.flatMap(\.turns)
    }
}

/// Everything the log replays into.
public struct State: Equatable, Sendable {
    public var players: [Player]
    public var seasons: [Season]
    public var activeSeasonId: String?
    public var games: [Game]
    public var currentGameId: String?

    /// The active season's members, with their names and that season's numbers.
    ///
    /// Recomputed on every change and never stored. A number resolved through a season is
    /// the whole point of release 003, and a cached copy is exactly how it would drift.
    public var roster: [RosterEntry]

    /// The state of an application that has recorded nothing.
    public init(
        players: [Player] = [],
        seasons: [Season] = [],
        activeSeasonId: String? = nil,
        games: [Game] = [],
        currentGameId: String? = nil,
        roster: [RosterEntry] = []
    ) {
        self.players = players
        self.seasons = seasons
        self.activeSeasonId = activeSeasonId
        self.games = games
        self.currentGameId = currentGameId
        self.roster = roster
    }
}
