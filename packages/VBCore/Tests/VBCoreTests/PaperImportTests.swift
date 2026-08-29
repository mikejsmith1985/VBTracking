// Reading a batch of games copied from paper.
//
// Ported from `tests/unit/historical-import.test.js`, including the case that actually
// happened: the operator built the roster with first names only, and the file was written
// with full ones.
import Foundation
import Testing

@testable import VBCore

private let season = Season(id: "s1", name: "2026", team: "Tigers")

private func members(_ pairs: [(String, String, String)]) -> [RosterEntry] {
    pairs.map { RosterEntry(id: $0.0, name: $0.1, number: $0.2) }
}

private let firstNamesOnly = members([
    ("p1", "Layna", "1"),
    ("p2", "Tegan", "4"),
    ("p3", "Aria", "5"),
])

/// A file as the operator's prepared batch is written.
private func file(
    app: String = paperImportMarker,
    kind: String = paperImportKind,
    roster: [(name: String, number: String)] = [],
    games: [JSONValue]
) -> String {
    var payload: [String: JSONValue] = [
        "app": .string(app),
        "kind": .string(kind),
        "games": .array(games),
    ]
    if !roster.isEmpty {
        payload["season"] = .object([
            "roster": .array(roster.map { .object(["name": .string($0.name), "number": .string($0.number)]) })
        ])
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = (try? encoder.encode(JSONValue.object(payload))) ?? Data()
    return String(data: data, encoding: .utf8) ?? ""
}

private func game(
    opponent: String = "Georgetown A",
    serves: [(name: String, servesIn: Int, servesOut: Int)],
    result: String? = nil
) -> JSONValue {
    var fields: [String: JSONValue] = [
        "opponent": .string(opponent),
        "date": "2026-08-08",
        "serves": .array(
            serves.map {
                .object([
                    "name": .string($0.name),
                    "in": .number(Double($0.servesIn)),
                    "out": .number(Double($0.servesOut)),
                ])
            }
        ),
    ]
    if let result { fields["result"] = .string(result) }
    return .object(fields)
}

/// Identifiers a test can predict. Tests run in parallel, so a shared counter would be
/// both unsafe and unrepeatable; a fresh value each call is all any of these need.
private func makeId() -> String {
    UUID().uuidString
}

@Suite("Reading a batch of games from paper")
struct PaperImportTests {
    @Test("A prepared batch becomes one event per game")
    func readsABatch() {
        let text = file(games: [
            game(serves: [("Layna", 5, 2)]),
            game(opponent: "Blanchester", serves: [("Aria", 9, 1)]),
        ])
        let result = parsePaperGames(text, season: season, members: firstNamesOnly, makeId: makeId)

        #expect(result.events?.count == 2)
    }

    @Test("Something that is not JSON is refused")
    func refusesNonJSON() {
        let result = parsePaperGames("not a file", season: season, members: firstNamesOnly, makeId: makeId)
        #expect(result.reason?.contains("not readable") == true)
    }

    @Test("A file that is not a game import is refused, even if it is one of ours")
    func refusesWrongKind() {
        let text = file(kind: "something-else", games: [game(serves: [("Layna", 1, 0)])])
        let result = parsePaperGames(text, season: season, members: firstNamesOnly, makeId: makeId)

        #expect(result.reason?.contains("not a Serve Tracker game import") == true)
    }

    @Test("A file with no games in it is refused")
    func refusesEmptyFile() {
        let result = parsePaperGames(file(games: []), season: season, members: firstNamesOnly, makeId: makeId)
        #expect(result.reason?.contains("holds no games") == true)
    }

    @Test("Importing before a season exists is refused, and says what to do")
    func refusesWithoutASeason() {
        let text = file(games: [game(serves: [("Layna", 1, 0)])])
        let result = parsePaperGames(text, season: nil, members: [], makeId: makeId)

        #expect(result.reason?.contains("Create a season") == true)
    }

    @Test("A game with no figures is refused, and named so it can be found")
    func refusesGameWithoutFigures() {
        let text = file(games: [.object(["opponent": "CNE", "serves": .array([])])])
        let result = parsePaperGames(text, season: season, members: firstNamesOnly, makeId: makeId)

        #expect(result.reason?.contains("CNE") == true)
        #expect(result.reason?.contains("no serve figures") == true)
    }

    @Test("A count that is not a whole number is refused")
    func refusesFractionalCount() {
        let text = file(games: [
            .object([
                "opponent": "CNE",
                "serves": .array([.object(["name": "Layna", "in": .number(1.5), "out": 0])]),
            ])
        ])
        let result = parsePaperGames(text, season: season, members: firstNamesOnly, makeId: makeId)

        #expect(result.reason?.contains("whole number") == true)
    }

    @Test("A negative count is refused")
    func refusesNegativeCount() {
        let text = file(games: [game(serves: [("Layna", -1, 0)])])
        let result = parsePaperGames(text, season: season, members: firstNamesOnly, makeId: makeId)

        #expect(result.reason?.contains("whole number") == true)
    }

    @Test("An unrecognised result is refused rather than assumed")
    func refusesUnknownResult() {
        let text = file(games: [game(serves: [("Layna", 1, 0)], result: "drew")])
        let result = parsePaperGames(text, season: season, members: firstNamesOnly, makeId: makeId)

        #expect(result.reason?.contains("unrecognised result") == true)
    }

    @Test("Nothing lands when any game in the batch is bad")
    func allOrNothing() {
        let text = file(games: [
            game(serves: [("Layna", 5, 2)]),
            game(opponent: "CNE", serves: [("Nobody", 1, 0)]),
        ])
        let result = parsePaperGames(text, season: season, members: firstNamesOnly, makeId: makeId)

        #expect(result.events == nil, "a partial import leaves nobody able to tell what landed")
        #expect(result.reason?.contains("Nothing was imported") == true)
    }
}

@Suite("Matching a name in the file to a player on the roster")
struct NameMatchingTests {
    @Test("A full name matches exactly")
    func matchesFullName() {
        let roster = members([("p1", "Layna Blankenship", "1")])
        let text = file(games: [game(serves: [("Layna Blankenship", 5, 2)])])

        #expect(parsePaperGames(text, season: season, members: roster, makeId: makeId).events?.count == 1)
    }

    @Test("A roster of first names still matches a file of full ones")
    func matchesByFirstName() {
        // This one actually happened: the roster was built on a phone before a match, with
        // first names; the file was written afterwards from handwriting, with full ones.
        let text = file(games: [game(serves: [("Layna Blankenship", 5, 2)])])
        let result = parsePaperGames(text, season: season, members: firstNamesOnly, makeId: makeId)

        #expect(result.events?.count == 1)
    }

    @Test("A jersey number bridges two spellings of a name")
    func matchesByNumber() {
        let roster = members([("p1", "Layna B", "1")])
        let text = file(
            roster: [(name: "Laina Blankenship", number: "1")],
            games: [game(serves: [("Laina Blankenship", 5, 2)])]
        )
        let result = parsePaperGames(text, season: season, members: roster, makeId: makeId)

        #expect(result.events?.count == 1, "the number is the least ambiguous thing either side holds")
    }

    @Test("Two players answering to one first name is refused, not guessed at")
    func refusesAmbiguity() {
        let roster = members([("p1", "Aria Smith", "5"), ("p2", "Aria Jones", "9")])
        let text = file(games: [game(serves: [("Aria", 5, 2)])])
        let result = parsePaperGames(text, season: season, members: roster, makeId: makeId)

        // Guessing would put a serve against the wrong child, which is worse than asking.
        #expect(result.reason?.contains("ambiguous") == true)
        #expect(result.reason?.contains("full names") == true)
    }

    @Test("A name nobody answers to is refused, and the roster is named so it can be seen")
    func refusesUnknownName() {
        let text = file(games: [game(serves: [("Nobody", 1, 0)])])
        let result = parsePaperGames(text, season: season, members: firstNamesOnly, makeId: makeId)

        #expect(result.reason?.contains("Nobody") == true)
        #expect(result.reason?.contains("Layna") == true, "the roster is named, not just refused")
    }

    @Test("A long roster is summarised rather than recited in full")
    func summarisesALongRoster() {
        let roster = members((1...20).map { ("p\($0)", "Player \($0)", "\($0)") })
        let text = file(games: [game(serves: [("Nobody", 1, 0)])])
        let result = parsePaperGames(text, season: season, members: roster, makeId: makeId)

        #expect(result.reason?.contains("and 8 more") == true)
    }
}

@Suite("What an imported game holds")
struct ImportedGameTests {
    @Test("It carries the context and the two lists the sheet keeps")
    func carriesContextAndNotes() throws {
        let text = file(games: [
            .object([
                "opponent": "CNE",
                "date": "2026-08-22",
                "location": "Felicity",
                "court": "1",
                "wentWell": "Charlee made 100% in",
                "needsWork": "Missed a lot of serves",
                "result": "won",
                "serves": .array([.object(["name": "Layna", "in": 6, "out": 4])]),
            ])
        ])
        let events = try #require(parsePaperGames(text, season: season, members: firstNamesOnly, makeId: makeId).events)

        guard case let .addHistoricalGame(_, seasonId, context, entries, notes, result) = events[0] else {
            Issue.record("expected a game from paper")
            return
        }

        #expect(seasonId == "s1")
        #expect(context.opponent == "CNE")
        #expect(context.date == "2026-08-22")
        #expect(context.location == "Felicity")
        #expect(notes.wentWell == "Charlee made 100% in")
        #expect(notes.needsWork == "Missed a lot of serves")
        #expect(result == .value(.won))
        #expect(entries?.first?.servesIn == 6)
    }

    @Test("A game with no result recorded is undecided, never lost")
    func unrecordedResultIsUndecided() throws {
        let text = file(games: [game(serves: [("Layna", 1, 0)])])
        let events = try #require(parsePaperGames(text, season: season, members: firstNamesOnly, makeId: makeId).events)

        guard case let .addHistoricalGame(_, _, _, _, _, result) = events[0] else {
            Issue.record("expected a game from paper")
            return
        }
        #expect(result == .value(.undecided), "silence is not a defeat")
    }

    @Test("The events it produces are accepted by the reducer")
    func producesAcceptableEvents() throws {
        let state = replay(
            firstNamesOnly.map {
                Event(id: $0.id, kind: .addPlayer(id: $0.id, name: $0.name, number: $0.number, seasonId: nil))
            }
        )
        let text = file(games: [game(serves: [("Layna", 5, 2)])])
        let events = try #require(parsePaperGames(text, season: state.activeSeason, members: state.roster, makeId: makeId).events)

        var next = state
        for kind in events {
            #expect(rejectionReason(next, Event(id: "e", kind: kind)) == nil)
            next = applyEvent(next, Event(id: "e", kind: kind))
        }
        #expect(next.games.count == 1)
        #expect(next.games[0].entries.first?.servesIn == 5)
    }
}
