// The rules, one at a time. Ported from `tests/unit/reducer.test.js`.
//
// Pure: no storage, no clock, no interface. If one of these needs a delay or a mock,
// something has leaked into the domain that does not belong there.
import Testing

@testable import VBCore

@Suite("Roster rules")
struct RosterTests {
    @Test("A player is added with a name and this season's number")
    func addsPlayer() {
        let state = build([event(.addPlayer(id: "p1", name: "Rivera", number: "7", seasonId: nil))])
        #expect(state.roster == [RosterEntry(id: "p1", name: "Rivera", number: "7")])
    }

    @Test("The roster stops at twenty")
    func capsRoster() {
        let state = build(roster(20))
        #expect(state.roster.count == 20)
        #expect(
            refusal(state, .addPlayer(id: "p21", name: "Extra", number: "21", seasonId: nil))?
                .contains("20") == true
        )
    }

    @Test("A blank name is refused")
    func refusesBlankName() {
        let state = build([event(.addPlayer(id: "p1", name: "   ", number: "7", seasonId: nil))])
        #expect(state.roster.isEmpty)
    }

    @Test("A jersey number is text, so a leading zero survives")
    func keepsLeadingZero() {
        let state = build([event(.addPlayer(id: "p1", name: "Bell", number: "07", seasonId: nil))])
        #expect(state.roster.first?.number == "07")
    }

    @Test("Editing a player keeps every serve they recorded")
    func editKeepsServes() {
        let state = build(
            roster(1),
            [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))],
            turn("p1", points: 2),
            [event(.editPlayer(id: "p1", name: "Rivera-Smith", number: "17", seasonId: nil))]
        )
        #expect(state.roster.first == RosterEntry(id: "p1", name: "Rivera-Smith", number: "17"))
        #expect(state.currentMatch?.turns.first?.serves.count == 3)
    }

    @Test("A number belongs to the season, never to the person")
    func numberLivesOnMembership() {
        let state = build(
            [event(.createSeason(id: "s1", name: "2025", team: "A", format: .standard))],
            [event(.addPlayer(id: "p1", name: "Ella", number: "7", seasonId: "s1"))],
            [event(.createSeason(id: "s2", name: "2026", team: "B", format: .standard))],
            [event(.addPlayer(id: "p1", name: "Ella", number: "12", seasonId: "s2"))]
        )

        #expect(state.players.count == 1, "one person, two rosters")
        #expect(state.number(inSeason: "s1", playerId: "p1") == "7")
        #expect(state.number(inSeason: "s2", playerId: "p1") == "12")
    }

    @Test("Leaving a season keeps the person and everything they recorded")
    func removalFromSeasonIsNotDestructive() {
        let played = build(
            roster(2),
            [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))],
            turn("p1", points: 1)
        )
        let after = apply(played, .removeFromSeason(playerId: "p1", seasonId: nil))

        #expect(after.roster.count == 1)
        #expect(after.player(id: "p1") != nil, "the person still exists")
        #expect(after.currentMatch?.turns.count == 1, "their serves are still theirs")
    }

    @Test("The old destructive removal still discards turns, so an old log replays the same")
    func legacyRemovalStillDestroys() {
        let state = build(
            roster(2),
            [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))],
            turn("p1", points: 1),
            turn("p2", points: 1),
            [event(.removePlayer(id: "p1", seasonId: nil))]
        )

        let turns = state.currentMatch?.turns ?? []
        #expect(turns.count == 1)
        #expect(turns.first?.playerId == "p2")
        #expect(turns.first?.ordinal == 0, "what remains renumbers")
    }
}

@Suite("Game and match lifecycle")
struct LifecycleTests {
    private var started: [Event] {
        [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))]
    }

    @Test("Starting a game opens its first match")
    func opensFirstMatch() {
        let state = build(roster(1), started)
        #expect(state.currentGame?.matches.count == 1)
        #expect(state.currentMatch?.index == 0)
        #expect(state.currentMatch?.status == .inProgress)
    }

    @Test("Ending a match opens the next")
    func opensNextMatch() {
        let state = build(roster(1), started, turn("p1", points: 1), [event(.endMatch(result: .absent))])
        let matches = state.currentGame?.matches ?? []
        #expect(matches.first?.status == .ended)
        #expect(matches.count == 2)
        #expect(matches.last?.index == 1)
    }

    @Test("A fourth match never opens")
    func neverOpensFourth() {
        let state = build(
            roster(1), started,
            turn("p1", points: 1), [event(.endMatch(result: .absent))],
            turn("p1", points: 1), [event(.endMatch(result: .absent))],
            turn("p1", points: 1), [event(.endMatch(result: .absent))]
        )
        #expect(state.currentGame?.matches.count == 3)
        #expect(state.currentMatch == nil)
    }

    @Test("An ended match is untouched by what happens afterwards")
    func endedMatchIsFrozen() {
        let first = build(roster(2), started, turn("p1", points: 3), [event(.endMatch(result: .absent))])
        let frozen = first.currentGame?.matches.first

        let later = build(
            roster(2), started,
            turn("p1", points: 3), [event(.endMatch(result: .absent))],
            turn("p2", points: 2)
        )
        #expect(later.currentGame?.matches.first == frozen)
    }

    @Test("A serve is refused when no match is in progress")
    func refusesServeWithoutMatch() {
        let state = build(roster(1))
        #expect(refusal(state, .selectServer(playerId: "p1")) != nil)
    }

    @Test("A game can be ended where it stands, keeping every serve")
    func endsGameEarly() {
        let state = build(
            roster(2), started,
            [event(.selectServer(playerId: "p1")), event(.recordServe(outcome: .inPoint)), event(.recordServe(outcome: .out))],
            [event(.endGame(result: .value(.won)))]
        )

        let matches = state.currentGame?.matches ?? []
        #expect(matches.count == 1, "no further match opens")
        #expect(matches.first?.status == .ended)
        #expect(matches.first?.result == .won)
        #expect(matches.first?.turns.first?.serves.count == 2, "every serve is kept")
        #expect(state.isGameComplete, "fewer than three matches, and still over")
    }

    @Test("Discarding a game removes it and every serve in it, and keeps the roster")
    func discardsGame() {
        let state = build(
            roster(2), started,
            turn("p1", points: 2),
            [event(.discardGame(id: "g1"))]
        )
        #expect(state.games.isEmpty)
        #expect(state.currentGame == nil)
        #expect(state.roster.count == 2)
    }
}

