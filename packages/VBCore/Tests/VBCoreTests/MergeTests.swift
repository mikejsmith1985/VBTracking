// Taking in a season somebody else recorded, without losing the one already here.
//
// The case this exists for: a coach and an assistant coach at the same match, one of them
// tracking. The tracker hands the season over, and the other phone must end up holding both
// what it already had and what it was just given -- never one at the cost of the other.
import Testing

@testable import VBCore

@Suite("Taking in somebody else's season")
struct MergeTests {
    /// A log as it sits on disk, with every event named, which is what a merge works on.
    private func log(_ events: [Event]) -> [RawEvent] {
        events.enumerated().map { index, event in
            var raw = EventEncoder.encode(event.kind)
            raw["eventId"] = .string(event.id.isEmpty ? "e\(index)" : event.id)
            return raw
        }
    }

    /// Her season: her own team, her own roster.
    private var hers: [Event] {
        [
            event(.createSeason(id: "s-her", name: "2026 Fall", team: "Riverside", format: .standard), id: "h1"),
            event(.activateSeason(id: "s-her"), id: "h2"),
            event(.addPlayer(id: "p1", name: "Avery", number: "4", seasonId: "s-her"), id: "h3"),
        ]
    }

    /// What he tracked: a different season entirely, so nothing collides.
    private var his: [Event] {
        [
            event(.createSeason(id: "s-his", name: "2026 Spring", team: "Riverside", format: .standard), id: "g1"),
            event(.addPlayer(id: "p9", name: "Quinn", number: "15", seasonId: "s-his"), id: "g2"),
        ]
    }

    @Test("What she had is still there afterwards")
    func keepsWhatWasAlreadyHere() {
        let merged = merge(mine: log(hers), theirs: log(his))
        let state = replay(raw: merged.events)
        #expect(state.season(id: "s-her") != nil)
        #expect(state.players.contains { $0.id == "p1" })
    }

    @Test("What he sent arrives")
    func bringsInTheOtherLog() {
        let merged = merge(mine: log(hers), theirs: log(his))
        let state = replay(raw: merged.events)
        #expect(state.season(id: "s-his") != nil)
        #expect(state.players.contains { $0.id == "p9" })
    }

    @Test("The same file twice adds nothing the second time")
    func ignoresWhatItAlreadyHolds() {
        let once = merge(mine: log(hers), theirs: log(his))
        let twice = merge(mine: once.events, theirs: log(his))
        #expect(twice.eventsAdded == 0)
        #expect(twice.events.count == once.events.count)
    }

    @Test("An overlapping log contributes only its new events")
    func takesOnlyWhatIsNew() {
        let extended = his + [event(.addPlayer(id: "p8", name: "Taylor", number: "21", seasonId: "s-his"), id: "g3")]
        let first = merge(mine: log(hers), theirs: log(his))
        let second = merge(mine: first.events, theirs: log(extended))
        #expect(second.eventsAdded == 1)
        #expect(replay(raw: second.events).players.contains { $0.id == "p8" })
    }

    @Test("A merge that the rulebook would refuse is refused whole")
    func refusesRatherThanCorrupt() {
        // The same season id created twice, which the rulebook will not accept a second
        // time. Taking the events it does accept would leave a season half arrived.
        let clashing = [
            event(.createSeason(id: "s-her", name: "Someone else's", team: "Elsewhere", format: .standard), id: "x1")
        ]
        let merged = merge(mine: log(hers), theirs: log(clashing))
        #expect(merged.refusal != nil)
        #expect(merged.events == log(hers))
        #expect(merged.eventsAdded == 0)
    }

    @Test("Merging into nothing is just taking the whole thing")
    func acceptsEverythingOnAnEmptyPhone() {
        let merged = merge(mine: [], theirs: log(his))
        #expect(merged.refusal == nil)
        #expect(merged.eventsAdded == his.count)
    }

    @Test("It says how much arrived, so the operator is told")
    func reportsWhatItDid() {
        let merged = merge(mine: log(hers), theirs: log(his))
        #expect(merged.eventsAdded == 2)
        #expect(merged.seasonsAdded == 1)
        #expect(merged.playersAdded == 1)
    }

    @Test("An event with no identifier is still recognised by its content")
    func namesWhatArrivesUnnamed() {
        var unnamed = log(his)
        for index in unnamed.indices { unnamed[index]["eventId"] = nil }
        let first = merge(mine: log(hers), theirs: unnamed)
        let second = merge(mine: first.events, theirs: unnamed)
        #expect(second.eventsAdded == 0)
    }
}
