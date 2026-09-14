// Deciding whether the phone that just answered is the one being waited for.
//
// A gym can hold two families running this app at two courts. Bluetooth finds whoever is
// advertising, so without this a receiver would take a stranger's match, draw a stranger's
// court, and look exactly like it was working.
import Testing
import VBCore

@testable import VBPresentation

@Suite("A phone only listens to the match it was invited to")
struct IntroductionsTests {
    private let mike = Introduction(senderCode: "MIKE-1", senderName: "Mike's iPhone")
    private let stranger = Introduction(senderCode: "OTHER-9", senderName: "Court 2")

    @Test("The invited phone is welcome")
    func takesTheInvitedPhone() {
        let greeting = Introductions.consider(mike, expecting: "MIKE-1")
        #expect(greeting.isWelcome)
        #expect(greeting.peerName == "Mike's iPhone")
    }

    @Test("Another match at the next court is refused")
    func refusesAStranger() {
        let greeting = Introductions.consider(stranger, expecting: "MIKE-1")
        #expect(!greeting.isWelcome)
        #expect(greeting.peerName == nil, "a refused phone is never named as connected")
    }

    @Test("A phone switched on by hand takes whoever answers")
    func takesAnybodyWithoutAnInvitation() {
        // No invitation means nothing to check against, which is the behaviour that existed
        // before invitations and is kept for when AirDrop is not to hand.
        #expect(Introductions.consider(stranger, expecting: nil).isWelcome)
        #expect(Introductions.consider(stranger, expecting: "").isWelcome)
    }

    @Test("A code is matched exactly, never nearly")
    func matchesExactly() {
        let nearly = Introduction(senderCode: "MIKE-11", senderName: "Somebody else")
        #expect(!Introductions.consider(nearly, expecting: "MIKE-1").isWelcome)

        let cased = Introduction(senderCode: "mike-1", senderName: "Somebody else")
        #expect(!Introductions.consider(cased, expecting: "MIKE-1").isWelcome)
    }

    @Test("What it says while waiting depends on whether a phone was named")
    func saysWhatItIsWaitingFor() {
        #expect(Introductions.waitingLabel(expecting: nil, from: nil).contains("a phone"))
        #expect(Introductions.waitingLabel(expecting: "MIKE-1", from: "Mike's iPhone").contains("Mike's iPhone"))
        // Invited, but the invitation carried no name to show.
        #expect(Introductions.waitingLabel(expecting: "MIKE-1", from: nil).contains("invitation"))
        #expect(Introductions.waitingLabel(expecting: "MIKE-1", from: "").contains("invitation"))
    }

    @Test("Nothing said while waiting is ever blank")
    func alwaysSaysSomething() {
        for code in [nil, "", "MIKE-1"] {
            for name in [nil, "", "Mike's iPhone"] {
                #expect(!Introductions.waitingLabel(expecting: code, from: name).isEmpty)
            }
        }
    }
}
