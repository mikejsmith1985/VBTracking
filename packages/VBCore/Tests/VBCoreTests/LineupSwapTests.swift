// Exchanging two places in the serving order.
//
// A correction, not a substitution. Nobody left the floor: the order was written down wrong,
// or the plan changed before the ball moved. Recording it as a substitution would put a swap
// in the history that never happened on court -- and the history is the thing this app is
// for.
//
// It has to work mid-match, because an order written down wrong is almost always noticed
// after the first serve rather than before it.
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

@Suite("Correcting the serving order")
struct LineupSwapTests {
    @Test("Two places exchange, and nobody else moves")
    func swapsTwo() {
        let state = inPlay([event(.swapLineupPositions(firstIndex: 0, secondIndex: 3))])
        #expect(state.currentLineup == ["p4", "p2", "p3", "p1", "p5", "p6"])
    }

    @Test("It still works after the first serve, which is when the mistake is noticed")
    func worksMidMatch() {
        let midMatch = inPlay([
            event(.selectServer(playerId: "p1")),
            event(.recordServe(outcome: .inPoint)),
        ])
        #expect(refusal(midMatch, .swapLineupPositions(firstIndex: 1, secondIndex: 2)) == nil)

        let corrected = replay(
            roster(8) + [
                event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true)),
                event(.setLineup(playerIds: six)),
                event(.selectServer(playerId: "p1")),
                event(.recordServe(outcome: .inPoint)),
                event(.swapLineupPositions(firstIndex: 1, secondIndex: 2)),
            ]
        )
        #expect(corrected.currentLineup == ["p1", "p3", "p2", "p4", "p5", "p6"])
    }

    @Test("The serves already played are left exactly as they were")
    func neverRewritesHistory() {
        let played = [
            event(.selectServer(playerId: "p1")),
            event(.recordServe(outcome: .inPoint)),
            event(.recordServe(outcome: .out)),
        ]
        let before = inPlay(played)
        let after = inPlay(played, [event(.swapLineupPositions(firstIndex: 2, secondIndex: 5))])

        // A correction to who stands where changes who serves next. It must never change who
        // served, or a percentage moves for a reason nobody could explain.
        #expect(after.currentMatch?.turns == before.currentMatch?.turns)
    }

    @Test("It is not recorded as a substitution")
    func isNotASubstitution() {
        let state = inPlay([event(.swapLineupPositions(firstIndex: 0, secondIndex: 1))])
        // Nobody came off and nobody came on, so the match must not claim otherwise.
        #expect(state.currentMatch?.substitutions.isEmpty == true)
    }

    @Test("Undo takes back exactly one correction")
    func undoDropsOne() {
        let events =
            roster(8) + [
                event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true)),
                event(.setLineup(playerIds: six)),
                event(.swapLineupPositions(firstIndex: 0, secondIndex: 1)),
                event(.swapLineupPositions(firstIndex: 2, secondIndex: 3)),
            ]
        let undone = replay(events.dropLast())
        #expect(undone.currentLineup == ["p2", "p1", "p3", "p4", "p5", "p6"])
    }

    @Test("Nonsense is refused rather than silently ignored")
    func refusesNonsense() {
        let state = inPlay()
        #expect(refusal(state, .swapLineupPositions(firstIndex: 2, secondIndex: 2))?.contains("same place") == true)
        #expect(refusal(state, .swapLineupPositions(firstIndex: -1, secondIndex: 0)) != nil)
        #expect(refusal(state, .swapLineupPositions(firstIndex: 0, secondIndex: 6)) != nil)

        let noOrder = build(roster(8), [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))])
        #expect(refusal(noOrder, .swapLineupPositions(firstIndex: 0, secondIndex: 1)) != nil)
    }

    @Test("It survives being written and read back")
    func survivesTheLog() {
        let written = EventEncoder.encode(.swapLineupPositions(firstIndex: 1, secondIndex: 4))
        #expect(written["t"]?.stringValue == EventType.swapLineupPositions)
        #expect(Event(raw: written)?.kind == .swapLineupPositions(firstIndex: 1, secondIndex: 4))
    }
}
