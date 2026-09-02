// Everything the screens would otherwise decide for themselves.
//
// There is no Mac here, so a SwiftUI view cannot be run. These are the decisions that would
// have gone unchecked: what a missing figure reads as, which box is biggest, what a tap
// means, and whether the wrist is telling the truth about how current it is.
import Foundation
import Testing
import VBCore

@testable import VBPresentation

// MARK: - Figures

@Suite("How a figure reads")
struct FormattingTests {
    @Test("A figure that was never recorded is a dash, never a zero")
    func missingIsADash() {
        #expect(text(count: nil) == "—")
        #expect(text(percentage: nil) == "—")
        #expect(text(count: 0) == "0", "a recorded nought is still a nought")
    }

    @Test("A percentage is whole points, rounded rather than cut short")
    func roundsPercentage() {
        #expect(text(percentage: 2.0 / 3.0) == "67%")
        #expect(text(percentage: 0.5) == "50%")
        #expect(text(percentage: 1) == "100%")
        #expect(text(percentage: 0) == "0%", "served and missed every one is a real figure")
    }

    @Test("A player with no jersey number stays identifiable")
    func marksMissingNumber() {
        #expect(text(number: nil) == "–")
        #expect(text(number: "  ") == "–")
        #expect(text(number: "07") == "07", "a leading zero survives")
    }

    @Test("An unrecorded result is a dash, not a loss")
    func undecidedIsNotALoss() {
        #expect(text(result: .undecided) == "—")
        #expect(text(result: .won) == "Won")
        #expect(text(result: .lost) == "Lost")
    }

    @Test("A record names the games left unrecorded rather than hiding them")
    func recordNamesUndecided() {
        #expect(text(record: Record(won: 3, lost: 2)) == "3–2")
        #expect(text(record: Record(won: 3, lost: 2, undecided: 1)) == "3–2 · 1 not recorded")
    }

    @Test("How long ago is said coarsely, because it is read at a glance")
    func saysHowLongAgo() {
        #expect(text(secondsAgo: 2) == "just now")
        #expect(text(secondsAgo: 12) == "12s ago")
        #expect(text(secondsAgo: 300) == "5m ago")
        #expect(text(secondsAgo: 7200) == "over an hour ago")
    }
}

// MARK: - The wrist

@Suite("How big each box on the wrist is")
struct CourtLayoutTests {
    private var boxes: [BoxSize] {
        CourtLayout.boxes(in: CourtLayout.designSize)
    }

    @Test("The on-deck box is the biggest thing on the screen")
    func onDeckIsBiggest() throws {
        let onDeck = try #require(boxes.first { $0.position == .rightFront })
        let others = boxes.filter { $0.position != .rightFront }

        for box in others {
            #expect(onDeck.area > box.area, "bigger than \(box.position)")
        }
    }

    @Test("It clears the stated margin, and by a margin that can be measured")
    func clearsTheRequiredMargin() throws {
        let onDeck = try #require(boxes.first { $0.position == .rightFront })
        let smallest = try #require(boxes.map(\.area).min())

        // SC-014: at least one and a half times the smallest box, on the 42 mm screen.
        #expect(onDeck.area >= smallest * 1.5)
    }

    @Test("The on-deck box is biggest on every watch the app can be installed on")
    func biggestOnEverySupportedWatch() throws {
        // The operator's own watch is an Ultra 2, but the app has to be readable on the
        // smallest one Apple still supports -- and the layout has to hold at both ends.
        for watch in CourtLayout.supportedWatchSizes {
            let boxes = CourtLayout.boxes(in: (width: watch.width, height: watch.height))
            let onDeck = try #require(boxes.first { $0.position == .rightFront })
            let smallest = try #require(boxes.map(\.area).min())

            #expect(onDeck.area >= smallest * 1.5, "on \(watch.name)")
        }
    }

    @Test("No box is too small to read a number in, on any supported watch")
    func readableOnEverySupportedWatch() {
        for watch in CourtLayout.supportedWatchSizes {
            for box in CourtLayout.boxes(in: (width: watch.width, height: watch.height)) {
                #expect(box.width > 60, "\(box.position) is too narrow on \(watch.name)")
                #expect(box.height > 50, "\(box.position) is too short on \(watch.name)")
            }
        }
    }

