// Building the rotation one player at a time.
//
// The whole-lineup event sets six at once, which is what a list of names produces. Placing
// is what a court produces: the operator taps a spot and a player, six times, and each of
// those taps has to be one undo.
import Foundation
import Testing

@testable import VBCore

@Suite("Arranging the rotation")
struct ArrangementTests {
    private var started: AppState {
        build(roster(8), [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))])
    }

    @Test("A placement into a match with no order creates the order around it")
    func firstPlacementCreatesTheOrder() {
        let state = apply(started, .placeInLineup(playerId: "p3", lineupIndex: 0))

        #expect(state.currentLineup?.count == lineupSize)
        #expect(state.currentLineup?[0] == "p3")
        #expect(state.currentLineup?.compactMap { $0 } == ["p3"], "nobody else is standing anywhere")
    }

    @Test("Placements accumulate rather than replacing each other")
    func placementsAccumulate() {
        var state = apply(started, .placeInLineup(playerId: "p1", lineupIndex: 0))
        state = apply(state, .placeInLineup(playerId: "p2", lineupIndex: 3))
        state = apply(state, .placeInLineup(playerId: "p5", lineupIndex: 5))

        #expect(state.currentLineup == ["p1", nil, nil, "p2", nil, "p5"])
    }

    @Test("A player placed a second time moves, rather than standing in two places")
    func placingAgainMoves() {
        var state = apply(started, .placeInLineup(playerId: "p1", lineupIndex: 0))
        state = apply(state, .placeInLineup(playerId: "p1", lineupIndex: 4))

        #expect(state.currentLineup == [nil, nil, nil, nil, "p1", nil])
    }

    @Test("Placing onto an occupied spot displaces whoever was there")
    func placingDisplaces() {
        var state = apply(started, .placeInLineup(playerId: "p1", lineupIndex: 2))
        state = apply(state, .placeInLineup(playerId: "p7", lineupIndex: 2))

        #expect(state.currentLineup?[2] == "p7")
        #expect(state.currentLineup?.contains("p1") == false, "p1 is on the bench, not doubled up")
    }

    @Test("Clearing the last occupied spot leaves no order at all")
    func clearingTheLastLeavesNoOrder() {
        var state = apply(started, .placeInLineup(playerId: "p1", lineupIndex: 1))
        #expect(state.currentLineup != nil)

        state = apply(state, .clearLineupPosition(lineupIndex: 1))
        #expect(state.currentLineup == nil, "six empty places are not an order")
    }

    @Test("Clearing one of several leaves the rest standing")
    func clearingOneLeavesTheRest() {
        var state = apply(started, .placeInLineup(playerId: "p1", lineupIndex: 0))
        state = apply(state, .placeInLineup(playerId: "p2", lineupIndex: 1))
        state = apply(state, .clearLineupPosition(lineupIndex: 0))

        #expect(state.currentLineup == [nil, "p2", nil, nil, nil, nil])
    }

    @Test("Undo takes back exactly one placement")
    func undoTakesBackOnePlacement() {
        let full = roster(8)
            + [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))]
            + (0..<3).map { event(.placeInLineup(playerId: "p\($0 + 1)", lineupIndex: $0)) }

        let after = replay(full)
        let undone = replay(Array(full.dropLast()))

        #expect(after.currentLineup?.compactMap { $0 } == ["p1", "p2", "p3"])
        #expect(undone.currentLineup?.compactMap { $0 } == ["p1", "p2"], "one tap, one undo")
    }

    // MARK: - What it refuses

    @Test("There is nothing to arrange without a match")
    func refusedWithoutAMatch() {
        let state = build(roster(8))
        #expect(refusal(state, .placeInLineup(playerId: "p1", lineupIndex: 0)) != nil)
    }

    @Test("A rotation has six places and no others")
    func refusesAPlaceOffTheCourt() {
        #expect(refusal(started, .placeInLineup(playerId: "p1", lineupIndex: 6)) != nil)
        #expect(refusal(started, .placeInLineup(playerId: "p1", lineupIndex: -1)) != nil)
        #expect(refusal(started, .placeInLineup(playerId: "p1", lineupIndex: 5)) == nil)
    }

    @Test("Only players on the roster can be placed")
    func refusesAStranger() {
        #expect(refusal(started, .placeInLineup(playerId: "nobody", lineupIndex: 0)) != nil)
    }

    @Test("Once a serve is on the record the order is a fact, and the move is a substitution")
    func refusesAfterTheFirstServe() {
        var state = apply(started, .setLineup(playerIds: (1...6).map { "p\($0)" }))
        state = apply(state, .selectServer(playerId: "p1"))
        state = apply(state, .recordServe(outcome: .inPoint))

        let reason = refusal(state, .placeInLineup(playerId: "p7", lineupIndex: 0))
        #expect(reason?.contains("Substitute") == true)
        #expect(refusal(state, .clearLineupPosition(lineupIndex: 0)) != nil)
        #expect(state.canArrangeRotation == false)
    }

    @Test("Choosing a server without serving yet still leaves the rotation arrangeable")
    func serverChosenIsNotAServe() {
        var state = apply(started, .setLineup(playerIds: (1...6).map { "p\($0)" }))
        state = apply(state, .selectServer(playerId: "p1"))

        #expect(state.canArrangeRotation, "an open turn with no serves in it changed nothing")
        #expect(refusal(state, .placeInLineup(playerId: "p7", lineupIndex: 2)) == nil)
    }

}
