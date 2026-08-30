// The event log's vocabulary: what can be recorded, and what each record carries.
//
// An event is a fact about something that happened. Its meaning comes from its position in
// the log, never from ambient state read at the time it was built -- which is why a rule
// that changes behaviour is written INTO the event (see `startGame`'s
// `rotatesAtServeLimit`) rather than read from the code that replays it. A rule read from
// the code applies backwards, and silently moves serves in games already recorded.
import Foundation

/// The three outcomes a serve can have. Nothing else is a valid outcome.
public enum Outcome: String, Codable, Sendable, CaseIterable {
    case out = "OUT"
    case inNoPoint = "IN_NO_POINT"
    case inPoint = "IN_POINT"

    /// True when the serve landed in, whether or not it won the rally.
    public var isIn: Bool { self != .out }
}

/// How a match ended. Silence is not a defeat, so an unmarked match is undecided.
public enum MatchResult: String, Codable, Sendable, CaseIterable {
    case won
    case lost
    case undecided
}

/// How a game was recorded: serve by serve, or as figures copied from paper.
public enum GameKind: String, Codable, Sendable {
    case tracked
    case historical
}

/// Whether a match is still being played.
public enum MatchStatus: String, Codable, Sendable {
    case inProgress = "in_progress"
    case ended
}

/// A roster may never hold more than this many players.
public let maxRoster = 20

/// A game is exactly this many matches.
public let matchesPerGame = 3

/// Players on court, and therefore positions in the serving order.
public let lineupSize = 6

/// The league expects a server to rotate out after this many consecutive serves.
///
/// It ends a turn; it never discards a serve. A referee who miscounts and lets someone
/// serve again is recorded by choosing that player once more, which is a second turn -- the
/// serves are all kept either way.
public let serveLimit = 5

/// The format a season is played under, recorded with the season so a later release can
/// vary it without changing stored data.
public struct SeasonFormat: Equatable, Codable, Sendable {
    public var matchesPerGame: Int
    public var targetScore: Int
    public var playersOnCourt: Int

    public init(matchesPerGame: Int = VBCore.matchesPerGame, targetScore: Int = 21, playersOnCourt: Int = lineupSize) {
        self.matchesPerGame = matchesPerGame
        self.targetScore = targetScore
        self.playersOnCourt = playersOnCourt
    }

    /// The format every season recorded so far was played under.
    public static let standard = SeasonFormat()
}

/// A result field as it arrives, which is three states rather than two.
///
/// Absent and unrecognised are not the same thing. Ending a match without saying how it
/// went is allowed and means undecided; ending it with a word this app does not know is a
/// corrupt event and is refused. Collapsing both to nil would quietly accept the second.
public enum ResultField: Equatable, Sendable {
    case absent
    case value(MatchResult)
    case unrecognised

    /// The result to record, treating an unstated one as undecided.
    public var recorded: MatchResult {
        if case let .value(result) = self { return result }
        return .undecided
    }

    /// True when a word arrived that this app does not recognise.
    public var isUnrecognised: Bool { self == .unrecognised }
}

/// Who, where, on which court, and when.
public struct GameContext: Equatable, Sendable {
    public var date: String?
    public var opponent: String
    public var location: String
    public var court: String

    public init(date: String? = nil, opponent: String = "", location: String = "", court: String = "") {
        self.date = date
        self.opponent = opponent
        self.location = location
        self.court = court
    }
}

/// The three things a scoresheet actually carries.
///
/// Every paper sheet keeps "what went well" and "what to work on" as separate lists, which
/// says more about how the record is used than one free-text box could. `notes` holds
/// remarks belonging to neither -- and everything already written into it.
public struct GameNotes: Equatable, Sendable {
    public var wentWell: String
    public var needsWork: String
    public var notes: String

    public init(wentWell: String = "", needsWork: String = "", notes: String = "") {
        self.wentWell = wentWell
        self.needsWork = needsWork
        self.notes = notes
    }
}

/// One player's figures in a game copied from paper: serves in and out, and nothing else,
/// because nothing else was written down.
public struct HistoricalEntry: Equatable, Sendable {
    public var playerId: String
    public var servesIn: Int
    public var servesOut: Int

