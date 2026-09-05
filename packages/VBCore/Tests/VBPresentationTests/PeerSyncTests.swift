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

/// The conversation itself, one step at a time.
///
/// The first sync worked and nothing after it did: the tracker announced its own identifiers
/// on every change, which asks the far side to send what IT is missing -- and a follower has
/// nothing to send. What a tracker owes has to be pushed, not asked about.
@Suite("Keeping a second phone level, serve by serve")
struct PeerConversationTests {
    private func event(_ id: String) -> RawEvent {
        ["eventId": .string(id), "t": .string("RECORD_SERVE")]
    }

    @Test("The first exchange sends everything the other phone lacks")
    func catchesAFreshPhoneUp() {
        let mine = [event("a"), event("b")]
        let sent = PeerSync.eventsToSend(mine: mine, theyHold: [])
        #expect(sent.count == 2)
    }

    @Test("Once sent, the same events are never sent again")
    func doesNotResend() {
        let mine = [event("a"), event("b")]
        var peerHolds = Set<String>()

        let first = PeerSync.eventsToSend(mine: mine, theyHold: peerHolds)
        peerHolds.formUnion(PeerSync.identifiersHeld(first))

        #expect(PeerSync.eventsToSend(mine: mine, theyHold: peerHolds).isEmpty)
    }

    @Test("A serve recorded after the catch-up is the only thing that travels")
    func sendsOnlyTheNewServe() {
        var mine = [event("a"), event("b")]
        var peerHolds = Set<String>()
        peerHolds.formUnion(PeerSync.identifiersHeld(PeerSync.eventsToSend(mine: mine, theyHold: peerHolds)))

        mine.append(event("c"))
        let next = PeerSync.eventsToSend(mine: mine, theyHold: peerHolds)

        #expect(next.map(PeerSync.identifier) == ["c"], "one serve, not the season again")
    }

    @Test("Forgetting the far side resends everything, which is what a reconnect needs")
    func startsOverAfterADrop() {
        let mine = [event("a"), event("b"), event("c")]
        var peerHolds = Set(PeerSync.identifiersHeld(mine))
        #expect(PeerSync.eventsToSend(mine: mine, theyHold: peerHolds).isEmpty)

        peerHolds = []
        #expect(PeerSync.eventsToSend(mine: mine, theyHold: peerHolds).count == 3)
    }
}

/// Who is the tracker, once two phones have been talking for a while.
///
/// Reported from a real match: the tracker threw a game away, started another, and the
/// second phone stayed connected, stayed read-only, and stopped receiving anything. Both
/// phones had quietly decided they were the follower, and a follower never pushes.
@Suite("Which phone stays the tracker")
struct PeerRoleSettlingTests {
    @Test("Sending a match makes this phone the tracker")
    func sendingMakesYouTheTracker() {
        #expect(PeerRole.alone.afterSending() == .tracking)
        #expect(PeerRole.tracking.afterSending() == .tracking)
    }

    @Test("Receiving a match makes a phone that is not tracking the follower")
    func receivingMakesYouTheFollower() {
        #expect(PeerRole.alone.afterReceiving() == .following)
        #expect(PeerRole.following.afterReceiving() == .following)
    }

    @Test("A phone that has sent a match never becomes the follower")
    func theTrackerNeverFlips() {
        // The other phone almost always has something the tracker has not got -- an older
        // season of its own -- and that used to arrive and silently demote the phone doing
        // the recording. From then on neither phone pushed anything.
        #expect(PeerRole.tracking.afterReceiving() == .tracking)
    }

    @Test("Roles hold across the end of a match")
    func rolesSurviveAGameEnding() {
        // A game thrown away and another started is still the same two people at the same
        // match. Sharing continues until somebody stops it, which is the only thing they
        // asked for by tapping the button.
        var tracker = PeerRole.alone.afterSending()
        tracker = tracker.afterReceiving()
        tracker = tracker.afterSending()
        #expect(tracker == .tracking, "ending a game does not hand the record to the other phone")
    }

    @Test("Only stopping sharing puts a phone back on its own")
    func stoppingReturnsYouToAlone() {
        #expect(PeerRole.following.afterStoppingSharing() == .alone)
        #expect(PeerRole.tracking.afterStoppingSharing() == .alone)
    }
}

@Suite("What the sharing row says")
struct PeerLabelTests {
    private let joined = PeerLinkState.connected(peerName: "Mike's iPhone")

    @Test("The tracker is told it is the one recording")
    func namesTheTracker() {
        #expect(joined.label(as: .tracking).contains("you are recording"))
    }

    @Test("The follower is told the other phone is recording")
    func namesTheFollower() {
        let said = joined.label(as: .following)
        #expect(said.contains("Mike's iPhone"))
        #expect(said.contains("they are recording"))
    }

    @Test("A link that is not up says what it is doing, whatever the role")
    func staysHonestWhenNotJoined() {
        #expect(PeerLinkState.looking.label(as: .tracking) == PeerLinkState.looking.label)
        #expect(PeerLinkState.off.label(as: .following) == PeerLinkState.off.label)
    }
}
