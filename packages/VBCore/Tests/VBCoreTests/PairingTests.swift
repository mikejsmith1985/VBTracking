// The invitation that turns a season file into "and I am sharing this match now".
//
// The whole point is that it is additive. A file with an invitation must still be a season
// file to everything that has ever read one -- the web app, an older build of this app, and
// the importer here -- because the alternative is a coach on a sideline whose season will not
// open.
import Foundation
import Testing

@testable import VBCore

@Suite("An invitation rides along with a season")
struct PairingTests {
    private var events: [RawEvent] {
        readBackup(buildBackup([], exportedAt: "2026-09-06T18:00:00Z")).log?.events ?? []
    }

    private let invitation = MatchInvitation(senderCode: "F4C0-1", senderName: "Mike's iPhone")

    @Test("An invitation comes back exactly as it was sent")
    func survivesTheRoundTrip() {
        let file = buildHandover([], exportedAt: "2026-09-06T18:00:00Z", inviting: invitation)
        #expect(readInvitation(file) == invitation)
    }

    @Test("A file with an invitation is still an ordinary season file")
    func staysReadableAsASeason() {
        let plain = buildBackup([], exportedAt: "2026-09-06T18:00:00Z")
        let invited = buildHandover([], exportedAt: "2026-09-06T18:00:00Z", inviting: invitation)

        // Both must import. An invitation that cost somebody their season would be a far
        // worse bug than the coordination it saves.
        #expect(readBackup(plain).log != nil)
        #expect(readBackup(invited).log != nil)
        #expect(readBackup(invited).log?.events == readBackup(plain).log?.events)
    }

    @Test("A season handed over for keeps carries no invitation, and that is not a failure")
    func noInvitationIsOrdinary() {
        let plain = buildHandover([], exportedAt: "2026-09-06T18:00:00Z", inviting: nil)
        #expect(readInvitation(plain) == nil)
        #expect(readBackup(plain).log != nil, "still a season")
        #expect(plain == buildBackup([], exportedAt: "2026-09-06T18:00:00Z"), "byte for byte")
    }

    @Test("Nothing is taken as an invitation from a file that is not ours")
    func refusesAStrangersFile() {
        #expect(readInvitation("") == nil)
        #expect(readInvitation("not json at all") == nil)
        // Right shape, wrong app: an invitation must not be read out of somebody else's JSON.
        #expect(readInvitation("{\"liveMatch\":{\"senderCode\":\"x\",\"senderName\":\"y\"}}") == nil)
    }

    @Test("An invitation with no phone in it is no invitation")
    func refusesAnEmptyCode() {
        let hollow = buildHandover(
            [],
            exportedAt: "2026-09-06T18:00:00Z",
            inviting: MatchInvitation(senderCode: "", senderName: "Nobody")
        )
        #expect(readInvitation(hollow) == nil, "a code nobody has matches every phone")
    }

    @Test("An invitation that lost its name still names the phone something")
    func alwaysHasSomethingToCall() {
        let file = buildHandover(
            [],
            exportedAt: "2026-09-06T18:00:00Z",
            inviting: MatchInvitation(senderCode: "ABC", senderName: "")
        )
        // Empty is allowed through; the row on screen must never be blank.
        #expect(readInvitation(file)?.senderCode == "ABC")
    }
}
