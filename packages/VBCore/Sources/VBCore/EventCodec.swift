// The boundary between the log as it is written and the events the rulebook reads.
//
// Decoding happens once, here. Everything past this file works in types; everything before
// it works in values. Nothing is coerced on the way through -- a count that is not a whole
// number arrives as "not a whole number" rather than as zero, because the difference is
// what tells a corrupt event from a player who served nothing.
import Foundation

/// The type tags as they appear in the log. They are the format of record and must not be
/// renamed: a season recorded by the shipped web app is written in them.
public enum EventType {
    public static let addPlayer = "ADD_PLAYER"
    public static let editPlayer = "EDIT_PLAYER"
    public static let removePlayer = "REMOVE_PLAYER"
    public static let removeFromSeason = "REMOVE_FROM_SEASON"
    public static let createSeason = "CREATE_SEASON"
    public static let renameSeason = "RENAME_SEASON"
    public static let activateSeason = "ACTIVATE_SEASON"
    public static let discardSeason = "DISCARD_SEASON"
    public static let startGame = "START_GAME"
    public static let discardGame = "DISCARD_GAME"
    public static let setGameContext = "SET_GAME_CONTEXT"
    public static let setGameNotes = "SET_GAME_NOTES"
    public static let setMatchResult = "SET_MATCH_RESULT"
    public static let setTurnServes = "SET_TURN_SERVES"
    public static let reassignTurn = "REASSIGN_TURN"
    public static let deleteTurn = "DELETE_TURN"
    public static let insertTurn = "INSERT_TURN"
    public static let addHistoricalGame = "ADD_HISTORICAL_GAME"
    public static let editHistoricalGame = "EDIT_HISTORICAL_GAME"
    public static let setLineup = "SET_LINEUP"
    public static let clearLineup = "CLEAR_LINEUP"
    public static let placeInLineup = "PLACE_IN_LINEUP"
    public static let clearLineupPosition = "CLEAR_LINEUP_POSITION"
    public static let substitute = "SUBSTITUTE"
    public static let selectServer = "SELECT_SERVER"
    public static let recordServe = "RECORD_SERVE"
    public static let endMatch = "END_MATCH"
    public static let endGame = "END_GAME"
}

/// An event as it sits in the log: a plain object, with whatever fields it was written with.
public typealias RawEvent = [String: JSONValue]

extension Event {
    /// Reads one raw event.
    ///
    /// Returns nil only when there is no type tag at all, which is not an event. An
    /// unfamiliar tag decodes as `.unrecognised` and is ignored by replay, exactly as the
    /// web app's reducer ignores one — a log holding something newer than this build must
    /// still open.
    public init?(raw: RawEvent) {
        guard let type = raw["t"]?.stringValue else { return nil }

        // `eventId`, not `id`: several event types already use `id` for the thing they are
        // about -- the player added, the game started -- and a collision there would
        // silently rewrite a season recorded by the web app. An event with no identifier
        // is one the web app wrote, and is given one at import.
        self.init(id: raw["eventId"]?.stringValue ?? "", kind: Kind(type: type, raw: raw))
    }
}

