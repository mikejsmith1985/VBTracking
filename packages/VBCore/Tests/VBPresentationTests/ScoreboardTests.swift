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

@Suite("How big the scoreboard's controls are")
struct ScoreLayoutTests {
    @Test("Scoring is the big control and correcting is the small one")
    func theScoreIsTheBigTarget() {
        let ratio = ScoreLayout.scoreHeight / ScoreLayout.minusPillHeight
        #expect(
            ratio >= ScoreLayout.minimumScoreToMinusRatio,
            "adding a point happens every rally; taking one off happens on a mistake"
        )
        // The glyph follows the same ratio as the control it sits in, rather than a
        // tighter one of its own -- a minus drawn too faint to see is the reason the mark
        // grew in the first place.
        #expect(ScoreLayout.scoreFontSize >= ScoreLayout.minusFontSize * ScoreLayout.minimumScoreToMinusRatio)
    }

    @Test("The minus is drawn smaller than it is tapped")
    func drawnSmallTappedBigger() {
        // A control small enough to read as secondary is smaller than a thumb, so the two
        // are allowed to differ -- and the tap area is the one that has to be big enough.
        #expect(ScoreLayout.minusTapHeight > ScoreLayout.minusPillHeight)
        #expect(
            ScoreLayout.minusTapHeight >= ScoreLayout.minimumTapHeight,
            "below this it is a decoration, not a button"
        )
    }

    @Test("The score pill has room for the side's name as well as the figure")
    func theNameFitsInsideThePill() {
        // The name used to ride on the tile's edge, outside it. The tile has to hold both
        // lines with room to spare, or the same thing happens the next time a font grows.
        // Measured against line height, not point size: a 44 pt font does not occupy 44 pt.
        #expect(
            ScoreLayout.scoreHeight >= ScoreLayout.scoreContentHeight + 12,
            "\(ScoreLayout.scoreContentHeight)pt of text in a \(ScoreLayout.scoreHeight)pt tile"
        )
    }

    @Test("The whole page fits on the smallest watch anybody owns")
    func fitsTheSmallestWatch() {
        let usable = ScoreLayout.shortestScreenHeight * ScoreLayout.usableHeightFraction
        #expect(
            ScoreLayout.requiredHeight <= usable,
            "\(ScoreLayout.requiredHeight)pt of controls in \(usable)pt of screen"
        )
    }

    @Test("The page is worked out in points, not the pixels the court list is in")
    func usesPoints() {
        // The 40 mm watch is 324 x 394 pixels and 162 x 197 points. Reading one as the
        // other would lay this page out in twice the room it has.
        let smallestInPixels = CourtLayout.supportedWatchSizes[0]
        #expect(ScoreLayout.shortestScreenHeight == smallestInPixels.height / 2)
    }
}

@Suite("Whether the scoreboard can actually be read")
struct ScorePaletteTests {
    @Test("The figure stands off its tile hard enough to read across a court")
    func figuresAreLegible() {
        for side in Side.allCases {
            let ratio = contrastRatio(ScorePalette.figure, ScorePalette.fill(for: side))
            #expect(
                ratio >= ScorePalette.minimumFigureContrast,
                "\(side.label) is \(ratio):1 — the first attempt was a tint at 22% and vanished in a lit room"
            )
        }
    }

    @Test("The two sides are told apart by more than their labels")
    func theSidesAreDifferentColours() {
        #expect(ScorePalette.fill(for: .us) != ScorePalette.fill(for: .them))
    }

    @Test("The tiles are the bright thing and the lesser controls are not")
    func thePriorityIsInTheBrightness() {
        // A scoreboard read at arm's length has to put its brightness where the numbers are.
        for side in Side.allCases {
            #expect(
                contrastRatio(ScorePalette.fill(for: side), "#000000")
                    > contrastRatio(ScorePalette.controlFill, "#000000") * 2,
                "the minus bars are competing with the scores"
            )
        }
    }

    @Test("The lesser controls are still readable, just quieter")
    func controlsAreReadable() {
        #expect(
            contrastRatio(ScorePalette.controlInk, ScorePalette.controlFill)
                >= ScorePalette.minimumControlContrast
        )
        #expect(
            contrastRatio(ScorePalette.alertInk, ScorePalette.controlFill)
                >= ScorePalette.minimumControlContrast
        )
    }

    @Test("The status line reads against the screen behind it")
    func statusReadsOnBlack() {
        #expect(contrastRatio(ScorePalette.statusInk, "#000000") >= 7)
        #expect(contrastRatio(ScorePalette.alertInk, "#000000") >= 4.5)
    }

    @Test("Contrast is measured the way an eye sees it, not the way a screen stores it")
    func contrastFormulaIsRight() {
        // The known anchors of the WCAG formula. Getting this wrong would let every check
        // above pass on colours nobody can read.
        #expect(abs(contrastRatio("#ffffff", "#000000") - 21) < 0.01)
        #expect(abs(contrastRatio("#ffffff", "#ffffff") - 1) < 0.01)
        #expect(abs(contrastRatio("#767676", "#ffffff") - 4.54) < 0.05, "the classic 4.5:1 grey")
    }
}

@Suite("Whether the lesser controls can be found at all")
struct ControlVisibilityTests {
    @Test("A button's own background stands off the screen behind it")
    func controlsAreVisibleOnBlack() {
        // The first palette had every rule about ink on a fill and none about whether the
        // fill could be seen. The buttons came out near-black on a black screen.
        let ratio = contrastRatio(ScorePalette.controlFill, "#000000")
        #expect(
            ratio >= ScorePalette.minimumControlFillContrast,
            "the minus bars are \(ratio):1 against the screen — a button nobody can find is not a button"
        )
    }

    @Test("The minus mark has all the contrast a small mark needs")
    func theMinusIsHighContrast() {
        #expect(contrastRatio(ScorePalette.controlInk, ScorePalette.controlFill) >= 7)
    }

    @Test("The score is still the bigger target, just not by as much")
    func theScoreStaysTheBigOne() {
        let ratio = ScoreLayout.scoreHeight / ScoreLayout.minusPillHeight
        #expect(ratio >= ScoreLayout.minimumScoreToMinusRatio)
        #expect(ratio < 4, "a minus too small to hit while watching a court is no use either")
    }
}
