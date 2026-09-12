// What a glance is allowed to show.
//
// A glance is read in a second, from a distance, by somebody about to decide whether to
// substitute. The one thing it must never do is show a figure that stopped being true --
// because a coach reading a frozen percentage has no way to know it froze.
//
// So a glance either vouches for what it shows or it shows nothing and says why. There is no
// third state where old figures sit on the screen looking current.
import Foundation
import Testing
import VBCore

@testable import VBPresentation

@Suite("What a glance may show")
struct GlanceTests {
    private let captured = Date(timeIntervalSince1970: 1_788_000_000)

    private func slot(_ court: Int, _ number: String, onDeck: Bool = false) -> SnapshotSlot {
        SnapshotSlot(court: court, number: number, inPercentage: 0.8, points: 4, isServing: court == 6, isOnDeck: onDeck)
    }

    private var court: CourtSnapshot {
        CourtSnapshot(
            sequence: 1,
            capturedAt: captured,
            scopeLabel: "Match 2",
            hasOrder: true,
            slots: (1...6).map { slot($0, "\($0)", onDeck: $0 == 4) },
            serveLimit: nil,
            acknowledgedEventIds: []
        )
    }

    @Test("A court that just arrived is shown")
    func showsAFreshCourt() {
        let glance = Glance(court: court, now: captured.addingTimeInterval(2))
        #expect(glance.isVouchedFor)
        #expect(glance.slots.count == 6)
    }

    @Test("A court that stopped arriving shows no figures at all")
    func hidesAStaleCourt() {
        // Not dimmed, not greyed, not marked: absent. A percentage on screen is read as a
        // percentage however it is styled.
        let glance = Glance(court: court, now: captured.addingTimeInterval(120))
        #expect(glance.isVouchedFor == false)
        #expect(glance.slots.isEmpty)
    }

    @Test("A stale glance says why, so it is never mistaken for a court with nobody on it")
    func explainsWhyItIsBlank() {
        let glance = Glance(court: court, now: captured.addingTimeInterval(120))
        #expect(glance.headline.isEmpty == false)
        #expect(glance.headline.lowercased().contains("open") || glance.headline.lowercased().contains("catch"))
    }

    @Test("Having never received a court is not the same as having lost one")
    func distinguishesNothingYetFromStale() {
        let waiting = Glance(court: nil, now: captured)
        #expect(waiting.isVouchedFor == false)
        #expect(waiting.slots.isEmpty)
        #expect(waiting.headline != Glance(court: court, now: captured.addingTimeInterval(120)).headline)
    }

    @Test("The threshold is the one the wrist already uses")
    func sharesTheWristsThreshold() {
        // One rule about what "current" means, in one place. Two would drift, and the wrist
        // and the lock screen would disagree in front of the same coach.
        let onTheEdge = Glance(court: court, now: captured.addingTimeInterval(Double(LinkFreshness.stalenessThreshold) - 1))
        let overIt = Glance(court: court, now: captured.addingTimeInterval(Double(LinkFreshness.stalenessThreshold) + 1))
        #expect(onTheEdge.isVouchedFor)
        #expect(overIt.isVouchedFor == false)
    }

    @Test("A fresh glance says how old it is, in case a second matters")
    func statesItsOwnAge() {
        // Under five seconds the wrist already says "just now" rather than counting, and the
        // lock screen says the same thing: one wording, so the two never disagree.
        #expect(Glance(court: court, now: captured.addingTimeInterval(3)).age == "just now")
        #expect(Glance(court: court, now: captured.addingTimeInterval(12)).age.contains("12"))
    }

    @Test("Who serves next is named, because that is the whole decision")
    func namesTheServerOnDeck() {
        let glance = Glance(court: court, now: captured.addingTimeInterval(1))
        #expect(glance.onDeckNumber == "4")
    }

    @Test("With no order there is nobody on deck, and none is invented")
    func namesNobodyWithoutAnOrder() {
        var unordered = court
        unordered.hasOrder = false
        unordered.slots = unordered.slots.map { slot in
            var next = slot
            next.isOnDeck = false
            return next
        }
        #expect(Glance(court: unordered, now: captured.addingTimeInterval(1)).onDeckNumber == nil)
    }
}

/// A court has to be hashable to ride a Live Activity: ActivityKit only carries a state that
/// can be compared for equality by value, so it knows whether the lock screen changed.
@Suite("A court can travel to the lock screen")
struct CourtSnapshotHashingTests {
    private func court(sequence: Int) -> CourtSnapshot {
        CourtSnapshot(
            sequence: sequence,
            capturedAt: Date(timeIntervalSince1970: 1_788_000_000),
            scopeLabel: "Match 1",
            hasOrder: true,
            slots: [SnapshotSlot(court: 1, number: "4", inPercentage: 0.5, points: 1, isServing: false, isOnDeck: true)],
            serveLimit: nil,
            acknowledgedEventIds: []
        )
    }

    @Test("The same court hashes the same, so an unchanged lock screen is left alone")
    func sameCourtSameHash() {
        #expect(court(sequence: 1) == court(sequence: 1))
        #expect(court(sequence: 1).hashValue == court(sequence: 1).hashValue)
    }

    @Test("A court that moved is a different court")
    func movedCourtDiffers() {
        #expect(court(sequence: 1) != court(sequence: 2))
    }
}
