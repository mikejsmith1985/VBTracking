// Two phones at the same match, only one of them tracking.
//
// The coach's watch pairs to the coach's phone and to nothing else, so a court cannot travel
// from the tracker's phone to the coach's wrist directly. It goes phone to phone, and the
// coach's phone feeds her own watch by the link that already exists.
//
// Every rule about who may record, what travels and what happens to it on arrival is decided
// here, where it can be tested on a machine with no phone attached at all.
import Testing
import VBCore

@testable import VBPresentation

@Suite("Which phone may record")
struct PeerRoleTests {
    @Test("A phone on its own records, because that is every phone today")
    func aloneMeansTracking() {
        #expect(PeerRole.alone.canRecord)
    }

    @Test("The phone doing the tracking records")
    func trackerRecords() {
        #expect(PeerRole.tracking.canRecord)
    }

    @Test("The phone following somebody else's match does not record")
    func followerIsReadOnly() {
        // Two logs of the same game cannot be joined afterwards -- the merge refuses them,
        // and rightly. So the second phone is never allowed to start a second log.
        #expect(PeerRole.following.canRecord == false)
    }

    @Test("A follower is told why the buttons are gone")
    func followerSaysWhy() {
        #expect(PeerRole.following.explanation != nil)
        #expect(PeerRole.tracking.explanation == nil)
        #expect(PeerRole.alone.explanation == nil)
    }
}

@Suite("What travels between two phones")
struct PeerSyncTests {
    private func event(_ id: String) -> RawEvent {
        ["eventId": .string(id), "t": .string("RECORD_SERVE"), "outcome": .string("IN_POINT")]
    }

    private var mine: [RawEvent] { [event("a"), event("b"), event("c")] }

    @Test("Only what the other phone is missing is sent")
    func sendsOnlyTheDifference() {
        let outgoing = PeerSync.eventsToSend(mine: mine, theyHold: ["a", "b"])
        #expect(outgoing.map(PeerSync.identifier) == ["c"])
    }

    @Test("A phone that holds nothing is sent everything")
    func sendsEverythingToAFreshPhone() {
        #expect(PeerSync.eventsToSend(mine: mine, theyHold: []).count == 3)
    }

    @Test("A phone already up to date is sent nothing")
    func sendsNothingWhenLevel() {
        #expect(PeerSync.eventsToSend(mine: mine, theyHold: ["a", "b", "c"]).isEmpty)
    }

    @Test("What a phone holds is announced by identifier, never by sending the log")
    func announcesIdentifiersOnly() {
        // A season is thousands of events. Sending the whole log to ask what is missing
        // would put a season on the air every few seconds.
        #expect(PeerSync.identifiersHeld(mine).sorted() == ["a", "b", "c"])
    }

    @Test("An event with no identifier is never announced as held")
    func ignoresAnUnnamedEvent() {
        let unnamed: RawEvent = ["t": .string("RECORD_SERVE")]
        #expect(PeerSync.identifiersHeld([unnamed]).isEmpty)
        #expect(PeerSync.eventsToSend(mine: [unnamed], theyHold: []).count == 1)
    }
}

@Suite("How current the other phone is")
struct PeerFreshnessTests {
    @Test("A link that is up says so")
    func connectedReadsAsConnected() {
        #expect(PeerLinkState.connected(peerName: "Mike's iPhone").isLive)
        #expect(PeerLinkState.connected(peerName: "Mike's iPhone").label.contains("Mike's iPhone"))
    }

    @Test("A link that is down is not presented as current")
    func lookingIsNotLive() {
        #expect(PeerLinkState.looking.isLive == false)
        #expect(PeerLinkState.off.isLive == false)
    }

    @Test("Off is the resting state, and it says nothing is being shared")
    func offSaysNothingIsShared() {
        #expect(PeerLinkState.off.label.isEmpty == false)
        #expect(PeerLinkState.off.isLive == false)
    }
}
