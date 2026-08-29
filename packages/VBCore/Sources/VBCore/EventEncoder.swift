// Writing an event back out in the shape the log stores.
//
// The exact counterpart of `EventCodec`, and the two are held together by a round-trip
// test: anything this writes, that must read back as the same event. They also have to
// agree with the shipped web app, because a log written here is opened there.
import Foundation

/// Turns a typed event back into the plain object the log holds.
public enum EventEncoder {
    /// The stored shape of one event, without its identifier — the caller adds that,
    /// because identity belongs to the record of the event rather than to what it says.
    public static func encode(_ kind: Event.Kind) -> RawEvent {
        switch kind {
        case let .createSeason(id, name, team, format):
            [
                "t": .string(EventType.createSeason), "id": .string(id),
                "name": .string(name), "team": .string(team),
                "format": .object([
                    "matchesPerGame": .number(Double(format.matchesPerGame)),
                    "targetScore": .number(Double(format.targetScore)),
                    "playersOnCourt": .number(Double(format.playersOnCourt)),
                ]),
            ]

        case let .renameSeason(id, name, team):
            [
                "t": .string(EventType.renameSeason), "id": .string(id),
                "name": .string(name), "team": .string(team ?? ""),
            ]

        case let .activateSeason(id):
            ["t": .string(EventType.activateSeason), "id": .string(id)]

        case let .addPlayer(id, name, number, seasonId):
            player(EventType.addPlayer, id: id, name: name, number: number, seasonId: seasonId)

        case let .editPlayer(id, name, number, seasonId):
            player(EventType.editPlayer, id: id, name: name, number: number, seasonId: seasonId)

        case let .removePlayer(id, seasonId):
            ["t": .string(EventType.removePlayer), "id": .string(id), "seasonId": season(seasonId)]

        case let .removeFromSeason(playerId, seasonId):
            [
                "t": .string(EventType.removeFromSeason), "playerId": .string(playerId),
                "seasonId": season(seasonId),
            ]

        case let .startGame(id, seasonId, rotatesAtServeLimit):
            [
                "t": .string(EventType.startGame), "id": .string(id),
                "seasonId": season(seasonId),
                "rotatesAtServeLimit": .bool(rotatesAtServeLimit),
            ]

        case let .discardGame(id):
            ["t": .string(EventType.discardGame), "id": .string(id)]

        case let .setGameContext(gameId, gameContext):
            ["t": .string(EventType.setGameContext), "gameId": .string(gameId)]
                .merging(context(gameContext)) { _, new in new }

        case let .setGameNotes(gameId, gameNotes):
            ["t": .string(EventType.setGameNotes), "gameId": .string(gameId)]
                .merging(notes(gameNotes)) { _, new in new }

        case let .setMatchResult(gameId, matchIndex, result):
            [
                "t": .string(EventType.setMatchResult), "gameId": .string(gameId),
                "matchIndex": .number(Double(matchIndex)), "result": resultValue(result),
            ]

        case let .addHistoricalGame(id, seasonId, gameContext, entries, gameNotes, result):
            ([
                "t": .string(EventType.addHistoricalGame), "id": .string(id),
                "seasonId": season(seasonId),
                "entries": .array((entries ?? []).map(entry)),
                "result": resultValue(result),
            ] as RawEvent)
                .merging(context(gameContext)) { _, new in new }
                .merging(notes(gameNotes)) { _, new in new }

        case let .editHistoricalGame(id, gameContext, entries, gameNotes, result):
            ([
                "t": .string(EventType.editHistoricalGame), "id": .string(id),
                "entries": .array((entries ?? []).map(entry)),
                "result": resultValue(result),
            ] as RawEvent)
                .merging(context(gameContext)) { _, new in new }
                .merging(notes(gameNotes)) { _, new in new }

        case let .setLineup(playerIds):
            ["t": .string(EventType.setLineup), "playerIds": .array(playerIds.map { .string($0) })]

        case .clearLineup:
            ["t": .string(EventType.clearLineup)]

        case let .substitute(outPlayerId, inPlayerId):
            [
                "t": .string(EventType.substitute),
                "outPlayerId": .string(outPlayerId), "inPlayerId": .string(inPlayerId),
            ]

        case let .selectServer(playerId):
            ["t": .string(EventType.selectServer), "playerId": .string(playerId)]

        case let .recordServe(outcome):
            ["t": .string(EventType.recordServe), "outcome": .string(outcome?.rawValue ?? "")]

        case let .endMatch(result):
            ["t": .string(EventType.endMatch), "result": resultValue(result)]

        case let .endGame(result):
            ["t": .string(EventType.endGame), "result": resultValue(result)]

        case let .setTurnServes(gameId, matchIndex, ordinal, outcomes):
            [
                "t": .string(EventType.setTurnServes), "gameId": .string(gameId),
                "matchIndex": .number(Double(matchIndex)), "ordinal": .number(Double(ordinal)),
                "outcomes": .array((outcomes ?? []).map { .string($0) }),
            ]

        case let .reassignTurn(gameId, matchIndex, ordinal, playerId):
            [
                "t": .string(EventType.reassignTurn), "gameId": .string(gameId),
                "matchIndex": .number(Double(matchIndex)), "ordinal": .number(Double(ordinal)),
                "playerId": .string(playerId),
            ]

        case let .deleteTurn(gameId, matchIndex, ordinal):
            [
                "t": .string(EventType.deleteTurn), "gameId": .string(gameId),
                "matchIndex": .number(Double(matchIndex)), "ordinal": .number(Double(ordinal)),
            ]

        case let .insertTurn(gameId, matchIndex, afterOrdinal, playerId):
            [
                "t": .string(EventType.insertTurn), "gameId": .string(gameId),
                "matchIndex": .number(Double(matchIndex)),
                "afterOrdinal": .number(Double(afterOrdinal ?? -1)),
                "playerId": .string(playerId),
            ]

        case let .unrecognised(type):
            ["t": .string(type)]
        }
    }

    // MARK: - Pieces

    private static func player(
        _ type: String,
        id: String,
        name: String,
        number: String,
        seasonId: String?
    ) -> RawEvent {
        [
            "t": .string(type), "id": .string(id), "name": .string(name),
            "number": .string(number), "seasonId": season(seasonId),
        ]
    }

    /// An absent season is written as null rather than omitted, so the field is always there
    /// to be read and its absence is a stated fact rather than a gap.
    private static func season(_ seasonId: String?) -> JSONValue {
        seasonId.map { JSONValue.string($0) } ?? .null
    }

    private static func context(_ context: GameContext) -> RawEvent {
        [
            "date": context.date.map { JSONValue.string($0) } ?? .null,
            "opponent": .string(context.opponent),
            "location": .string(context.location),
            "court": .string(context.court),
        ]
    }

    private static func notes(_ notes: GameNotes) -> RawEvent {
        [
            "wentWell": .string(notes.wentWell),
            "needsWork": .string(notes.needsWork),
            "notes": .string(notes.notes),
        ]
    }

    private static func entry(_ entry: RawHistoricalEntry) -> JSONValue {
        .object([
            "playerId": .string(entry.playerId),
            "in": entry.servesIn.map { JSONValue.number(Double($0)) } ?? .null,
            "out": entry.servesOut.map { JSONValue.number(Double($0)) } ?? .null,
        ])
    }

    private static func resultValue(_ result: ResultField) -> JSONValue {
        switch result {
        case .absent: .null
        case let .value(value): .string(value.rawValue)
        case .unrecognised: .string("")
        }
    }
}