    @Test("The design target is the smallest watch, not the operator's own")
    func designsForTheSmallest() throws {
        let smallest = try #require(CourtLayout.supportedWatchSizes.first)

        #expect(CourtLayout.designSize.width == smallest.width)
        #expect(CourtLayout.designSize.height == smallest.height)
    }

    @Test("Every box still fits on the smaller watch")
    func fitsTheSmallerWatch() {
        let width = boxes.filter { $0.position == .leftFront || $0.position == .middleFront || $0.position == .rightFront }
            .reduce(0) { $0 + $1.width }
        let height = boxes.filter { $0.position == .leftFront }.reduce(0) { $0 + $1.height }
            + boxes.filter { $0.position == .leftBack }.reduce(0) { $0 + $1.height }

        #expect(width < CourtLayout.designSize.width)
        #expect(height < CourtLayout.designSize.height)
    }

    @Test("No box is too small to read a number in")
    func nothingIsUnreadable() {
        // The smallest box still has to carry a jersey number at 32 points.
        for box in boxes {
            #expect(box.width > 60, "\(box.position) is too narrow")
            #expect(box.height > 50, "\(box.position) is too short")
        }
    }

    @Test("Six boxes, one per position, in the order they are drawn")
    func drawsSixBoxes() {
        #expect(boxes.count == 6)
        #expect(boxes.map(\.position) == CourtPosition.drawingOrder)
    }

    @Test("The court still fits on a larger watch, with everything bigger")
    func scalesUp() {
        let larger = CourtLayout.boxes(in: (width: 416, height: 496))
        for (small, large) in zip(boxes, larger) {
            #expect(large.area > small.area, "\(small.position) grows with the screen")
        }
    }

    @Test("The number is the largest thing in a box, and largest of all on deck")
    func typographyFollowsTheDecision() {
        let onDeck = BoxTypography.forBox(isOnDeck: true)
        let other = BoxTypography.forBox(isOnDeck: false)

        #expect(onDeck.number > onDeck.percentage)
        #expect(onDeck.percentage > onDeck.points)
        #expect(onDeck.points > onDeck.pointsLabel, "the count outranks the word beside it")
        #expect(onDeck.number > other.number, "the box being decided about is the readable one")

        // Read from a wrist across a gym. The figures under the number were the two things
        // somebody had to lean in for, so they have a floor now -- one that a later tidy-up
        // of the type scale cannot quietly drop back below.
        for type in [onDeck, other] {
            #expect(type.percentage >= 15, "the serve-in figure must be legible at arm's length")
            #expect(type.points >= 14, "so must the points")
        }
    }
}

// MARK: - The dock

@Suite("What is under the thumb")
struct DockTests {
    @Test("With someone serving, the outcomes are shown and the picker is not")
    func showsOutcomesWhileServing() {
        let state = onCourt([event(.selectServer(playerId: "p1"))])
        let dock = DockState(state: state, isPickerRequested: false, canUndo: true)

        #expect(dock.content == .outcomes(servingPlayerId: "p1"))
        #expect(dock.isRecording)
    }

    @Test("With nobody serving, the picker is shown")
    func showsPickerWhenNobodyServes() {
        let state = build(roster(3), [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))])
        let dock = DockState(state: state, isPickerRequested: false, canUndo: false)

        #expect(dock.content == .picker)
        #expect(dock.isRecording == false)
    }

    @Test("The operator can ask for the picker mid-turn, and gets it")
    func honoursTheOverride() {
        let state = onCourt([event(.selectServer(playerId: "p1"))])
        let dock = DockState(state: state, isPickerRequested: true, canUndo: true)

        #expect(dock.content == .picker, "the operator's own override wins")
    }

    @Test("With no match, there is nothing to record into and nothing is offered")
    func offersNothingWithoutAMatch() {
        let dock = DockState(state: build(roster(3)), isPickerRequested: false, canUndo: false)
        #expect(dock.content == .nothing)
    }

    @Test("It never shows both at once")
    func neverBoth() {
        let serving = DockState(state: onCourt([event(.selectServer(playerId: "p1"))]), isPickerRequested: false, canUndo: true)
        let picking = DockState(state: onCourt(), isPickerRequested: false, canUndo: true)

        #expect(serving.content != picking.content)
        #expect(serving.isRecording != picking.isRecording)
    }
}

