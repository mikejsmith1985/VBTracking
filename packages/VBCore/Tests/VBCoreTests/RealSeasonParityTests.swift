// The season that actually matters.
//
// Nine players, four games copied from paper sheets, one tracked serve by serve and then
// corrected afterwards, five games thrown away along the way, and a team name with an
// apostrophe in it. Nothing about it is synthetic, and it cannot be recorded again.
//
// The expectations were produced by the shipped web app from this same file. If a figure
// here moves, the port has changed what a real season says about real children.
import Foundation
import Testing

@testable import VBCore

@Suite("Parity with the operator's own season")
struct RealSeasonParityTests {
    /// The season, read through the native import exactly as the app will read it.
    private func season() throws -> AppState {
        let url = Fixture.directory.appendingPathComponent("season-2026.json")
        let text = try String(contentsOf: url, encoding: .utf8)
        let imported = try #require(readBackup(text).log, "the real season could not be read")
        return replay(raw: imported.events)
    }

    private func expectation() throws -> [String: JSONValue] {
        try Fixture.json("season-2026-expected")
    }

    @Test("It reads through the native import at all")
    func imports() throws {
        let state = try season()
        let expected = try #require(try expectation()["season"]?.objectValue)

        #expect(state.seasons.count == 1)
        #expect(state.activeSeason?.name == expected["name"]?.stringValue)
        #expect(state.activeSeason?.team == expected["team"]?.stringValue, "apostrophe and all")
    }

    @Test("Every player comes across, with the number they wore this season")
    func roster() throws {
        let state = try season()
        let expected = try #require(try expectation()["roster"]?.arrayValue).compactMap(\.objectValue)

        #expect(state.roster.count == expected.count)
        for (entry, expected) in zip(state.roster, expected) {
            #expect(entry.id == expected["id"]?.stringValue)
            #expect(entry.name == expected["name"]?.stringValue)
            #expect(entry.number == expected["number"]?.stringValue)
        }
    }

    @Test("Every game kept is kept, and every game discarded stays gone")
    func games() throws {
        let state = try season()
        let expected = try #require(try expectation()["games"]?.arrayValue).compactMap(\.objectValue)
        let seasonId = try #require(state.activeSeasonId)
        let games = state.games(inSeason: seasonId)

        #expect(games.count == expected.count, "five kept; the discarded ones stay discarded")

        for (game, expected) in zip(games, expected) {
            let who = game.context.opponent
            #expect(game.id == expected["id"]?.stringValue)
            #expect(game.kind.rawValue == expected["kind"]?.stringValue, "kind of \(who)")
            #expect(game.context.date == expected["date"]?.stringValue, "date of \(who)")
            #expect(game.context.opponent == expected["opponent"]?.stringValue)
            #expect(game.result.rawValue == expected["result"]?.stringValue, "result of \(who)")
            #expect(game.summary.serves == expected["serves"]?.intValue, "serves of \(who)")
            #expect(game.summary.servesIn == expected["servesIn"]?.intValue, "serves in of \(who)")
            #expect(game.summary.topScorer?.playerId == expected["topScorer"]?.stringValue, "top scorer of \(who)")
        }
    }

    @Test("The season's record and coverage are the same figures")
    func recordAndCoverage() throws {
        let state = try season()
        let expected = try expectation()
        let seasonId = try #require(state.activeSeasonId)
        let games = state.games(inSeason: seasonId)

        let tally = try #require(expected["record"]?.objectValue)
        let actual = record(of: games)
        #expect(actual.won == tally["won"]?.intValue)
        #expect(actual.lost == tally["lost"]?.intValue)
        #expect(actual.undecided == tally["undecided"]?.intValue)

        let coverage = try #require(expected["coverage"]?.objectValue)
        let figures = state.seasonStatistics(seasonId)
        #expect(figures.coverage.totalGames == coverage["totalGames"]?.intValue)
        #expect(figures.coverage.trackedGames == coverage["trackedGames"]?.intValue, "one game of five was tracked")
    }

    @Test("The record breaks down by opponent identically")
    func byOpponent() throws {
        let state = try season()
        let seasonId = try #require(state.activeSeasonId)
        let expected = try #require(try expectation()["byOpponent"]?.objectValue)
        let actual = recordByOpponent(state.games(inSeason: seasonId))

        #expect(actual.count == expected.count)
        for (opponent, value) in expected {
            let tally = try #require(value.objectValue)
            #expect(actual[opponent]?.won == tally["won"]?.intValue, "wins against \(opponent)")
            #expect(actual[opponent]?.lost == tally["lost"]?.intValue, "losses against \(opponent)")
            #expect(actual[opponent]?.undecided == tally["undecided"]?.intValue, "undecided against \(opponent)")
        }
    }

