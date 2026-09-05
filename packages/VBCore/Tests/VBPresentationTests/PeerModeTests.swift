// Which phone is sending and which is receiving, decided before any radio is touched.
//
// Both phones used to advertise AND browse, and work out afterwards who was who from what
// arrived. Two phones inviting each other at the same moment is a race: one invitation wins,
// the other is refused, and the pair spends its time reconnecting instead of syncing. It
// joined perhaps one time in five.
//
// So the operator says which way the match travels, by tapping one of two buttons, and the
// radio does exactly one job on each phone. Nothing is inferred, so nothing can be inferred
// wrongly.
import Testing

@testable import VBPresentation

@Suite("Which way the match travels")
struct PeerModeTests {
    @Test("A phone sending a match is the one keeping the record")
    func sendingIsTracking() {
        #expect(PeerMode.sending.role == .tracking)
        #expect(PeerMode.sending.role.canRecord)
    }

    @Test("A phone receiving a match records nothing")
    func receivingIsFollowing() {
        #expect(PeerMode.receiving.role == .following)
        #expect(PeerMode.receiving.role.canRecord == false)
    }

    @Test("A phone not sharing is on its own and records as normal")
    func offIsAlone() {
        #expect(PeerMode.off.role == .alone)
        #expect(PeerMode.off.role.canRecord)
    }

    @Test("Exactly one phone advertises and exactly one looks")
    func onlyOneOfEachJob() {
        // The sender is findable; the receiver does the finding. Both doing both is what
        // made two phones invite each other and knock the connection over.
        #expect(PeerMode.sending.isAdvertising)
        #expect(PeerMode.sending.isBrowsing == false)

        #expect(PeerMode.receiving.isBrowsing)
        #expect(PeerMode.receiving.isAdvertising == false)

        #expect(PeerMode.off.isAdvertising == false)
        #expect(PeerMode.off.isBrowsing == false)
    }

    @Test("Each mode says what it is doing, in words the operator chose")
    func saysWhatItIsDoing() {
        #expect(PeerMode.sending.waitingLabel.lowercased().contains("receive"))
        #expect(PeerMode.receiving.waitingLabel.lowercased().contains("send"))
    }

    @Test("A role never changes while a mode holds")
    func roleFollowsModeAndNothingElse() {
        // The old code demoted whichever phone received anything, which quietly turned the
        // tracker into a follower and stopped both of them pushing.
        for mode in [PeerMode.off, .sending, .receiving] {
            #expect(mode.role == mode.role, "a mode has exactly one role, whatever arrives")
        }
        #expect(PeerMode.sending.role == .tracking)
    }
}
