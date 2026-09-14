// Believing a phone is nearby, and stopping when it is not.
//
// Bluetooth never says goodbye, so everything here is about how long a sighting is worth.
// Offering to join a match that ended an hour ago is worse than offering nothing.
import Foundation
import Testing

@testable import VBPresentation

@Suite("Who is nearby, and for how long")
struct NearbyPhonesTests {
    private let start = Date(timeIntervalSince1970: 1_757_000_000)

    @Test("A phone just heard from is offered")
    func offersWhatItJustHeard() {
        var nearby = NearbyPhones()
        nearby.noticed(id: "A", name: "Mike's iPhone", at: start)

        #expect(nearby.current(at: start).count == 1)
        #expect(nearby.offer(at: start) == "Mike's iPhone is sharing a match")
        #expect(nearby.onlyOne(at: start)?.shownName == "Mike's iPhone")
    }

    @Test("A phone not heard from recently is dropped")
    func forgetsTheStale() {
        var nearby = NearbyPhones()
        nearby.noticed(id: "A", name: "Mike's iPhone", at: start)

        let stillGood = start.addingTimeInterval(NearbyPhones.trustedFor)
        let tooOld = start.addingTimeInterval(NearbyPhones.trustedFor + 1)
        #expect(nearby.current(at: stillGood).count == 1, "the edge is still trusted")
        #expect(nearby.current(at: tooOld).isEmpty)
        #expect(nearby.offer(at: tooOld) == nil)
    }

    @Test("Being heard again keeps a phone alive")
    func aSightingRenewsIt() {
        var nearby = NearbyPhones()
        nearby.noticed(id: "A", name: "Mike's iPhone", at: start)

        let later = start.addingTimeInterval(NearbyPhones.trustedFor - 1)
        nearby.noticed(id: "A", name: "Mike's iPhone", at: later)

        // Would have been dropped on the first sighting alone.
        let afterTheFirstWouldHaveGone = start.addingTimeInterval(NearbyPhones.trustedFor + 1)
        #expect(nearby.current(at: afterTheFirstWouldHaveGone).count == 1)
        #expect(nearby.current(at: afterTheFirstWouldHaveGone).count == 1, "and not doubled")
    }

    @Test("The same phone seen twice is one phone")
    func neverDoubles() {
        var nearby = NearbyPhones()
        for _ in 0..<20 { nearby.noticed(id: "A", name: "Mike's iPhone", at: start) }
        #expect(nearby.current(at: start).count == 1)
    }

    @Test("Two phones sharing at once are never guessed between")
    func refusesToPickBetweenTwo() {
        var nearby = NearbyPhones()
        nearby.noticed(id: "A", name: "Mike's iPhone", at: start)
        nearby.noticed(id: "B", name: "Court 2", at: start)

        // Picking one would put somebody else's match on this screen and look like it worked.
        #expect(nearby.onlyOne(at: start) == nil)
        #expect(nearby.offer(at: start) == "2 phones nearby are sharing a match")
    }

    @Test("The order does not shuffle as advertisements arrive")
    func staysInAStableOrder() {
        var nearby = NearbyPhones()
        nearby.noticed(id: "B", name: "Zoe's iPhone", at: start)
        nearby.noticed(id: "A", name: "Mike's iPhone", at: start)
        // Heard again in the other order, which is what a radio does.
        nearby.noticed(id: "A", name: "Mike's iPhone", at: start.addingTimeInterval(1))

        #expect(nearby.current(at: start.addingTimeInterval(1)).map(\.shownName) == ["Mike's iPhone", "Zoe's iPhone"])
    }

    @Test("A phone that gave no name is still offered, by some name")
    func alwaysHasSomethingToCallIt() {
        var nearby = NearbyPhones()
        // iOS drops the name out of an advertisement once that app is in the background.
        nearby.noticed(id: "A", name: "", at: start)

        #expect(nearby.onlyOne(at: start)?.shownName == "Another phone")
        #expect(nearby.offer(at: start)?.isEmpty == false)
        #expect(nearby.offer(at: start)?.contains("  ") == false, "never a gap where a name should be")
    }

    @Test("Nothing nearby says nothing at all")
    func staysQuietWhenEmpty() {
        let nearby = NearbyPhones()
        // An app that says "nobody is sharing" on every open teaches everybody to ignore
        // that row by the second week.
        #expect(nearby.offer(at: start) == nil)
        #expect(nearby.onlyOne(at: start) == nil)
        #expect(nearby.current(at: start).isEmpty)
    }

    @Test("Giving up listening forgets everybody")
    func forgetsAllOnDemand() {
        var nearby = NearbyPhones()
        nearby.noticed(id: "A", name: "Mike's iPhone", at: start)
        nearby.forgetAll()
        #expect(nearby.current(at: start).isEmpty)
    }
}
