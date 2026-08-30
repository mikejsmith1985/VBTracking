// Two numbers, and the rules for when they mean somebody has won.
//
// Nothing here touches a log, a season or a player, and the tests are written to notice if
// that ever stops being true.
import Foundation
import Testing
import VBCore

@testable import VBPresentation

@Suite("Keeping score for a game nobody is tracking")
struct ScoreboardTests {
    @Test("A new board is nothing to nothing")
    func startsEmpty() {
        let board = Scoreboard()
        #expect(board.us == 0)
        #expect(board.them == 0)
        #expect(board.winner == nil)
        #expect(board.hasStarted == false)
    }

    @Test("A point goes to the side it was given to, and only that side")
    func awardsOnePoint() {
        var board = Scoreboard()
        board.award(to: .us)
        board.award(to: .them)
        board.award(to: .them)

        #expect(board.us == 1)
        #expect(board.them == 2)
    }

    @Test("A minus takes a point off the side it was pressed under")
    func subtractsFromOneSide() {
        var board = Scoreboard()
        board.award(to: .us)
        board.award(to: .them)
        board.subtract(from: .us)

        #expect(board.us == 0)
        #expect(board.them == 1, "the other side is untouched")
    }

    @Test("A correction is made where the mistake was, not where the last tap was")
    func subtractsOutOfOrder() {
        var board = Scoreboard()
        board.award(to: .them)
        for _ in 0..<4 { board.award(to: .us) }

        // The point four rallies ago went to the wrong side. It comes off that side.
        board.subtract(from: .them)

        #expect(board.them == 0)
        #expect(board.us == 4, "nothing else is unwound to get there")
    }

    @Test("Nothing goes below nothing")
    func neverGoesNegative() {
        var board = Scoreboard()
        board.subtract(from: .us)
        board.subtract(from: .them)

        #expect(board.us == 0)
        #expect(board.them == 0)
    }

    @Test("A side with a point on it is the only side that can have one taken off")
    func knowsWhenItCanSubtract() {
        var board = Scoreboard()
        #expect(board.canSubtract(from: .us) == false)

        board.award(to: .us)
        #expect(board.canSubtract(from: .us))
        #expect(board.canSubtract(from: .them) == false)
    }

    @Test("A board nobody has scored on has no game on it to lose")
    func knowsWhenItHasStarted() {
        var board = Scoreboard()
        #expect(board.hasStarted == false)

        board.award(to: .them)
        #expect(board.hasStarted)

        board.subtract(from: .them)
        #expect(board.hasStarted == false, "taking the only point off leaves nothing again")
    }

    @Test("A new game clears the score but keeps how they are playing it")
    func resetKeepsTheTarget() {
        var board = Scoreboard(target: 15)
        board.award(to: .us)
        board.award(to: .them)
        board.reset()

        #expect(board.us == 0)
        #expect(board.them == 0)
        #expect(board.hasStarted == false)
        #expect(board.target == 15, "the target is a choice about today, not part of the score")
    }

    // MARK: - When it is won

    @Test("Reaching the target is not enough on its own")
    func targetAloneDoesNotWin() {
        var board = Scoreboard(us: 21, them: 20)
        #expect(board.winner == nil, "21-20 is still a game")

        board.award(to: .us)
        #expect(board.winner == .us, "22-20 is two clear")
    }

    @Test("Two clear is not enough on its own either")
    func twoClearAloneDoesNotWin() {
        let board = Scoreboard(us: 5, them: 3)
        #expect(board.winner == nil)
    }

    @Test("A game that runs on is won when somebody finally goes two clear")
    func longGamesAreWon() {
        var board = Scoreboard(us: 24, them: 24)
        #expect(board.winner == nil)

        board.award(to: .them)
        #expect(board.winner == nil, "25-24 is one clear")

        board.award(to: .them)
        #expect(board.winner == .them)
    }

    @Test("Either side can win it")
    func eitherSideWins() {
        #expect(Scoreboard(us: 21, them: 4).winner == .us)
        #expect(Scoreboard(us: 4, them: 21).winner == .them)
    }

