// Anything the app writes, it must be able to read back — and so must the web app.
//
// The encoder and the decoder are two halves of one agreement, and the only way to be sure
// they still agree is to send everything through both.
import Foundation
import Testing

@testable import VBCore

/// Every kind of event, one of each, with values that would show a field being dropped.
private let everyKind: [Event.Kind] = [
    .createSeason(id: "s1", name: "2026", team: "Tigers", format: .standard),
    .renameSeason(id: "s1", name: "2027", team: "Lions"),
    .activateSeason(id: "s1"),
    .addPlayer(id: "p1", name: "Ella", number: "07", seasonId: "s1"),
    .editPlayer(id: "p1", name: "Ella Hatch", number: "12", seasonId: "s1"),
    .removePlayer(id: "p1", seasonId: "s1"),
    .removeFromSeason(playerId: "p1", seasonId: "s1"),
    .startGame(id: "g1", seasonId: "s1", rotatesAtServeLimit: true),
    .discardGame(id: "g1"),
    .setGameContext(
        gameId: "g1",
        context: GameContext(date: "2026-08-29", opponent: "Northside", location: "Eastern", court: "3")
    ),
    .setGameNotes(gameId: "g1", notes: GameNotes(wentWell: "Talking", needsWork: "Serves", notes: "Tough")),
    .setMatchResult(gameId: "g1", matchIndex: 1, result: .value(.won)),
    .addHistoricalGame(
        id: "h1",
        seasonId: "s1",
        context: GameContext(date: "2026-08-08", opponent: "CNE", location: "Felicity", court: "1"),
        entries: [RawHistoricalEntry(playerId: "p1", servesIn: 9, servesOut: 2)],
        notes: GameNotes(wentWell: "In", needsWork: "Out", notes: ""),
        result: .value(.lost)
    ),
    .editHistoricalGame(
        id: "h1",
        context: GameContext(date: "2026-08-08", opponent: "CNE", location: "Felicity", court: "1"),
        entries: [RawHistoricalEntry(playerId: "p1", servesIn: 0, servesOut: 0)],
        notes: GameNotes(),
        result: .value(.won)
    ),
    .setLineup(playerIds: ["p1", "p2", "p3", "p4", "p5", "p6"]),
    .clearLineup,
    .placeInLineup(playerId: "p4", lineupIndex: 2),
    .clearLineupPosition(lineupIndex: 5),
    .substitute(outPlayerId: "p3", inPlayerId: "p7"),
    .selectServer(playerId: "p1"),
    .recordServe(outcome: .inNoPoint),
    .endMatch(result: .value(.lost)),
    .endGame(result: .value(.undecided)),
    .setTurnServes(gameId: "g1", matchIndex: 2, ordinal: 4, outcomes: ["IN_POINT", "OUT"]),
    .reassignTurn(gameId: "g1", matchIndex: 0, ordinal: 1, playerId: "p2"),
    .deleteTurn(gameId: "g1", matchIndex: 1, ordinal: 3),
    .insertTurn(gameId: "g1", matchIndex: 2, afterOrdinal: 6, playerId: "p4"),
]

@Suite("Writing an event and reading it back")
struct EventEncoderTests {
    @Test("Every kind of event survives the round trip unchanged", arguments: everyKind)
    func roundTrips(kind: Event.Kind) throws {
        var stored = EventEncoder.encode(kind)
        stored["eventId"] = "e1"

        let read = try #require(Event(raw: stored))
        #expect(read.id == "e1")
        #expect(read.kind == kind)
    }

    @Test("Every kind writes a type the reducer recognises")
    func writesKnownTypes() {
        for kind in everyKind {
            let type = EventEncoder.encode(kind)["t"]?.stringValue
            #expect(type?.isEmpty == false, "no type written for \(kind)")

            var stored = EventEncoder.encode(kind)
            stored["eventId"] = "e1"
            if case .unrecognised = Event(raw: stored)?.kind {
                Issue.record("\(kind) writes a type the reader does not know")
            }
        }
    }

    @Test("A result that was never stated stays unstated")
    func keepsAbsenceAbsent() throws {
        var stored = EventEncoder.encode(.endMatch(result: .absent))
        stored["eventId"] = "e1"

        let read = try #require(Event(raw: stored))
        #expect(read.kind == .endMatch(result: .absent), "absent is not the same as undecided")
    }

    @Test("A whole log written here replays to the same state it came from")
    func wholeLogRoundTrips() {
        let events = [
            Event(id: "a", kind: .addPlayer(id: "p1", name: "Ella", number: "7", seasonId: nil)),
            Event(id: "b", kind: .addPlayer(id: "p2", name: "Aria", number: "5", seasonId: nil)),
            Event(id: "c", kind: .startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true)),
            Event(id: "d", kind: .selectServer(playerId: "p1")),
            Event(id: "e", kind: .recordServe(outcome: .inPoint)),
            Event(id: "f", kind: .recordServe(outcome: .out)),
            Event(id: "g", kind: .endMatch(result: .value(.won))),
        ]

        let stored = events.map { event -> RawEvent in
            var raw = EventEncoder.encode(event.kind)
            raw["eventId"] = .string(event.id)
            return raw
        }

        #expect(replay(raw: stored) == replay(events))
    }

    @Test("What this writes, the backup format carries, and reads back the same")
    func survivesABackup() {
        // The route a season takes to the web app and back. If the encoder drops a field,
        // this is where a real record would quietly lose it.
        let stored = everyKind.enumerated().map { index, kind -> RawEvent in
            var raw = EventEncoder.encode(kind)
            raw["eventId"] = .string("e\(index)")
            return raw
        }

        let text = buildBackup(stored, exportedAt: "2026-08-29T18:04:11.000Z")
        let read = readBackup(text).log

        #expect(read?.events == stored)
    }
}

extension Event.Kind: CustomTestStringConvertible {
    public var testDescription: String {
        EventEncoder.encode(self)["t"]?.stringValue ?? "unknown"
    }
}
