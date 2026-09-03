// Getting rid of a season, in the native app, the same way the web app does it.
//
// The two apps read the same log, so an event one of them writes must mean exactly the same
// thing to the other. These are the Swift half of tests/unit/discard-season.test.js.
import Testing

@testable import VBCore

@Suite("Throwing a season away")
struct DiscardSeasonTests {
    /// A season with a squad and a game in it, plus a second season left alone.
    private var twoSeasons: [Event] {
        [
            event(.createSeason(id: "s1", name: "2026 Fall", team: "Riverside", format: .standard)),
            event(.activateSeason(id: "s1")),
            event(.addPlayer(id: "p1", name: "Avery", number: "4", seasonId: "s1")),
            event(.addPlayer(id: "p2", name: "Riley", number: "5", seasonId: "s1")),
            event(.startGame(id: "g1", seasonId: "s1", rotatesAtServeLimit: true)),
            event(.createSeason(id: "s2", name: "2025 Fall", team: "Riverside", format: .standard)),
            event(.addPlayer(id: "p1", name: "Avery", number: "9", seasonId: "s2")),
        ]
    }

    private func discarded() -> AppState {
        replay(twoSeasons + [event(.discardSeason(id: "s1"))])
    }

    @Test("The season and its games go together")
    func takesItsGames() {
        let state = discarded()
        #expect(state.season(id: "s1") == nil)
        #expect(state.games.isEmpty)
    }

    @Test("The players stay, because a person outlives a roster")
    func keepsThePeople() {
        #expect(discarded().players.map(\.id).sorted() == ["p1", "p2"])
    }

    @Test("What they wore in another season is untouched")
    func keepsTheOtherMembership() {
        let state = discarded()
        #expect(state.members(ofSeason: "s2").count == 1)
        #expect(state.members(ofSeason: "s2").first?.number == "9")
    }

    @Test("Nothing is left active or in progress")
    func leavesNothingDangling() {
        let state = discarded()
        #expect(state.activeSeasonId == nil)
        #expect(state.currentGameId == nil)
    }

    @Test("A season that is not there is refused rather than ignored")
    func refusesAGhost() {
        #expect(refusal(replay(twoSeasons), .discardSeason(id: "s9")) != nil)
    }

    @Test("The event survives a trip through the file format both apps read")
    func survivesTheRoundTrip() {
        var encoded = EventEncoder.encode(.discardSeason(id: "s1"))
        encoded["eventId"] = .string("e1")
        #expect(encoded["t"]?.stringValue == EventType.discardSeason)
        #expect(Event(raw: encoded)?.kind == .discardSeason(id: "s1"))
    }
}