extension Event.Kind {
    // swiftlint:disable:next cyclomatic_complexity
    fileprivate init(type: String, raw: RawEvent) {
        switch type {
        case EventType.createSeason:
            self = .createSeason(
                id: raw.string("id"),
                name: raw.string("name"),
                team: raw.string("team"),
                format: raw.format("format")
            )

        case EventType.renameSeason:
            self = .renameSeason(id: raw.string("id"), name: raw.string("name"), team: raw.optionalString("team"))

        case EventType.activateSeason:
            self = .activateSeason(id: raw.string("id"))

        case EventType.discardSeason:
            self = .discardSeason(id: raw.string("id"))

        case EventType.addPlayer:
            self = .addPlayer(
                id: raw.string("id"),
                name: raw.string("name"),
                number: raw.string("number"),
                seasonId: raw.optionalString("seasonId")
            )

        case EventType.editPlayer:
            self = .editPlayer(
                id: raw.string("id"),
                name: raw.string("name"),
                number: raw.string("number"),
                seasonId: raw.optionalString("seasonId")
            )

        case EventType.removePlayer:
            self = .removePlayer(id: raw.string("id"), seasonId: raw.optionalString("seasonId"))

        case EventType.removeFromSeason:
            self = .removeFromSeason(
                playerId: raw.string("playerId"),
                seasonId: raw.optionalString("seasonId")
            )

        case EventType.startGame:
            // Absent on games recorded before the rule existed, which is exactly the
            // point: those games replay as they always did.
            self = .startGame(
                id: raw.string("id"),
                seasonId: raw.optionalString("seasonId"),
                rotatesAtServeLimit: raw["rotatesAtServeLimit"]?.boolValue == true
            )

        case EventType.discardGame:
            self = .discardGame(id: raw.string("id"))

        case EventType.setGameContext:
            self = .setGameContext(gameId: raw.string("gameId"), context: raw.context())

        case EventType.setGameNotes:
            self = .setGameNotes(gameId: raw.string("gameId"), notes: raw.notes())

        case EventType.setMatchResult:
            self = .setMatchResult(
                gameId: raw.string("gameId"),
                matchIndex: raw.int("matchIndex") ?? -1,
                result: raw.result("result")
            )

        case EventType.addHistoricalGame:
            self = .addHistoricalGame(
                id: raw.string("id"),
                seasonId: raw.optionalString("seasonId"),
                context: raw.context(),
                entries: raw.entries(),
                notes: raw.notes(),
                result: raw.result("result")
            )

        case EventType.editHistoricalGame:
            self = .editHistoricalGame(
                id: raw.string("id"),
                context: raw.context(),
                entries: raw.entries(),
                notes: raw.notes(),
                result: raw.result("result")
            )

        case EventType.setLineup:
            self = .setLineup(playerIds: raw.strings("playerIds") ?? [])

        case EventType.clearLineup:
            self = .clearLineup

        case EventType.placeInLineup:
            self = .placeInLineup(
                playerId: raw.string("playerId"),
                lineupIndex: raw.int("lineupIndex") ?? -1
            )

        case EventType.clearLineupPosition:
            self = .clearLineupPosition(lineupIndex: raw.int("lineupIndex") ?? -1)

        case EventType.substitute:
            self = .substitute(outPlayerId: raw.string("outPlayerId"), inPlayerId: raw.string("inPlayerId"))

        case EventType.selectServer:
            self = .selectServer(playerId: raw.string("playerId"))

        case EventType.recordServe:
            self = .recordServe(outcome: raw["outcome"]?.stringValue.flatMap(Outcome.init(rawValue:)))

        case EventType.endMatch:
            self = .endMatch(result: raw.result("result"))

        case EventType.endGame:
            self = .endGame(result: raw.result("result"))

        case EventType.setTurnServes:
            self = .setTurnServes(
                gameId: raw.string("gameId"),
                matchIndex: raw.int("matchIndex") ?? -1,
                ordinal: raw.int("ordinal") ?? -1,
                outcomes: raw.strings("outcomes")
            )

        case EventType.reassignTurn:
            self = .reassignTurn(
                gameId: raw.string("gameId"),
                matchIndex: raw.int("matchIndex") ?? -1,
                ordinal: raw.int("ordinal") ?? -1,
                playerId: raw.string("playerId")
            )

        case EventType.deleteTurn:
            self = .deleteTurn(
                gameId: raw.string("gameId"),
                matchIndex: raw.int("matchIndex") ?? -1,
                ordinal: raw.int("ordinal") ?? -1
            )

        case EventType.insertTurn:
            self = .insertTurn(
                gameId: raw.string("gameId"),
                matchIndex: raw.int("matchIndex") ?? -1,
                afterOrdinal: raw.int("afterOrdinal"),
                playerId: raw.string("playerId")
            )

        default:
            self = .unrecognised(type: type)
        }
    }
}

// MARK: - Reading fields

extension [String: JSONValue] {
    /// A string field, or the empty string. Absent and empty behave alike everywhere the
    /// rules care, and both are refused where a name is required.
    fileprivate func string(_ key: String) -> String {
        self[key]?.stringValue ?? ""
    }

    /// A string field that may legitimately be absent, where absence means something.
    fileprivate func optionalString(_ key: String) -> String? {
        self[key]?.stringValue
    }

    fileprivate func int(_ key: String) -> Int? {
        self[key]?.intValue
    }

    fileprivate func strings(_ key: String) -> [String]? {
        guard let values = self[key]?.arrayValue else { return nil }
        return values.map { $0.stringValue ?? "" }
    }

    fileprivate func result(_ key: String) -> ResultField {
        guard let raw = self[key] else { return .absent }
        if raw.isNull { return .absent }
        guard let name = raw.stringValue, let result = MatchResult(rawValue: name) else {
            return .unrecognised
        }
        return .value(result)
    }

    fileprivate func context() -> GameContext {
        GameContext(
            date: self["date"]?.stringValue,
            opponent: string("opponent"),
            location: string("location"),
            court: string("court")
        )
    }

    fileprivate func notes() -> GameNotes {
        GameNotes(wentWell: string("wentWell"), needsWork: string("needsWork"), notes: string("notes"))
    }

    fileprivate func entries() -> [RawHistoricalEntry]? {
        guard let values = self["entries"]?.arrayValue else { return nil }
        return values.map { value in
            let fields = value.objectValue ?? [:]
            return RawHistoricalEntry(
                playerId: fields.string("playerId"),
                servesIn: fields["in"]?.intValue,
                servesOut: fields["out"]?.intValue
            )
        }
    }

    /// The season format, taking the standard value for anything the event did not state.
    fileprivate func format(_ key: String) -> SeasonFormat {
        let fields = self[key]?.objectValue ?? [:]
        let standard = SeasonFormat.standard
        return SeasonFormat(
            matchesPerGame: fields["matchesPerGame"]?.intValue ?? standard.matchesPerGame,
            targetScore: fields["targetScore"]?.intValue ?? standard.targetScore,
            playersOnCourt: fields["playersOnCourt"]?.intValue ?? standard.playersOnCourt
        )
    }
}