@Suite("The five-serve alert")
struct ServeLimitAlertTests {
    /// A player who has just taken their fifth serve, with the order advancing.
    private func afterFive() -> (state: AppState, serving: String) {
        var events: [Event] = [event(.selectServer(playerId: "p1"))]
        events += (0..<serveLimit).map { _ in event(.recordServe(outcome: .inPoint)) }
        return (onCourt(events), "p1")
    }

    @Test("It is raised on the fifth serve")
    func raisedAtTheLimit() {
        let (state, serving) = afterFive()
        let alert = ServeLimitAlert.raised(after: state, servingPlayerId: serving)

        #expect(alert?.finishedPlayerId == "p1")
        #expect(alert?.nextPlayerId == "p2")
    }

    @Test("It is not raised on the fourth")
    func silentBeforeTheLimit() {
        var events: [Event] = [event(.selectServer(playerId: "p1"))]
        events += (0..<4).map { _ in event(.recordServe(outcome: .inPoint)) }

        #expect(ServeLimitAlert.raised(after: onCourt(events), servingPlayerId: "p1") == nil)
    }

    @Test("It names no next server when there is no order to name one from")
    func silentAboutTheNextServer() {
        var events = roster(3) + [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))]
        events += [event(.selectServer(playerId: "p1"))]
        events += (0..<serveLimit).map { _ in event(.recordServe(outcome: .inPoint)) }

        let alert = ServeLimitAlert.raised(after: replay(events), servingPlayerId: "p1")
        #expect(alert?.finishedPlayerId == "p1")
        #expect(alert?.nextPlayerId == nil, "the same player still holds the ball")
    }

    @Test("A sixth serve does not raise it a second time")
    func raisedOnlyOnce() {
        var events = roster(3) + [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))]
        events += [event(.selectServer(playerId: "p1"))]
        events += (0..<6).map { _ in event(.recordServe(outcome: .inPoint)) }

        #expect(ServeLimitAlert.raised(after: replay(events), servingPlayerId: "p1") == nil)
    }
}

// MARK: - What a column covers

@Suite("Saying which games a column covers")
struct CoverageWordingTests {
    @Test("A season tracked all the way through explains nothing, because there is nothing to explain")
    func silentWhenFullyTracked() {
        let coverage = Coverage(totalGames: 4, trackedGames: 4)
        #expect(isPointsASubset(coverage) == false)
        #expect(pointsHeading(coverage: coverage) == "Pts")
        #expect(coverageNote(coverage) == nil)
    }

    @Test("A season with games from paper marks the points column and says why")
    func marksTheSubset() {
        let coverage = Coverage(totalGames: 5, trackedGames: 1)
        #expect(isPointsASubset(coverage))
        #expect(pointsHeading(coverage: coverage) == "Pts*")

        let note = coverageNote(coverage)
        #expect(note?.contains("1 game of 5") == true, "both counts, so the reader can judge the figure")
        #expect(note?.contains("other 4 games") == true)
        #expect(note?.contains("dash") == true, "a dash is not a nought, and the note has to say so")
    }

    @Test("The sentence reads as one a person would say, whichever way the counts fall")
    func pluralsRead() {
        #expect(coverageNote(Coverage(totalGames: 2, trackedGames: 1))?.contains("other 1 game") == true)
        #expect(coverageNote(Coverage(totalGames: 3, trackedGames: 2))?.contains("2 games of 3") == true)
    }

    @Test("A screen with no coverage to report says nothing rather than guessing")
    func silentWithoutCoverage() {
        #expect(isPointsASubset(nil) == false)
        #expect(pointsHeading(coverage: nil) == "Pts")
        #expect(coverageNote(nil) == nil)
    }
}

