// Bringing somebody back onto a roster, with the career they already have.
//
// Taking a player off a roster always left the person and their serves alone. Putting them
// back was the broken half: typing the name again made a second person who happened to share
// it, with an empty record, so a girl who left in October and returned in November had two
// histories and neither of them was hers.
import Testing
import VBCore

@testable import VBPresentation

@Suite("Who can be brought back")
struct ReturningPlayersTests {
    /// A season with `six` on the roster and `away` known to the app but not on it.
    private func state(onRoster: [String], known: [String]) -> AppState {
        var events: [Event] = []
        for (index, name) in known.enumerated() {
            events.append(
                Event(
                    id: "e\(index)",
                    kind: .addPlayer(id: "p\(index)", name: name, number: "\(index + 1)", seasonId: nil)
                )
            )
        }
        // Everybody is added, then the ones who are not meant to be on it are taken off --
        // which is exactly how this situation arises in a season.
        for (index, name) in known.enumerated() where !onRoster.contains(name) {
            events.append(
                Event(id: "r\(index)", kind: .removeFromSeason(playerId: "p\(index)", seasonId: nil))
            )
        }
        return replay(events)
    }

    @Test("Somebody taken off the roster can be brought back")
    func offersTheRemoved() {
        let season = state(onRoster: ["Aria", "Bea"], known: ["Aria", "Bea", "Cass"])
        #expect(playersWhoCouldReturn(to: season).map(\.name) == ["Cass"])
    }

    @Test("Nobody on the roster is offered")
    func neverOffersACurrentMember() {
        let season = state(onRoster: ["Aria", "Bea"], known: ["Aria", "Bea"])
        // Adding one would be refused anyway, but offering it is a button that does nothing.
        #expect(playersWhoCouldReturn(to: season).isEmpty)
    }

    @Test("A number they still wear somewhere is offered as a starting point")
    func remembersANumberFromAnotherSeason() {
        // Last year's roster, and this year's without her.
        let events: [Event] = [
            Event(id: "s1", kind: .createSeason(id: "last", name: "2025", team: "Us", format: .standard)),
            Event(id: "a1", kind: .activateSeason(id: "last")),
            Event(id: "p1", kind: .addPlayer(id: "cass", name: "Cass", number: "9", seasonId: "last")),
            Event(id: "s2", kind: .createSeason(id: "now", name: "2026", team: "Us", format: .standard)),
            Event(id: "a2", kind: .activateSeason(id: "now")),
        ]
        let seasons = replay(events)

        // Offered, not applied: a number belongs to the season being joined, and hers may be
        // on somebody else's back now.
        #expect(playersWhoCouldReturn(to: seasons).first?.lastNumber == "9")
    }

    @Test("A number that was deleted with the membership is not invented")
    func offersNoNumberItDoesNotHave() {
        // Taking somebody off a roster deletes the membership the number lived on, so after
        // that the app genuinely does not know what they wore. An empty field is the honest
        // answer; guessing one would put a number on a back that may be taken.
        let season = state(onRoster: ["Aria"], known: ["Aria", "Cass"])
        #expect(playersWhoCouldReturn(to: season).first?.lastNumber == nil)
    }

    @Test("They are listed by name, so a squad list can be read")
    func sortsByName() {
        let season = state(onRoster: [], known: ["Zoe", "Aria", "Meg"])
        #expect(playersWhoCouldReturn(to: season).map(\.name) == ["Aria", "Meg", "Zoe"])
    }

    @Test("What is said under a name is only ever what is known")
    func describesWhatItHas() {
        let neverPlayed = ReturningPlayer(id: "p1", name: "Aria", lastNumber: nil, serves: 0)
        #expect(neverPlayed.history == nil, "an empty line under a name is noise")

        let numbered = ReturningPlayer(id: "p2", name: "Bea", lastNumber: "7", serves: 0)
        #expect(numbered.history == "Last wore 7")

        let played = ReturningPlayer(id: "p3", name: "Cass", lastNumber: "9", serves: 42)
        #expect(played.history?.contains("42 serves") == true)
        #expect(played.history?.contains("Last wore 9") == true)

        let unnumbered = ReturningPlayer(id: "p4", name: "Dee", lastNumber: nil, serves: 12)
        #expect(unnumbered.history == "12 serves recorded")
    }

    @Test("Bringing one back makes no second person")
    func attachesToTheSameCareer() {
        let season = state(onRoster: ["Aria"], known: ["Aria", "Cass"])
        guard let cass = playersWhoCouldReturn(to: season).first else {
            return #expect(Bool(false), "Cass is available")
        }

        let peopleBefore = season.players.count
        let back = apply(
            season,
            .addPlayer(id: cass.id, name: cass.name, number: "11", seasonId: nil)
        )

        // The same person, wearing a new number. A second Cass with an empty career is the
        // whole thing this exists to prevent.
        #expect(back.players.count == peopleBefore)
        #expect(back.roster.contains { $0.id == cass.id })
        #expect(back.roster.first { $0.id == cass.id }?.number == "11")
    }

    @Test("Bringing somebody back who is already there is refused")
    func refusesADuplicateMembership() {
        let season = state(onRoster: ["Aria"], known: ["Aria"])
        let reason = rejectionReason(
            season,
            Event(id: "x", kind: .addPlayer(id: "p0", name: "Aria", number: "5", seasonId: nil))
        )
        #expect(reason?.contains("already on") == true)
    }
}
