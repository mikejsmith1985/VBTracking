// Derived figures, and the one rule they all serve: a figure that was never recorded is
// nil, never zero. Ported from `tests/unit/stats.test.js` and `aggregate.test.js`.
import Testing

@testable import VBCore

@Suite("Figures for a turn and a match")
struct FigureTests {
    @Test("A turn counts its serves, the ones that landed in, and the points")
    func countsATurn() {
        let turn = Turn(
            playerId: "p1",
            ordinal: 0,
            colorIndex: 0,
            serves: [Serve(outcome: .inPoint), Serve(outcome: .inNoPoint), Serve(outcome: .out)]
        )

        #expect(turn.figures.serves == 3)
        #expect(turn.figures.servesIn == 2)
        #expect(turn.figures.points == 1)
        #expect(turn.figures.inPercentage == 2.0 / 3.0)
    }

    @Test("A turn with no serves has no percentage, rather than zero")
    func noServesNoPercentage() {
        let turn = Turn(playerId: "p1", ordinal: 0, colorIndex: 0)
        #expect(turn.figures.inPercentage == nil)
        #expect(turn.figures.serves == 0)
    }

    @Test("A match scores the points won on serve, which is not the rally score")
    func matchScore() {
        let state = build(
            roster(2),
            [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))],
            turn("p1", points: 3),
            turn("p2", points: 2)
        )
        #expect(state.currentMatch?.score == 5)
    }

    @Test("A turn opened but never served is left out of the figures entirely")
    func ignoresUnservedTurn() {
        let state = build(
            roster(2),
            [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))],
            turn("p1", points: 1),
            [event(.selectServer(playerId: "p2"))]
        )
        #expect(state.currentMatch?.statistics["p2"] == nil, "no turn credited for standing there")
    }
}

@Suite("Figures across games")
struct AggregateTests {
    /// A season holding one tracked game and one copied from paper — the mix that the
    /// null-not-zero rule exists for.
    private var mixedSeason: State {
        build(
            roster(3),
            [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))],
            turn("p1", points: 2),
            [event(.endGame(result: .value(.won)))],
            [
                event(
                    .addHistoricalGame(
                        id: "h1",
                        seasonId: nil,
                        context: GameContext(opponent: "Northside"),
                        entries: [
                            RawHistoricalEntry(playerId: "p2", servesIn: 6, servesOut: 4),
                            RawHistoricalEntry(playerId: "p1", servesIn: 3, servesOut: 1),
                        ],
                        notes: GameNotes(),
                        result: .value(.lost)
                    )
                )
            ]
        )
    }

    @Test("Serves and serves in span every game, tracked or copied from paper")
    func servesSpanEverything() {
        let figures = mixedSeason.seasonStatistics("season-1").byPlayer

        // p1: three serves tracked (two points and the one that ended the turn) plus four
        // from paper.
        #expect(figures["p1"]?.serves == 7)
        #expect(figures["p1"]?.servesIn == 5)
    }

    @Test("A player who appears only in a game from paper has no points — not zero points")
    func pointsAreNilWithoutTracking() {
        let figures = mixedSeason.seasonStatistics("season-1").byPlayer

        #expect(figures["p2"]?.serves == 10)
        #expect(figures["p2"]?.points == nil, "the paper never recorded points")
        #expect(figures["p2"]?.turnsTaken == nil)
        #expect(figures["p2"]?.turnsOnCourt == nil)
    }

    @Test("A player with tracked games does have points")
    func pointsExistWhereTracked() {
        let figures = mixedSeason.seasonStatistics("season-1").byPlayer
        #expect(figures["p1"]?.points == 2)
    }

    @Test("Coverage says how much of the season was tracked serve by serve")
    func reportsCoverage() {
        let coverage = mixedSeason.seasonStatistics("season-1").coverage
        #expect(coverage.totalGames == 2)
        #expect(coverage.trackedGames == 1)
    }

    @Test("A game's result follows from its matches; silence counts for neither side")
    func derivesGameResult() {
        let state = build(
            roster(2),
            [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))],
            turn("p1", points: 1), [event(.endMatch(result: .value(.won)))],
            turn("p1", points: 1), [event(.endMatch(result: .value(.lost)))],
            turn("p1", points: 1), [event(.endMatch(result: .absent))]
        )

        #expect(state.currentGame?.result == .undecided, "one each, and one unrecorded")
    }

    @Test("A season's record counts undecided games rather than folding them into losses")
    func recordKeepsUndecided() {
        let games = mixedSeason.games(inSeason: "season-1")
        let tally = record(of: games)

        #expect(tally.won == 1)
        #expect(tally.lost == 1)
        #expect(tally.undecided == 0)
    }

    @Test("The record breaks down by who was played")
    func recordByOpponentGroups() {
        let byOpponent = recordByOpponent(mixedSeason.games(inSeason: "season-1"))
        #expect(byOpponent["Northside"]?.lost == 1)
        #expect(byOpponent["Unnamed opponent"]?.won == 1, "a game with no opponent is still a game")
    }

    @Test("A career follows one player across every season, with each season's number")
    func careerSpansSeasons() {
        let state = build(
            [event(.createSeason(id: "s1", name: "2025", team: "Eastern", format: .standard))],
            [event(.addPlayer(id: "p1", name: "Ella", number: "7", seasonId: "s1"))],
            [event(.startGame(id: "g1", seasonId: "s1", rotatesAtServeLimit: false))],
            turn("p1", points: 2),
            [event(.endGame(result: .value(.won)))],
            [event(.createSeason(id: "s2", name: "2026", team: "School", format: .standard))],
            [event(.activateSeason(id: "s2"))],
            [event(.addPlayer(id: "p1", name: "Ella", number: "12", seasonId: "s2"))],
            [event(.startGame(id: "g2", seasonId: "s2", rotatesAtServeLimit: false))],
            turn("p1", points: 1),
            [event(.endGame(result: .value(.lost)))]
        )

        let career = state.career(of: "p1")
        #expect(career.seasons.count == 2)
        #expect(career.seasons.first?.number == "7")
        #expect(career.seasons.last?.number == "12")
        #expect(career.total?.serves == 5, "three serves in one season, two in the other")
    }

    @Test("Top scorer means most serves landed in, not most points")
    func topScorerIsServesIn() {
        // The operator's paper sheets use "score" for serves in. The app's own "points"
        // means something different, and the two must never be conflated.
        let state = build(
            roster(2),
            [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))],
            [
                // p1 lands one and wins the rally with it; p2 lands two and wins neither.
                event(.selectServer(playerId: "p1")),
                event(.recordServe(outcome: .inPoint)),
                event(.recordServe(outcome: .out)),
                event(.selectServer(playerId: "p2")),
                event(.recordServe(outcome: .inNoPoint)),
                event(.selectServer(playerId: "p2")),
                event(.recordServe(outcome: .inNoPoint)),
            ]
        )

        let summary = try? #require(state.currentGame).summary
        #expect(summary?.topScorer?.playerId == "p2", "two serves in beats one, whoever won the rally")
        #expect(state.currentGame?.statistics["p1"]?.points == 1, "and p1 is the one who scored")
    }
}
