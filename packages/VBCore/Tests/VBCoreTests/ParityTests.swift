// The argument that this port is trustworthy.
//
// The rulebook was moved from JavaScript to Swift. It reads correctly — but a port that
// reads correctly and counts differently has failed, and the only thing riding on it is a
// real season that cannot be recorded again. So the ported reducer replays the logs the
// shipped web app actually produced, and every figure is compared against the figures that
// app derived from them.
//
// The fixtures are never edited. They are the format as shipped, not as remembered.
import Foundation
import Testing

@testable import VBCore

@Suite("Parity with the shipped web app")
struct ParityTests {
    /// Replays a stored log through the migration chain and the ported reducer.
    private func replayed(_ name: String) throws -> State {
        let (events, version) = try Fixture.log(name)
        let carried = try #require(migrate(events, from: version).events, "\(name) failed to migrate")
        return replay(raw: carried)
    }

    // MARK: - Release 001

    @Test("A release-001 log replays to the roster it recorded")
    func version1Roster() throws {
        let state = try replayed("v1-log")
        let expected = try Fixture.json("v1-expected")

        #expect(state.roster.count == expected["roster"]?.intValue)
    }

    @Test("A release-001 log replays to the same matches, turns and scores")
    func version1Matches() throws {
        let state = try replayed("v1-log")
        let expected = try Fixture.json("v1-expected")
        let game = try #require(state.currentGame)

        let matches = try #require(expected["matches"]?.arrayValue)
        #expect(game.matches.count == matches.count)

        for (match, expectation) in zip(game.matches, matches.compactMap(\.objectValue)) {
            #expect(match.index == expectation["index"]?.intValue)
            #expect(match.status.rawValue == expectation["status"]?.stringValue)
            #expect(match.turns.count == expectation["turns"]?.intValue)
            #expect(match.score == expectation["score"]?.intValue)
        }
    }

    @Test("A release-001 log replays to the same per-player figures")
    func version1Figures() throws {
        let state = try replayed("v1-log")
        let expected = try Fixture.json("v1-expected")
        let game = try #require(state.currentGame)

        try expectFigures(game.statistics, match: expected["game"])
    }

    // MARK: - Release 002

    @Test("A release-002 log replays to the roster it recorded, with this season's numbers")
    func version2Roster() throws {
        let state = try replayed("v2-log")
        let expected = try Fixture.json("v2-expected")
        let players = try #require(expected["roster"]?.arrayValue).compactMap(\.objectValue)

        #expect(state.roster.count == players.count)
        for (entry, expectation) in zip(state.roster, players) {
            #expect(entry.id == expectation["id"]?.stringValue)
            #expect(entry.name == expectation["name"]?.stringValue)
            #expect(entry.number == expectation["number"]?.stringValue)
        }
    }

    @Test("A release-002 log replays to the same matches, lineups and substitutions")
    func version2Matches() throws {
        let state = try replayed("v2-log")
        let expected = try Fixture.json("v2-expected")
        let game = try #require(state.currentGame)
        let matches = try #require(expected["matches"]?.arrayValue).compactMap(\.objectValue)

        #expect(game.matches.count == matches.count)

        for (match, expectation) in zip(game.matches, matches) {
            #expect(match.index == expectation["index"]?.intValue)
            #expect(match.status.rawValue == expectation["status"]?.stringValue)
            #expect(match.turns.count == expectation["turns"]?.intValue)
            #expect(match.score == expectation["score"]?.intValue)
            #expect(match.substitutions.count == (expectation["subs"]?.intValue ?? 0))

            let lineup = (expectation["lineup"]?.arrayValue ?? []).map(\.stringValue)
            #expect(match.lineup?.map { $0 } ?? [] == lineup)
        }
    }

    @Test("A release-002 log replays to the same per-player figures")
    func version2Figures() throws {
        let state = try replayed("v2-log")
        let expected = try Fixture.json("v2-expected")
        let game = try #require(state.currentGame)

        try expectFigures(game.statistics, match: expected["game"])
    }

    @Test("A release-002 log replays to the same time on court")
    func version2OnCourt() throws {
        let state = try replayed("v2-log")
        let expected = try Fixture.json("v2-expected")
        let game = try #require(state.currentGame)
        let onCourt = try #require(expected["onCourt"]?.objectValue)

        for (playerId, expectation) in onCourt {
            #expect(
                turnsOnCourt(game.allTurns, playerId: playerId) == expectation.intValue,
                "time on court for \(playerId)"
            )
        }
    }

    // MARK: - The rule the whole port turns on

    @Test("The rotation rule does not reach backwards into a game already recorded")
    func rotationRuleIsNotRetroactive() throws {
        // Release 002 logs carry no `rotatesAtServeLimit`, so the rule that was added in a
        // later release must not apply to them. If it did, a turn that ran to five in a
        // recorded game would end early and hand serves to a different player -- the exact
        // corruption this field exists to prevent.
        let state = try replayed("v2-log")
        let game = try #require(state.currentGame)

        #expect(game.rotatesAtServeLimit == false)
    }

    // MARK: - Comparing

    private func expectFigures(_ actual: [String: Figures], match expected: JSONValue?) throws {
        let expectation = try #require(expected?.objectValue)

        #expect(actual.count == expectation.count, "the same players have figures")

        for (playerId, value) in expectation {
            let fields = try #require(value.objectValue)
            let figures = try #require(actual[playerId], "no figures for \(playerId)")

            #expect(figures.serves == fields["serves"]?.intValue, "serves for \(playerId)")
            #expect(figures.servesIn == fields["servesIn"]?.intValue, "serves in for \(playerId)")
            #expect(figures.points == fields["points"]?.intValue, "points for \(playerId)")
            #expect(figures.turnsTaken == fields["turnsTaken"]?.intValue, "turns for \(playerId)")

            // A percentage that was never recorded is nil in both languages. Comparing it
            // as a number would let a null quietly become a zero, which is the one thing
            // this whole model exists to prevent.
            switch fields["inPercentage"] {
            case .null, nil:
                #expect(figures.inPercentage == nil, "percentage for \(playerId) should be absent")
            case let .number(value):
                let actual = try #require(figures.inPercentage, "percentage for \(playerId)")
                #expect(abs(actual - value) < 0.0000001, "percentage for \(playerId)")
            default:
                Issue.record("percentage for \(playerId) is not a number")
            }
        }
    }
}