@Suite("Serve turn boundaries")
struct ServeTurnTests {
    private var started: [Event] {
        [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))]
    }

    @Test("A point keeps the same server")
    func pointKeepsServer() {
        let state = build(
            roster(3), started,
            [event(.selectServer(playerId: "p1")), event(.recordServe(outcome: .inPoint)), event(.recordServe(outcome: .inPoint))]
        )
        let open = state.currentMatch?.openTurn
        #expect(open?.playerId == "p1")
        #expect(open?.serves.count == 2)
    }

    @Test("A serve that is out ends the turn")
    func outEndsTurn() {
        let state = build(roster(3), started, [event(.selectServer(playerId: "p1")), event(.recordServe(outcome: .out))])
        #expect(state.currentMatch?.openTurn == nil)
    }

    @Test("A serve that is in but wins no point ends the turn")
    func inWithoutPointEndsTurn() {
        let state = build(roster(3), started, [event(.selectServer(playerId: "p1")), event(.recordServe(outcome: .inNoPoint))])
        #expect(state.currentMatch?.openTurn == nil)
    }

    @Test("A serve is refused while no turn is open")
    func refusesServeWithoutOpenTurn() {
        let state = build(roster(3), started, [event(.selectServer(playerId: "p1")), event(.recordServe(outcome: .out))])
        #expect(refusal(state, .recordServe(outcome: .inPoint)) != nil)
    }

    @Test("Choosing a different server closes the turn before it")
    func selectingClosesPrevious() {
        let state = build(
            roster(3), started,
            [event(.selectServer(playerId: "p1")), event(.recordServe(outcome: .inPoint)), event(.selectServer(playerId: "p2"))]
        )
        let turns = state.currentMatch?.turns ?? []
        #expect(turns.count == 2)
        #expect(turns.first?.isOpen == false)
        #expect(turns.first?.serves.count == 1)
        #expect(turns.last?.playerId == "p2")
    }

    @Test("A turn that recorded nothing is never kept")
    func discardsEmptyTurn() {
        let state = build(
            roster(3), started,
            [event(.selectServer(playerId: "p1")), event(.selectServer(playerId: "p2")), event(.recordServe(outcome: .out))]
        )
        let turns = state.currentMatch?.turns ?? []
        #expect(turns.count == 1)
        #expect(turns.first?.playerId == "p2")
    }

    @Test("A player returning to serve takes a separate turn")
    func returningIsANewTurn() {
        let state = build(
            roster(3), started,
            turn("p1", points: 1), turn("p2", points: 1), turn("p1", points: 1)
        )
        let theirs = (state.currentMatch?.turns ?? []).filter { $0.playerId == "p1" }
        #expect(theirs.count == 2)
        #expect(theirs.map(\.ordinal) == [0, 2])
    }

    @Test("A turn past five serves is recorded in full and flagged")
    func recordsBeyondTheLimit() {
        var events = roster(3) + started + [event(.selectServer(playerId: "p1"))]
        events += (0..<7).map { _ in event(.recordServe(outcome: .inPoint)) }
        let state = replay(events)

        let open = state.currentMatch?.openTurn
        #expect(open?.serves.count == 7, "nothing is capped")
        #expect(open?.isOverServeLimit == true)
    }
}

@Suite("Purity")
struct PurityTests {
    @Test("Applying an event does not change the state it was given")
    func doesNotMutate() {
        let before = build(
            roster(2),
            [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false)), event(.selectServer(playerId: "p1"))]
        )
        let snapshot = before
        _ = apply(before, .recordServe(outcome: .inPoint))
        #expect(before == snapshot)
    }

    @Test("A refused event returns the same state, unchanged")
    func refusedChangesNothing() {
        let before = build(roster(1), [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))])
        #expect(apply(before, .recordServe(outcome: .inPoint)) == before)
    }

    @Test("Replay is deterministic")
    func replaysDeterministically() {
        let events = roster(2)
            + [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))]
            + turn("p1", points: 3) + turn("p2", points: 1)
        #expect(replay(events) == replay(events))
    }

    @Test("An event this build does not understand is ignored, not fatal")
    func ignoresUnknownEvent() {
        let known = build(roster(1))
        let withStranger = apply(known, .unrecognised(type: "SOMETHING_NEWER"))
        #expect(withStranger == known)
    }
}