// MARK: - Tapping

/// The same six, once a serve is on the record — after which the order is a fact and the
/// only way to change who stands where is a substitution.
private func underWay() -> AppState {
    onCourt([
        event(.selectServer(playerId: "p1")),
        event(.recordServe(outcome: .inPoint)),
    ])
}

@Suite("What a tap on a player means")
struct TapIntentTests {
    @Test("Someone in the order is simply the next server")
    func onCourtPlayerServes() {
        #expect(intent(ofTapping: "p3", state: onCourt(), armed: nil) == .serve(playerId: "p3"))
    }

    @Test("Someone on the bench is the player coming on")
    func benchPlayerArms() {
        #expect(intent(ofTapping: "p8", state: onCourt(), armed: nil) == .armSubstitution(incomingPlayerId: "p8"))
    }

    @Test("Mid-match, tapping a player on court with one armed completes the swap")
    func completesTheSwap() {
        let result = intent(ofTapping: "p3", state: underWay(), armed: .player("p8"))
        #expect(result == .substitute(outPlayerId: "p3", inPlayerId: "p8"))
    }

    @Test("Before the first serve the same two taps arrange rather than substitute")
    func arrangesBeforeTheFirstServe() {
        let result = intent(ofTapping: "p3", state: onCourt(), armed: .player("p8"))
        #expect(
            result == .place(playerId: "p8", lineupIndex: 2),
            "a substitution nobody made would be a swap in the record that never happened"
        )
    }

    @Test("Tapping a different bench player re-aims rather than refusing")
    func reAims() {
        let result = intent(ofTapping: "p9", state: onCourt(), armed: .player("p8"))
        #expect(result == .armSubstitution(incomingPlayerId: "p9"))
    }

    @Test("Tapping the armed player again serves them without substituting")
    func servesTheArmedPlayer() {
        let result = intent(ofTapping: "p8", state: onCourt(), armed: .player("p8"))
        #expect(result == .serve(playerId: "p8"))
    }

    @Test("With a spot held, the next player tapped stands in it")
    func placesIntoTheHeldSpot() {
        #expect(
            intent(ofTapping: "p8", state: onCourt(), armed: .position(4))
                == .place(playerId: "p8", lineupIndex: 4)
        )
    }

    @Test("Without an order, a tap picks the player up so they can be placed")
    func withoutAnOrderATapArms() {
        // This used to serve them outright, which meant an operator building a rotation
        // player-first started recording that player's serves on their first tap.
        let state = build(roster(3), [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))])
        #expect(intent(ofTapping: "p2", state: state, armed: nil) == .armSubstitution(incomingPlayerId: "p2"))
    }

    @Test("Tapping them a second time hands them the ball, order or no order")
    func aSecondTapStillServes() {
        // The way out for an operator who wants no rotation at all and is simply naming
        // whoever serves next.
        let state = build(roster(3), [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))])
        #expect(intent(ofTapping: "p2", state: state, armed: .player("p2")) == .serve(playerId: "p2"))
    }

    @Test("Tapping whoever is already serving does nothing")
    func ignoresTheCurrentServer() {
        let state = build(
            roster(3),
            [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false)), event(.selectServer(playerId: "p1"))]
        )
        #expect(intent(ofTapping: "p1", state: state, armed: nil) == .ignore)
    }
}

@Suite("What a tap on a place on the court means")
struct PositionTapTests {
    @Test("An empty spot with nothing held is picked up, waiting for a player")
    func armsThePosition() {
        #expect(intent(ofTappingPosition: 3, state: onCourt(), armed: nil) == .armPosition(lineupIndex: 3))
    }

