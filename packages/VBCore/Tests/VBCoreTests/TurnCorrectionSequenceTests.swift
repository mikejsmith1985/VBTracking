// The correction the operator actually made, step by step.
//
// A turn recorded as four points then a serve in: [Pt Pt Pt Pt In]. What really happened was
// three points then a serve in. Getting from one to the other means dropping the last serve
// and then changing the new last serve -- two corrections in a row on the same turn, which
// is where it went wrong on the phone.
import Testing

@testable import VBCore

@Suite("Two corrections in a row on one turn")
struct TurnCorrectionSequenceTests {
    /// A match with two turns, the first of them the one being corrected.
    private var played: AppState {
        build(
            roster(6),
            [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))],
            [event(.setLineup(playerIds: ["p1", "p2", "p3", "p4", "p5", "p6"]))],
            turn("p1", points: 4, closing: .inNoPoint),
            turn("p2", points: 1, closing: .out)
        )
    }

    private func serves(_ state: AppState, ordinal: Int = 0) -> [Outcome] {
        state.game(id: "g1")?.matches.first?.turns.first { $0.ordinal == ordinal }?
            .serves.map(\.outcome) ?? []
    }

    private func turnCount(_ state: AppState) -> Int {
        state.game(id: "g1")?.matches.first?.turns.count ?? 0
    }

    @Test("The turn starts as it was recorded")
    func startsWithFiveServes() {
        #expect(serves(played) == [.inPoint, .inPoint, .inPoint, .inPoint, .inNoPoint])
        // Three, not two: the turn that ended opens the next server's turn behind it.
        #expect(turnCount(played) == 3)
    }

    @Test("Dropping the last serve leaves the other four")
    func dropsTheLastServe() {
        let state = apply(played, .setTurnServes(gameId: "g1", matchIndex: 0, ordinal: 0, outcomes: ["IN_POINT", "IN_POINT", "IN_POINT", "IN_POINT"]))
        #expect(serves(state) == [.inPoint, .inPoint, .inPoint, .inPoint])
        #expect(turnCount(state) == 3, "correcting a turn must not take another turn with it")
    }

    @Test("Changing the new last serve gives the turn that actually happened")
    func thenChangesTheNewLast() {
        let dropped = apply(played, .setTurnServes(gameId: "g1", matchIndex: 0, ordinal: 0, outcomes: ["IN_POINT", "IN_POINT", "IN_POINT", "IN_POINT"]))
        let fixed = apply(dropped, .setTurnServes(gameId: "g1", matchIndex: 0, ordinal: 0, outcomes: ["IN_POINT", "IN_POINT", "IN_POINT", "IN_NO_POINT"]))

        #expect(serves(fixed) == [.inPoint, .inPoint, .inPoint, .inNoPoint])
        #expect(turnCount(fixed) == 3, "the turn must still be there after two corrections")
    }

    @Test("The figures follow both corrections")
    func figuresFollow() {
        let dropped = apply(played, .setTurnServes(gameId: "g1", matchIndex: 0, ordinal: 0, outcomes: ["IN_POINT", "IN_POINT", "IN_POINT", "IN_POINT"]))
        let fixed = apply(dropped, .setTurnServes(gameId: "g1", matchIndex: 0, ordinal: 0, outcomes: ["IN_POINT", "IN_POINT", "IN_POINT", "IN_NO_POINT"]))
        let figures = fixed.game(id: "g1")?.matches.first?.statistics["p1"]

        #expect(figures?.serves == 4)
        #expect(figures?.servesIn == 4)
        #expect(figures?.points == 3)
    }

    @Test("Neither correction is refused")
    func neitherIsRefused() {
        #expect(refusal(played, .setTurnServes(gameId: "g1", matchIndex: 0, ordinal: 0, outcomes: ["IN_POINT", "IN_POINT", "IN_POINT", "IN_POINT"])) == nil)

        let dropped = apply(played, .setTurnServes(gameId: "g1", matchIndex: 0, ordinal: 0, outcomes: ["IN_POINT", "IN_POINT", "IN_POINT", "IN_POINT"]))
        #expect(refusal(dropped, .setTurnServes(gameId: "g1", matchIndex: 0, ordinal: 0, outcomes: ["IN_POINT", "IN_POINT", "IN_POINT", "IN_NO_POINT"])) == nil)
    }
}