    @Test("Every player's season figures match, dashes included")
    func seasonFigures() throws {
        let state = try season()
        let seasonId = try #require(state.activeSeasonId)
        let expected = try #require(try expectation()["seasonFigures"]?.objectValue)
        let actual = state.seasonStatistics(seasonId).byPlayer

        #expect(actual.count == expected.count)

        for (playerId, value) in expected {
            let fields = try #require(value.objectValue)
            let figures = try #require(actual[playerId], "no figures for \(playerId)")

            #expect(figures.serves == fields["serves"]?.intValue, "serves for \(playerId)")
            #expect(figures.servesIn == fields["servesIn"]?.intValue, "serves in for \(playerId)")
            #expect(figures.games == fields["games"]?.intValue, "games for \(playerId)")
            #expect(figures.trackedGames == fields["trackedGames"]?.intValue, "tracked games for \(playerId)")

            expectCount(figures.points, fields["points"], "points for \(playerId)")
            expectCount(figures.turnsTaken, fields["turnsTaken"], "turns for \(playerId)")
            expectCount(figures.turnsOnCourt, fields["turnsOnCourt"], "time on court for \(playerId)")
            expectRatio(figures.inPercentage, fields["inPercentage"], "percentage for \(playerId)")
        }
    }

    @Test("The tracked game replays match by match, corrections and all")
    func trackedGame() throws {
        let state = try season()
        let expected = try #require(try expectation()["tracked"]?.objectValue)
        let game = try #require(state.game(id: expected["id"]?.stringValue))
        let matches = try #require(expected["matches"]?.arrayValue).compactMap(\.objectValue)

        #expect(game.matches.count == matches.count)

        for (match, expected) in zip(game.matches, matches) {
            #expect(match.index == expected["index"]?.intValue)
            #expect(match.status.rawValue == expected["status"]?.stringValue)
            #expect(match.result.rawValue == expected["result"]?.stringValue, "result of match \(match.index)")
            #expect(match.turns.count == expected["turns"]?.intValue, "turns in match \(match.index)")
            #expect(match.score == expected["score"]?.intValue, "score of match \(match.index)")
            #expect(match.substitutions.count == (expected["subs"]?.intValue ?? 0))

            let byPlayer = try #require(expected["byPlayer"]?.objectValue)
            let actual = match.statistics
            #expect(actual.count == byPlayer.count, "players with figures in match \(match.index)")

            for (playerId, value) in byPlayer {
                let fields = try #require(value.objectValue)
                let figures = try #require(actual[playerId], "no figures for \(playerId) in match \(match.index)")

                #expect(figures.serves == fields["serves"]?.intValue, "serves for \(playerId)")
                #expect(figures.servesIn == fields["servesIn"]?.intValue, "serves in for \(playerId)")
                #expect(figures.points == fields["points"]?.intValue, "points for \(playerId)")
                #expect(figures.turnsTaken == fields["turnsTaken"]?.intValue, "turns for \(playerId)")
                expectRatio(figures.inPercentage, fields["inPercentage"], "percentage for \(playerId)")
            }
        }
    }

    @Test("Time on court in the tracked game is the same for every player")
    func timeOnCourt() throws {
        let state = try season()
        let expected = try #require(try expectation()["tracked"]?.objectValue)
        let game = try #require(state.game(id: expected["id"]?.stringValue))
        let onCourt = try #require(expected["onCourt"]?.objectValue)

        for (playerId, expected) in onCourt {
            #expect(
                turnsOnCourt(game.allTurns, playerId: playerId) == expected.intValue,
                "time on court for \(playerId)"
            )
        }
    }

    @Test("Reading the season twice gives the same season")
    func readsDeterministically() throws {
        #expect(try season() == season())
    }

    @Test("The same file is recognised on a second import rather than doubling the season")
    func refusesASecondImport() throws {
        let url = Fixture.directory.appendingPathComponent("season-2026.json")
        let text = try String(contentsOf: url, encoding: .utf8)
        let first = try #require(readBackup(text).log)

        let second = decideImport(readBackup(text), alreadyImported: [first.sourceHash])
        #expect(second.reason == "That backup is already in. Nothing was changed.")
    }

    // MARK: - Comparing

    /// A count that may legitimately be absent.
    ///
    /// Absent and zero are different answers, and comparing them as numbers is exactly how
    /// one quietly becomes the other.
    private func expectCount(_ actual: Int?, _ expected: JSONValue?, _ label: String) {
        switch expected {
        case .null, nil:
            #expect(actual == nil, "\(label) should be absent")
        case let .number(value):
            #expect(actual == Int(value), Comment(rawValue: label))
        default:
            Issue.record("\(label) is not a number")
        }
    }

    private func expectRatio(_ actual: Double?, _ expected: JSONValue?, _ label: String) {
        switch expected {
        case .null, nil:
            #expect(actual == nil, "\(label) should be absent")
        case let .number(value):
            #expect(actual.map { abs($0 - value) < 0.0000001 } == true, Comment(rawValue: label))
        default:
            Issue.record("\(label) is not a number")
        }
    }
}
