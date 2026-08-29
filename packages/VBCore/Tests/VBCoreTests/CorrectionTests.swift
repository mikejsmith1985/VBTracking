// Correcting a game already recorded. Ported from `tests/unit/corrections.test.js`.
//
// The corrections are appended like any other event rather than rewriting the log in
// place. Undo keeps working, replay stays deterministic, and fixing a mistake does not
// quietly destroy the record of what was first entered.
import Testing

@testable import VBCore

/// A finished game: p1 served three, p2 served two, and the match was ended.
private var played: [Event] {
    roster(4)
        + [event(.startGame(id: "g1", seasonId: "season-1", rotatesAtServeLimit: false))]
        + [
            event(.selectServer(playerId: "p1")),
            event(.recordServe(outcome: .inPoint)),
            event(.recordServe(outcome: .inPoint)),
            event(.recordServe(outcome: .out)),
            event(.selectServer(playerId: "p2")),
            event(.recordServe(outcome: .inPoint)),
            event(.recordServe(outcome: .out)),
            event(.endMatch(result: .value(.won))),
        ]
}

private var finished: State { replay(played) }

private func turns(_ state: State) -> [Turn] {
    state.game(id: "g1")?.matches.first?.turns ?? []
}

private func figures(_ state: State) -> [String: Figures] {
    state.game(id: "g1")?.matches.first?.statistics ?? [:]
}

/// A game copied from paper, which has no turns to correct.
private var fromPaper: State {
    build(
        roster(2),
        [
            event(
                .addHistoricalGame(
                    id: "h1",
                    seasonId: nil,
                    context: GameContext(opponent: "X"),
                    entries: [RawHistoricalEntry(playerId: "p1", servesIn: 1, servesOut: 0)],
                    notes: GameNotes(),
                    result: .absent
                )
            )
        ]
    )
}

@Suite("Correcting the serves in a turn")
struct SetTurnServesTests {
    @Test("They are replaced with what actually happened")
    func replacesServes() {
        let state = apply(finished, .setTurnServes(gameId: "g1", matchIndex: 0, ordinal: 0, outcomes: ["IN_POINT", "OUT"]))
        #expect(turns(state).first?.serves.map(\.outcome) == [.inPoint, .out])
    }

    @Test("The correction carries through every figure")
    func figuresFollow() {
        #expect(figures(finished)["p1"]?.serves == 3)
        #expect(figures(finished)["p1"]?.points == 2)

        let state = apply(finished, .setTurnServes(gameId: "g1", matchIndex: 0, ordinal: 0, outcomes: ["IN_NO_POINT"]))
        #expect(figures(state)["p1"]?.serves == 1)
        #expect(figures(state)["p1"]?.points == 0)
        #expect(state.game(id: "g1")?.matches.first?.score == 1)
    }

    @Test("It works on a match that has already ended")
    func worksAfterTheMatch() {
        #expect(refusal(finished, .setTurnServes(gameId: "g1", matchIndex: 0, ordinal: 0, outcomes: ["OUT"])) == nil)
    }

    @Test("An empty list is refused: that turn should be deleted instead")
    func refusesEmpty() {
        let reason = refusal(finished, .setTurnServes(gameId: "g1", matchIndex: 0, ordinal: 0, outcomes: []))
        #expect(reason?.contains("deleted instead") == true)
    }

    @Test("A list that never arrived is a different mistake, and says so")
    func refusesMissingList() {
        let reason = refusal(finished, .setTurnServes(gameId: "g1", matchIndex: 0, ordinal: 0, outcomes: nil))
        #expect(reason?.contains("needs a list") == true)
    }

    @Test("An outcome this app does not recognise is refused")
    func refusesUnknownOutcome() {
        #expect(refusal(finished, .setTurnServes(gameId: "g1", matchIndex: 0, ordinal: 0, outcomes: ["ACE"])) != nil)
    }

    @Test("A turn that is not there is refused")
    func refusesMissingTurn() {
        let reason = refusal(finished, .setTurnServes(gameId: "g1", matchIndex: 0, ordinal: 99, outcomes: ["OUT"]))
        #expect(reason?.contains("no longer exists") == true)
    }

    @Test("A game from paper has no turns to correct")
    func refusesPaperGame() {
        let reason = refusal(fromPaper, .setTurnServes(gameId: "h1", matchIndex: 0, ordinal: 0, outcomes: ["OUT"]))
        #expect(reason?.contains("from paper") == true)
    }
}

@Suite("Correcting who took a turn")
struct ReassignTurnTests {
    @Test("The whole turn moves to the right player")
    func movesTheTurn() {
        let state = apply(finished, .reassignTurn(gameId: "g1", matchIndex: 0, ordinal: 0, playerId: "p3"))

        #expect(turns(state).first?.playerId == "p3")
        #expect(figures(state)["p1"] == nil)
        #expect(figures(state)["p3"]?.serves == 3)
        #expect(figures(state)["p3"]?.points == 2)
    }