    public init(playerId: String, servesIn: Int, servesOut: Int) {
        self.playerId = playerId
        self.servesIn = servesIn
        self.servesOut = servesOut
    }
}

/// A figure as it arrived, before anything has checked it.
///
/// A count that is not a whole number is a corrupt event and must be refused with a
/// message that says so. Decoding it to zero would accept the corruption and report that
/// the player served nothing, which is a different and worse kind of wrong.
public struct RawHistoricalEntry: Equatable, Sendable {
    public var playerId: String
    public var servesIn: Int?
    public var servesOut: Int?

    public init(playerId: String, servesIn: Int?, servesOut: Int?) {
        self.playerId = playerId
        self.servesIn = servesIn
        self.servesOut = servesOut
    }

    /// The checked figure, or nil when either count was not a whole number.
    public var checked: HistoricalEntry? {
        guard let servesIn, let servesOut else { return nil }
        return HistoricalEntry(playerId: playerId, servesIn: servesIn, servesOut: servesOut)
    }
}

/// Everything that can be recorded.
///
/// The identifier is carried alongside the event rather than inside each case: it belongs
/// to the record of the event, not to what the event says. It is assigned once, on the
/// device where the event was created, and is what makes delivery between two devices
/// exactly-once rather than merely reliable.
public struct Event: Equatable, Sendable {
    public var id: String
    public var kind: Kind

    public init(id: String, kind: Kind) {
        self.id = id
        self.kind = kind
    }

    /// What happened.
    public enum Kind: Equatable, Sendable {
        // Seasons
        case createSeason(id: String, name: String, team: String, format: SeasonFormat)
        case renameSeason(id: String, name: String, team: String?)
        case activateSeason(id: String)

        // Players and rosters
        case addPlayer(id: String, name: String, number: String, seasonId: String?)
        case editPlayer(id: String, name: String, number: String, seasonId: String?)
        case removePlayer(id: String, seasonId: String?)
        case removeFromSeason(playerId: String, seasonId: String?)

        // Games
        case startGame(id: String, seasonId: String?, rotatesAtServeLimit: Bool)
        case discardGame(id: String)
        case setGameContext(gameId: String, context: GameContext)
        case setGameNotes(gameId: String, notes: GameNotes)
        case setMatchResult(gameId: String, matchIndex: Int, result: ResultField)
        case addHistoricalGame(
            id: String,
            seasonId: String?,
            context: GameContext,
            entries: [RawHistoricalEntry]?,
            notes: GameNotes,
            result: ResultField
        )
        case editHistoricalGame(
            id: String,
            context: GameContext,
            entries: [RawHistoricalEntry]?,
            notes: GameNotes,
            result: ResultField
        )

        // The match in progress
        case setLineup(playerIds: [String])

        /// Puts one player at one place in the serving order, leaving the rest alone.
        ///
        /// Its own event rather than a rewritten `setLineup` so that one undo takes back
        /// one tap: an operator building the rotation six taps before the whistle needs to
        /// step back one placement, not lose the five before it.
        case placeInLineup(playerId: String, lineupIndex: Int)

        /// Empties one place in the serving order.
        case clearLineupPosition(lineupIndex: Int)

        case clearLineup
        case substitute(outPlayerId: String, inPlayerId: String)
        case selectServer(playerId: String)
        case recordServe(outcome: Outcome?)
        case endMatch(result: ResultField)
        case endGame(result: ResultField)

        // Corrections to a game already recorded
        // The outcomes arrive as they were written, not as this app would like them: a
        // list that is absent, empty, or holds a word we do not know are three different
        // mistakes with three different messages.
        case setTurnServes(gameId: String, matchIndex: Int, ordinal: Int, outcomes: [String]?)
        case reassignTurn(gameId: String, matchIndex: Int, ordinal: Int, playerId: String)
        case deleteTurn(gameId: String, matchIndex: Int, ordinal: Int)
        case insertTurn(gameId: String, matchIndex: Int, afterOrdinal: Int?, playerId: String)

        /// An event this build does not understand. Replay ignores it, exactly as the web
        /// app's reducer ignores an unrecognised type, rather than refusing to start.
        case unrecognised(type: String)
    }
}
