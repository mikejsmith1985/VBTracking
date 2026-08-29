// The rotation and substitution rules. Ported from `tests/unit/rotation.test.js` and
// `substitution.test.js`.
import Testing

@testable import VBCore

private let six = ["p1", "p2", "p3", "p4", "p5", "p6"]

/// Nine on the roster, a game underway with the rotation rule in force, six on court.
private func inPlay(_ extra: [Event]...) -> State {
    var events = roster(9)
    events += [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))]
    events += [event(.setLineup(playerIds: six))]
    events += extra.flatMap { $0 }
    return replay(events)
}

@Suite("The serving order")
struct LineupTests {
    @Test("Six are set, in serving order")
    func setsLineup() {
        let state = inPlay()
        #expect(state.currentLineup?.map { $0 } == six.map { Optional($0) })
    }

    @Test("A lineup that is not exactly six is refused")
    func refusesWrongSize() {
        let started = build(roster(9), [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))])
        #expect(refusal(started, .setLineup(playerIds: ["p1", "p2"]))?.contains("exactly 6") == true)
        #expect(refusal(started, .setLineup(playerIds: six + ["p7"]))?.contains("exactly 6") == true)
    }

    @Test("A player cannot hold two positions")
    func refusesDuplicate() {
        let started = build(roster(9), [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))])
        #expect(refusal(started, .setLineup(playerIds: ["p1", "p1", "p2", "p3", "p4", "p5"])) != nil)
    }

    @Test("The order cannot be rewritten once a serve has been recorded")
    func refusesAfterFirstServe() {
        let state = inPlay(turn("p1", points: 1))
        #expect(refusal(state, .setLineup(playerIds: six.reversed()))?.contains("Substitute") == true)
    }
}

@Suite("The rotation serving by itself")
struct RotationAdvanceTests {
    @Test("A side-out hands the serve to the next player in the order")
    func advancesOnSideOut() {
        let state = inPlay([
            event(.selectServer(playerId: "p1")),
            event(.recordServe(outcome: .out)),
        ])
        #expect(state.activeServerId == "p2")
    }

    @Test("A point keeps the ball with the same player")
    func pointDoesNotAdvance() {
        let state = inPlay([
            event(.selectServer(playerId: "p1")),
            event(.recordServe(outcome: .inPoint)),
        ])
        #expect(state.activeServerId == "p1")
    }

    @Test("The order runs right round and back to the first")
    func wrapsAround() {
        var events: [Event] = [event(.selectServer(playerId: "p1"))]
        events += (0..<6).map { _ in event(.recordServe(outcome: .out)) }
        #expect(inPlay(events).activeServerId == "p1")
    }

    @Test("Five serves end the turn, even when the fifth won the point")
    func rotatesAtTheLimit() {
        var events: [Event] = [event(.selectServer(playerId: "p1"))]
        events += (0..<serveLimit).map { _ in event(.recordServe(outcome: .inPoint)) }
        let state = inPlay(events)

        let served = state.currentMatch?.turns.first
        #expect(served?.serves.count == serveLimit, "every serve is kept")
        #expect(served?.isOpen == false, "the turn is over")
        #expect(state.activeServerId == "p2", "and the serve has moved on")
    }

    @Test("The limit does not reach into a game recorded before the rule existed")
    func limitIsNotRetroactive() {
        var events = roster(9)
        // No `rotatesAtServeLimit`: this is what a release-002 log looks like.
        events += [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))]
        events += [event(.setLineup(playerIds: six)), event(.selectServer(playerId: "p1"))]
        events += (0..<7).map { _ in event(.recordServe(outcome: .inPoint)) }

        let state = replay(events)
        #expect(state.activeServerId == "p1", "the old game plays by the old rule")
        #expect(state.currentMatch?.openTurn?.serves.count == 7)
    }

    @Test("Undoing a serve takes the advance with it, so one undo is one action")
    func undoReversesTheAdvance() {
        let played = [event(.selectServer(playerId: "p1")), event(.recordServe(outcome: .out))]
        let after = inPlay(played)
        #expect(after.activeServerId == "p2")

        // Undo is dropping the last event and replaying, which is the whole point of
        // putting the advance inside the serve transition rather than beside it.
        var events = roster(9)
        events += [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))]
        events += [event(.setLineup(playerIds: six))] + played
        let undone = replay(events.dropLast())

        #expect(undone.activeServerId == "p1")
    }

    @Test("A server outside the order consumes the position that was due")
    func offOrderServerConsumesThePosition() {
        let state = inPlay([
            event(.selectServer(playerId: "p1")), event(.recordServe(outcome: .out)),
            event(.selectServer(playerId: "p9")), event(.recordServe(outcome: .out)),
        ])

        let offOrder = state.currentMatch?.turns.last { $0.playerId == "p9" }
        #expect(offOrder?.isOffLineup == true)
        #expect(state.activeServerId == "p3", "the order does not lag by one")
    }
}

@Suite("Substituting")
struct SubstitutionTests {
    @Test("The incoming player takes the outgoing player's exact position")
    func takesTheSameSlot() {
        let state = inPlay([event(.substitute(outPlayerId: "p3", inPlayerId: "p7"))])
        #expect(state.currentLineup?.map { $0 } == ["p1", "p2", "p7", "p4", "p5", "p6"])
    }

    @Test("Someone already on court is refused")
    func refusesOnCourtPlayer() {
        let state = inPlay()
        #expect(refusal(state, .substitute(outPlayerId: "p3", inPlayerId: "p4"))?.contains("already on court") == true)
    }

    @Test("Substituting the server closes their turn with the serves they actually took")
    func closesTheServersTurn() {
        let state = inPlay([
            event(.selectServer(playerId: "p1")),
            event(.recordServe(outcome: .inPoint)),
            event(.substitute(outPlayerId: "p1", inPlayerId: "p7")),
        ])

        let turns = state.currentMatch?.turns ?? []
        #expect(turns.first?.playerId == "p1")
        #expect(turns.first?.serves.count == 1, "their serve stays theirs")
        #expect(state.activeServerId == "p7", "and the ball passes to whoever came on")
    }

    @Test("The substitution is recorded with where and when it happened")
    func recordsTheSubstitution() {
        let state = inPlay(turn("p1", points: 1), [event(.substitute(outPlayerId: "p3", inPlayerId: "p7"))])
        let substitution = state.currentMatch?.substitutions.first

        #expect(substitution?.outPlayerId == "p3")
        #expect(substitution?.inPlayerId == "p7")
        #expect(substitution?.position == 2)
    }
}