    @Test("It keeps its place in the order")
    func keepsItsPlace() {
        let state = apply(finished, .reassignTurn(gameId: "g1", matchIndex: 0, ordinal: 0, playerId: "p3"))
        #expect(turns(state).map(\.ordinal) == [0, 1])
    }

    @Test("A player who is not on the roster is refused")
    func refusesStranger() {
        #expect(refusal(finished, .reassignTurn(gameId: "g1", matchIndex: 0, ordinal: 0, playerId: "ghost")) != nil)
    }
}

@Suite("Deleting a turn recorded by mistake")
struct DeleteTurnTests {
    private var deleted: State {
        apply(finished, .deleteTurn(gameId: "g1", matchIndex: 0, ordinal: 0))
    }

    @Test("It goes, and everything it held goes with it")
    func removesTheTurn() {
        #expect(turns(deleted).count == 1)
        #expect(figures(deleted)["p1"] == nil)
    }

    @Test("The gap closes rather than being left as a hole")
    func renumbers() {
        #expect(turns(deleted).map(\.ordinal) == [0])
    }

    @Test("The other turns are untouched")
    func leavesTheRest() {
        #expect(figures(deleted)["p2"]?.serves == 2)
        #expect(figures(deleted)["p2"]?.points == 1)
    }
}

@Suite("Adding a turn that was missed at the time")
struct InsertTurnTests {
    @Test("It lands after the turn it was added against, not at the end")
    func landsInPlace() {
        let state = apply(finished, .insertTurn(gameId: "g1", matchIndex: 0, afterOrdinal: 0, playerId: "p3"))
        #expect(turns(state).map(\.playerId) == ["p1", "p3", "p2"])
    }

    @Test("It can be added before the first turn of the match")
    func addsAtTheStart() {
        let state = apply(finished, .insertTurn(gameId: "g1", matchIndex: 0, afterOrdinal: -1, playerId: "p3"))
        #expect(turns(state).first?.playerId == "p3")
    }

    @Test("It arrives holding one serve, because a turn with none did not happen")
    func arrivesWithOneServe() {
        let state = apply(finished, .insertTurn(gameId: "g1", matchIndex: 0, afterOrdinal: 0, playerId: "p3"))
        #expect(turns(state)[1].serves.map(\.outcome) == [.out])
    }

    @Test("It takes no rotation position, so it cannot move who serves next")
    func takesNoPosition() {
        let state = apply(finished, .insertTurn(gameId: "g1", matchIndex: 0, afterOrdinal: 0, playerId: "p3"))
        #expect(turns(state)[1].lineupPosition == nil)
        #expect(turns(state)[1].isOffLineup == false)
    }

    @Test("The turns after it renumber, so no two share a number")
    func renumbers() {
        let state = apply(finished, .insertTurn(gameId: "g1", matchIndex: 0, afterOrdinal: 0, playerId: "p3"))
        #expect(turns(state).map(\.ordinal) == [0, 1, 2])
    }

    @Test("It is corrected from there like any other turn")
    func correctableAfterwards() {
        var state = apply(finished, .insertTurn(gameId: "g1", matchIndex: 0, afterOrdinal: 0, playerId: "p3"))
        state = apply(state, .setTurnServes(gameId: "g1", matchIndex: 0, ordinal: 1, outcomes: ["IN_POINT", "IN_POINT", "OUT"]))

        #expect(figures(state)["p3"]?.serves == 3)
        #expect(figures(state)["p3"]?.points == 2)
    }

    @Test("A place that is not in the match is refused")
    func refusesBadPlace() {
        #expect(refusal(finished, .insertTurn(gameId: "g1", matchIndex: 0, afterOrdinal: 9, playerId: "p1"))?.contains("no such place") == true)
        #expect(refusal(finished, .insertTurn(gameId: "g1", matchIndex: 0, afterOrdinal: -2, playerId: "p1"))?.contains("no such place") == true)
    }
}

@Suite("A correction is an event like any other")
struct CorrectionLogTests {
    @Test("Dropping it undoes it")
    func undoDropsIt() {
        let corrected = played + [event(.setTurnServes(gameId: "g1", matchIndex: 0, ordinal: 0, outcomes: ["OUT"]))]

        #expect(replay(corrected) != finished)
        #expect(replay(corrected.dropLast()) == finished)
    }

    @Test("It replays deterministically")
    func replaysDeterministically() {
        let events = played + [
            event(.reassignTurn(gameId: "g1", matchIndex: 0, ordinal: 0, playerId: "p3")),
            event(.deleteTurn(gameId: "g1", matchIndex: 0, ordinal: 1)),
        ]
        #expect(replay(events) == replay(events))
    }
}