    @Test("With a player held, the spot is where they stand")
    func placesTheHeldPlayer() {
        #expect(
            intent(ofTappingPosition: 3, state: onCourt(), armed: .player("p8"))
                == .place(playerId: "p8", lineupIndex: 3)
        )
    }

    @Test("Tapping the held spot again puts it down")
    func tappingTheHeldSpotCancels() {
        #expect(intent(ofTappingPosition: 3, state: onCourt(), armed: .position(3)) == .ignore)
    }

    @Test("Tapping a different spot moves the hold to it")
    func tappingAnotherSpotReAims() {
        #expect(
            intent(ofTappingPosition: 5, state: onCourt(), armed: .position(3))
                == .armPosition(lineupIndex: 5)
        )
    }

    @Test("There are six places, and a tap outside them does nothing")
    func refusesAPlaceOffTheCourt() {
        #expect(intent(ofTappingPosition: 6, state: onCourt(), armed: .player("p8")) == .ignore)
        #expect(intent(ofTappingPosition: -1, state: onCourt(), armed: nil) == .ignore)
    }
}

@Suite("What the hint under the picker says")
struct PickerHintTests {
    @Test("A held spot asks for the player who stands in it, by place in the order")
    func heldSpotAsksWho() {
        let hint = pickerHint(state: onCourt(), armed: .position(0))
        #expect(hint.contains("1st"))
        #expect(pickerHint(state: onCourt(), armed: .position(3)).contains("4th"))
    }

    @Test("A held player before the first serve offers a spot; after it, a substitution")
    func heldPlayerReadsTheMoment() {
        #expect(pickerHint(state: onCourt(), armed: .player("p8")).contains("tap a spot"))
        #expect(pickerHint(state: underWay(), armed: .player("p8")).contains("is coming on"))
    }

    @Test("With nothing held, the hint says where the serving corner is")
    func restingHintNamesTheCorner() {
        #expect(pickerHint(state: underWay(), armed: nil).contains("bottom right"))
        // Six standing and nobody serving yet: the job is to start, not to keep arranging.
        #expect(pickerHint(state: onCourt(), armed: nil).contains("serves first"))
    }

    @Test("With no order at all, the hint offers both ways in")
    func noOrderHintOffersBothWaysIn() {
        let noOrder = build(roster(3), [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))])
        let hint = pickerHint(state: noOrder, armed: nil)
        #expect(hint.contains("spot"))
        #expect(hint.contains("player"))
    }

    @Test("A place in the order is spoken as a place, not a number")
    func ordinalsRead() {
        #expect(ordinal(1) == "1st")
        #expect(ordinal(2) == "2nd")
        #expect(ordinal(3) == "3rd")
        #expect(ordinal(4) == "4th")
        #expect(ordinal(6) == "6th")
    }
}

// MARK: - The link

@Suite("What travels to the wrist")
struct SnapshotTests {
    private func snapshot(_ state: AppState, sequence: Int = 1) -> CourtSnapshot? {
        state.courtView().map { CourtSnapshot(court: $0, sequence: sequence, capturedAt: Date()) }
    }

    @Test("It carries six boxes, with the server in the service corner")
    func carriesTheCourt() {
        let snapshot = snapshot(onCourt([event(.selectServer(playerId: "p1"))]))

        #expect(snapshot?.slots.count == 6)
        #expect(snapshot?.slots.last?.court == 1)
        #expect(snapshot?.slots.last?.isServing == true)
        #expect(snapshot?.slots.last?.number == "1")
    }

    @Test("A figure never recorded travels as absent, not as zero")
    func carriesAbsence() {
        let snapshot = snapshot(onCourt([event(.selectServer(playerId: "p1"))]))
        let waiting = snapshot?.slots.first { $0.number == "4" }

        #expect(waiting?.inPercentage == nil)
        #expect(waiting?.points == nil)
    }

    @Test("Without an order, nothing is marked as on deck")
    func marksNobodyOnDeckWithoutAnOrder() {
        let state = build(
            roster(3),
            [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false)), event(.selectServer(playerId: "p1"))]
        )
        let snapshot = snapshot(state)

        #expect(snapshot?.hasOrder == false)
        #expect(snapshot?.slots.contains { $0.isOnDeck } == false)
    }

    @Test("It survives being encoded and read back")
    func roundTrips() throws {
        let original = try #require(snapshot(onCourt([event(.selectServer(playerId: "p1"))])))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CourtSnapshot.self, from: data)

        #expect(decoded == original)
    }

    @Test("Only one box serves, and only one is on deck")
    func oneOfEach() {
        let snapshot = snapshot(onCourt([event(.selectServer(playerId: "p1"))]))
        #expect(snapshot?.slots.filter(\.isServing).count == 1)
        #expect(snapshot?.slots.filter(\.isOnDeck).count == 1)
    }
}

