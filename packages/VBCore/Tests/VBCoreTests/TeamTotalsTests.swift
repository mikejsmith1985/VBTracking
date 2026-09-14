// What the whole side served, as one row.
//
// The tally board always answered "how is this player serving" and never "how are we
// serving" -- a question asked between sets, and one nobody could answer from six rows of
// marks without adding them up by hand.
import Testing

@testable import VBCore

private let six = ["p1", "p2", "p3", "p4", "p5", "p6"]

private func inPlay(_ extra: [Event]...) -> AppState {
    var events = roster(8)
    events += [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))]
    events += [event(.setLineup(playerIds: six))]
    events += extra.flatMap { $0 }
    return replay(events)
}

@Suite("What the whole side served")
struct TeamTotalsTests {
    @Test("Every serve in the match is counted once")
    func countsEveryServe() {
        let state = inPlay(
            turn("p1", points: 2, closing: .out),
            turn("p2", points: 1, closing: .inNoPoint)
        )
        let total = state.currentMatch?.teamFigures

        // Two turns: three points, two serves that ended a turn, five serves in all.
        #expect(total?.serves == 5)
        #expect(total?.points == 3)
        #expect(total?.turnsTaken == 2)
    }

    @Test("The two percentages answer different questions")
    func separatesInFromScoring() {
        // Four serves in of five, but only two of them won anything. A side that puts nine
        // in ten over the net and wins nothing with them reads 90% and 0%, and the gap is
        // the whole point of showing both.
        let state = inPlay(turn("p1", points: 2, closing: .inNoPoint), [
            event(.selectServer(playerId: "p2")),
            event(.recordServe(outcome: .out)),
        ])
        let total = state.currentMatch?.teamFigures

        #expect(total?.serves == 4)
        #expect(total?.servesIn == 3)
        #expect(total?.points == 2)
        #expect(total?.inPercentage == 3.0 / 4.0)
        #expect(total?.pointPercentage == 2.0 / 4.0)
    }

    @Test("Nothing served is a dash, not a nought")
    func staysNilWithNoServes() {
        let state = inPlay()
        let total = state.currentMatch?.teamFigures

        #expect(total?.serves == 0)
        // A side that has not served has no percentage. Reporting 0% would say they served
        // and missed, which is the same lie a zero tells anywhere else in this app.
        #expect(total?.inPercentage == nil)
        #expect(total?.pointPercentage == nil)
    }

    @Test("A turn opened but never served does not count as a turn taken")
    func ignoresEmptyTurns() {
        // The rotation opens the next turn the moment one ends, so an empty turn is the
        // ordinary resting state rather than something that happened.
        let state = inPlay(turn("p1", points: 1, closing: .out), [event(.selectServer(playerId: "p2"))])
        #expect(state.currentMatch?.teamFigures.turnsTaken == 1)
    }

    @Test("A game adds up its matches")
    func addsUpTheWholeGame() {
        let state = inPlay(
            turn("p1", points: 2, closing: .out),
            [event(.endMatch(result: .value(.won)))],
            [event(.setLineup(playerIds: six))],
            turn("p2", points: 1, closing: .out)
        )
        let game = state.currentGame?.teamFigures

        // Three serves in the first match, two in the second.
        #expect(game?.serves == 5)
        #expect(game?.points == 3)
    }

    @Test("The side's total matches the sum of its players")
    func agreesWithThePlayerTable() {
        let state = inPlay(
            turn("p1", points: 3, closing: .out),
            turn("p2", points: 1, closing: .inNoPoint),
            turn("p3", points: 0, closing: .out)
        )
        guard let match = state.currentMatch else { return #expect(Bool(false), "a match") }

        // Two readings of the same serves. If they ever disagree, one of them is wrong and
        // the screen shows both at once.
        let fromPlayers = match.statistics.values.reduce(0) { $0 + $1.serves }
        #expect(match.teamFigures.serves == fromPlayers)

        let pointsFromPlayers = match.statistics.values.reduce(0) { $0 + $1.points }
        #expect(match.teamFigures.points == pointsFromPlayers)
    }
}