    @Test("A target agreed on the way to the court is the one that decides it")
    func targetIsHonoured() {
        #expect(Scoreboard(us: 11, them: 9, target: 11).winner == .us)
        #expect(Scoreboard(us: 11, them: 9, target: 21).winner == nil)
    }

    @Test("Points are still accepted after the game is won")
    func keepsCountingPastTheEnd() {
        var board = Scoreboard(us: 21, them: 0)
        board.award(to: .them)

        #expect(board.them == 1, "the scoreboard is not the authority on when to stop")
        #expect(board.winner == .us)
    }

    // MARK: - Game point

    @Test("Game point is the point before the win, on the side that would take it")
    func namesGamePoint() {
        #expect(Scoreboard(us: 20, them: 4).onGamePoint == .us)
        #expect(Scoreboard(us: 4, them: 20).onGamePoint == .them)
    }

    @Test("Nobody is on game point when the next point would not end it")
    func noGamePointAtDeuce() {
        #expect(Scoreboard(us: 20, them: 20).onGamePoint == nil, "21-20 would not be two clear")
        #expect(Scoreboard(us: 5, them: 3).onGamePoint == nil)
    }

    @Test("A game already won is nobody's game point")
    func wonGamesHaveNoGamePoint() {
        #expect(Scoreboard(us: 21, them: 3).onGamePoint == nil)
    }

    @Test("Game point does exist in a long game, once someone is one clear")
    func gamePointPastTheTarget() {
        #expect(Scoreboard(us: 25, them: 24).onGamePoint == .us)
        #expect(Scoreboard(us: 24, them: 25).onGamePoint == .them)
    }

    // MARK: - What it says

    @Test("The line under the numbers says where the game is")
    func statusReadsBack() {
        #expect(Scoreboard(us: 0, them: 0).status.contains("playing to 21"))
        #expect(Scoreboard(us: 20, them: 20).status.contains("win by 2"))
        #expect(Scoreboard(us: 20, them: 4).status.contains("game point"))
        #expect(Scoreboard(us: 21, them: 4).status == "US WIN")
        #expect(Scoreboard(us: 4, them: 21).status == "THEM WIN")
    }

    @Test("A game half played survives being written down and read back")
    func roundTrips() throws {
        var board = Scoreboard(target: 15)
        board.award(to: .us)
        board.award(to: .them)
        board.award(to: .us)

        let read = try JSONDecoder().decode(Scoreboard.self, from: JSONEncoder().encode(board))
        #expect(read == board)
    }

    @Test("A board written by an earlier build is read as far as it goes")
    func readsAnOlderBoard() throws {
        // The shape that shipped before the minus buttons carried a history of every score,
        // which nothing reads now. A game in progress must survive the change -- there is
        // no copy of it anywhere else.
        let earlier = #"{"us":7,"them":5,"target":15,"history":[{"us":0,"them":0}]}"#
        let read = try JSONDecoder().decode(Scoreboard.self, from: Data(earlier.utf8))

        #expect(read == Scoreboard(us: 7, them: 5, target: 15))
    }

    @Test("A board missing a target is played to the usual one, not to nothing")
    func fillsInAMissingTarget() throws {
        let partial = #"{"us":2,"them":1}"#
        let read = try JSONDecoder().decode(Scoreboard.self, from: Data(partial.utf8))

        #expect(read.target == targetScore)
        #expect(read.us == 2)
    }
}

// MARK: - Telling the wrist what landed

@Suite("How the wrist learns a serve is safe")
struct AcknowledgementTests {
    private func serve(_ id: String) -> RawEvent {
        ["eventId": .string(id), "t": "RECORD_SERVE", "outcome": "OUT"]
    }

    @Test("The phone offers the identifiers it holds")
    func namesWhatItHolds() {
        let log = ["a", "b", "c"].map(serve)
        #expect(acknowledgedIds(in: log) == ["a", "b", "c"])
    }

    @Test("A season's worth is capped, newest kept")
    func capsTheList() {
        let log = (0..<200).map { serve("e\($0)") }
        let ids = acknowledgedIds(in: log, limit: 50)

        #expect(ids.count == 50)
        #expect(ids.last == "e199", "the newest are the ones the wrist might still be waiting on")
        #expect(ids.first == "e150")
    }

