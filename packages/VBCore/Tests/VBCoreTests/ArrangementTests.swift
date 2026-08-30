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

// Correcting a name or a number after the fact.
//
// A name typed wrong on the first night was, until the roster gained an editor, only fixable
// by removing the player — which takes their career with them. These are the rules that
// editor leans on.
@Suite("Fixing a player's name or number")
struct PlayerEditTests {
    private var season: AppState {
        build(
            [event(.createSeason(id: "s1", name: "2026", team: "Tigers", format: .standard))],
            [event(.addPlayer(id: "p1", name: "Ella Kate Hatch", number: "7", seasonId: "s1"))]
        )
    }

    @Test("A misspelled name is corrected without touching anything else")
    func correctsTheName() {
        let state = apply(season, .editPlayer(id: "p1", name: "Ella Cate Hatch", number: "7", seasonId: "s1"))

        #expect(state.rosterEntry(id: "p1")?.name == "Ella Cate Hatch")
        #expect(state.rosterEntry(id: "p1")?.number == "7")
    }

    @Test("A number changes on the season membership, never on the player")
    func numberBelongsToTheSeason() {
        var state = apply(season, .editPlayer(id: "p1", name: "Ella Cate Hatch", number: "12", seasonId: "s1"))
        state = apply(state, .createSeason(id: "s2", name: "2027", team: "Tigers", format: .standard))
        state = apply(state, .addPlayer(id: "p1", name: "Ella Cate Hatch", number: "3", seasonId: "s2"))

        #expect(state.number(inSeason: "s1", playerId: "p1") == "12")
        #expect(state.number(inSeason: "s2", playerId: "p1") == "3", "the shirt they wore last year is still theirs")
    }

    @Test("Correcting a name keeps every serve they have taken")
    func keepsTheirRecord() {
        var state = build(
            roster(3),
            [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))],
            turn("p1", points: 3)
        )
        let before = state.currentMatch?.statistics["p1"]

        state = apply(state, .editPlayer(id: "p1", name: "Corrected Name", number: "1", seasonId: nil))

        #expect(state.rosterEntry(id: "p1")?.name == "Corrected Name")
        #expect(state.currentMatch?.statistics["p1"] == before, "renaming is not removing")
    }

    @Test("Whitespace either side of a correction is not part of the name")
    func trimsWhatWasTyped() {
        let state = apply(season, .editPlayer(id: "p1", name: "  Ella  ", number: " 9 ", seasonId: "s1"))

        #expect(state.rosterEntry(id: "p1")?.name == "Ella")
        #expect(state.rosterEntry(id: "p1")?.number == "9")
    }

    @Test("A player has to have a name, and has to exist")
    func refusesTheImpossible() {
        #expect(refusal(season, .editPlayer(id: "p1", name: "   ", number: "7", seasonId: "s1")) != nil)
        #expect(refusal(season, .editPlayer(id: "nobody", name: "Someone", number: "7", seasonId: "s1")) != nil)
        #expect(refusal(season, .editPlayer(id: "p1", name: "Ella", number: "", seasonId: "s1")) == nil, "a player without a shirt number is still a player")
    }
}

// The rotation carrying on over a gap.
//
// A slot can be empty: a short bench, a player removed mid-match, or an order somebody was
// still building when the whistle went. Stopping at one froze the whole match.
@Suite("A rotation with a gap in it")
struct GappedRotationTests {
    private func match(placing pairs: [(String, Int)]) -> AppState {
        var state = build(roster(8), [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))])
        for (playerId, index) in pairs {
            state = apply(state, .placeInLineup(playerId: playerId, lineupIndex: index))
        }
        return state
    }

    @Test("The serve passes over an empty place to the next player standing")
    func stepsOverAGap() {
        // Nobody at index 1: the serve should reach p3 at index 2, not stop dead.
        var state = match(placing: [("p1", 0), ("p3", 2)])
        state = apply(state, .selectServer(playerId: "p1"))
        state = apply(state, .recordServe(outcome: .out))

        #expect(state.activeServerId == "p3", "a gap is not the end of the order")
    }

    @Test("A match with a gap keeps somebody serving after every turn")
    func neverStallsMidMatch() {
        // The failure this is here for: no turn opened, so nobody was serving, so the app
        // asked who serves next after every single rally.
        var state = match(placing: [("p1", 0), ("p2", 3)])
        state = apply(state, .selectServer(playerId: "p1"))

        for _ in 0..<6 {
            state = apply(state, .recordServe(outcome: .out))
            #expect(state.activeServerId != nil, "the court emptied itself between rallies")
        }
    }

    @Test("The order still wraps round to the beginning")
    func wrapsRound() {
        var state = match(placing: [("p1", 0), ("p2", 5)])
        state = apply(state, .selectServer(playerId: "p2"))
        state = apply(state, .recordServe(outcome: .out))

        #expect(state.activeServerId == "p1", "past the last place is the first")
    }

    @Test("A full order is unaffected")
    func fullOrderIsUnchanged() {
        var state = apply(
            build(roster(8), [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))]),
            .setLineup(playerIds: (1...6).map { "p\($0)" })
        )
        state = apply(state, .selectServer(playerId: "p1"))
        state = apply(state, .recordServe(outcome: .out))

        #expect(state.activeServerId == "p2")
    }

    @Test("An order nobody is standing in hands the ball to nobody")
    func emptyOrderStaysEmpty() {
        var state = match(placing: [("p1", 0)])
        state = apply(state, .selectServer(playerId: "p1"))
        state = apply(state, .clearLineupPosition(lineupIndex: 0))
        state = apply(state, .recordServe(outcome: .out))

        #expect(state.activeServerId == nil, "there is nobody to hand it to")
    }
}