@Suite("How current the wrist is")
struct FreshnessTests {
    private let captured = Date(timeIntervalSince1970: 1_000_000)

    @Test("A picture from a moment ago is current")
    func recentIsCurrent() {
        let freshness = LinkFreshness(capturedAt: captured, now: captured.addingTimeInterval(3))
        #expect(freshness.isCurrent)
        #expect(freshness.label == "just now")
    }

    @Test("A picture past the threshold says plainly that it is not current")
    func staleSaysSo() {
        let freshness = LinkFreshness(capturedAt: captured, now: captured.addingTimeInterval(60))
        #expect(freshness.isCurrent == false)
        #expect(freshness.label.contains("not current"))
        #expect(freshness.label.contains("1m ago"))
    }

    @Test("A clock that runs backwards does not report a picture from the future")
    func clampsNegativeAge() {
        let freshness = LinkFreshness(capturedAt: captured, now: captured.addingTimeInterval(-30))
        #expect(freshness.secondsOld == 0)
    }
}

@Suite("Serves recorded on the wrist")
struct PendingQueueTests {
    private func serve(_ id: String) -> RawEvent {
        ["eventId": .string(id), "t": "RECORD_SERVE", "outcome": "OUT"]
    }

    @Test("Nothing is shown when everything has landed")
    func silentWhenEmpty() {
        #expect(PendingQueue().label == nil)
    }

    @Test("What has not landed is counted, so it is never assumed safe")
    func countsWhatIsPending() {
        var queue = PendingQueue()
        queue.add(serve("a"))
        #expect(queue.label == "1 serve not sent")

        queue.add(serve("b"))
        #expect(queue.label == "2 serves not sent")
    }

    @Test("Confirmed serves leave the queue, in whatever order they are confirmed")
    func clearsOnConfirmation() {
        var queue = PendingQueue()
        queue.add(serve("a"))
        queue.add(serve("b"))
        queue.confirm(["b"])

        #expect(queue.count == 1)
        #expect(queue.events.first?["eventId"]?.stringValue == "a")
    }
}

@Suite("Merging what the wrist recorded")
struct MergeTests {
    private func serve(_ id: String) -> RawEvent {
        ["eventId": .string(id), "t": "RECORD_SERVE", "outcome": "OUT"]
    }

    @Test("A new serve is appended, and reads no differently from one recorded on the phone")
    func appendsNewEvents() {
        let result = merge(incoming: [serve("a")], into: [])
        #expect(result.log.count == 1)
        #expect(result.accepted == ["a"])
    }

    @Test("A serve already held is ignored, however many times it is delivered")
    func ignoresDuplicates() {
        let existing = [serve("a")]
        let result = merge(incoming: [serve("a"), serve("a")], into: existing)

        #expect(result.log.count == 1, "delivery may retry; the record may not double")
        #expect(result.accepted.isEmpty)
    }

    @Test("Two identical deliveries in one batch still land once")
    func deduplicatesWithinABatch() {
        let result = merge(incoming: [serve("b"), serve("b")], into: [serve("a")])
        #expect(result.log.count == 2)
        #expect(result.accepted == ["b"])
    }

    @Test("An event with no identifier is refused rather than guessed at")
    func refusesUnnamedEvents() {
        let unnamed: RawEvent = ["t": "RECORD_SERVE", "outcome": "OUT"]
        let result = merge(incoming: [unnamed], into: [])

        #expect(result.log.isEmpty)
    }

    @Test("Order is kept: the wrist's serves land in the order they were taken")
    func keepsOrder() {
        let result = merge(incoming: [serve("b"), serve("c")], into: [serve("a")])
        #expect(result.log.compactMap { $0["eventId"]?.stringValue } == ["a", "b", "c"])
    }
}