    @Test("An event with no identifier is simply not offered")
    func skipsUnidentifiedEvents() {
        let log: [RawEvent] = [serve("a"), ["t": "RECORD_SERVE"], serve("b")]
        #expect(acknowledgedIds(in: log) == ["a", "b"])
    }

    @Test("A serve the phone holds stops showing as unsent")
    func confirmsFromTheCourt() {
        var queue = PendingQueue()
        queue.add(serve("a"))
        queue.add(serve("b"))
        #expect(queue.label == "2 serves not sent")

        queue.confirm(Set(acknowledgedIds(in: [serve("a")])))
        #expect(queue.count == 1)
        #expect(queue.label == "1 serve not sent")

        queue.confirm(Set(acknowledgedIds(in: [serve("a"), serve("b")])))
        #expect(queue.label == nil, "nothing outstanding says nothing at all")
    }

    @Test("The court carries what the phone holds, and it survives the trip")
    func travelsWithTheCourt() throws {
        let snapshot = CourtSnapshot(
            sequence: 3,
            capturedAt: Date(),
            scopeLabel: "Match 1",
            hasOrder: true,
            slots: [],
            acknowledgedEventIds: ["a", "b"]
        )

        let read = try JSONDecoder().decode(CourtSnapshot.self, from: JSONEncoder().encode(snapshot))
        #expect(read.acknowledgedEventIds == ["a", "b"])
    }

    @Test("A court sent by a phone that never knew about this reads as knowing nothing")
    func olderPhonesAcknowledgeNothing() throws {
        let legacy = #"{"sequence":1,"capturedAt":0,"scopeLabel":"Match 1","hasOrder":false,"slots":[]}"#
        let read = try JSONDecoder().decode(CourtSnapshot.self, from: Data(legacy.utf8))

        #expect(read.acknowledgedEventIds.isEmpty, "and so confirms nothing, rather than everything")
    }
}

// MARK: - Saying thank you

@Suite("The tip jar")
struct SupportLinkTests {
    @Test("A real page is accepted")
    func acceptsAPage() throws {
        let link = try #require(SupportLink("https://ko-fi.com/example"))
        #expect(link.url.host == "ko-fi.com")
    }

    @Test("A page that goes nowhere is no tip jar at all")
    func refusesNothing() {
        // The screen shows no section when this is nil, so an address nobody filled in ships
        // as an app with no tip jar rather than an app with a dead button in it.
        #expect(SupportLink("") == nil)
        #expect(SupportLink("   ") == nil)
        #expect(SupportLink("ko-fi.com/example") == nil, "no scheme is not a link")
    }

    @Test("It must be https, because it is about to ask somebody for money")
    func insistsOnHttps() {
        #expect(SupportLink("http://ko-fi.com/example") == nil)
        #expect(SupportLink("vbtracker://donate") == nil)
        #expect(SupportLink("mailto:someone@example.com") == nil)
    }

    @Test("The asking is one sentence, and does not ask twice")
    func theAskIsSmall() {
        #expect(SupportLink.invitation.filter { $0 == "." }.count <= 2)
        #expect(SupportLink.invitation.lowercased().contains("please") == false)
        #expect(SupportLink.invitation.lowercased().contains("optional"))
        #expect(SupportLink.action.hasSuffix("!") == false, "a noun, not an exclamation")
    }

    @Test("The about page says the things somebody would check before trusting it")
    func factsCoverTheQuestions() {
        let all = About.facts.joined(separator: " ").lowercased()
        #expect(all.contains("free"))
        #expect(all.contains("no adverts"))
        #expect(all.contains("nothing locked"))
        #expect(all.contains("no networking"))
        #expect(About.tagline.isEmpty == false)
    }

    @Test("The build is named, however little of it is known")
    func versionLineAlwaysSaysSomething() {
        #expect(About.versionLine(version: "1.0", build: "12") == "Version 1.0 (12)")
        #expect(About.versionLine(version: "1.0", build: nil) == "Version 1.0")
        #expect(About.versionLine(version: nil, build: "12") == "Version unknown")
    }
}
