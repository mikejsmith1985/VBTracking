// A match, driven through the real app by real taps.
//
// The domain suite proves the rules; this proves the rules are wired to the things the
// operator actually touches. It runs on the build machine, because it is the only place a
// screen exists.
import XCTest

// XCUITest drives a running app, so every one of its APIs is main-actor isolated -- and
// `setUp` is not, even inside a main-actor class. So there is no `setUp`: each test says
// what it launches, which reads better anyway.
@MainActor
final class TrackingUITests: XCTestCase {
    private var app = XCUIApplication()

    /// A clean container each run: a test that inherits last run's season proves nothing.
    private func launch() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFreshStore"]
        app.launch()
    }

    func testAServeIsRecordedInOneTap() {
        launch()
        addPlayers(["7": "Ella", "5": "Aria"])
        app.buttons["Track"].tap()
        app.buttons["Start game"].tap()

        firstPlayerChip().tap()
        app.buttons["serve-IN_POINT"].tap()

        app.buttons["Game"].tap()
        XCTAssertTrue(app.staticTexts["1/1"].waitForExistence(timeout: 3), "one serve, one landed in")
    }

    func testOneUndoReversesExactlyOneAction() {
        launch()
        addPlayers(["7": "Ella", "5": "Aria"])
        app.buttons["Track"].tap()
        app.buttons["Start game"].tap()
        firstPlayerChip().tap()

        app.buttons["serve-IN_POINT"].tap()
        app.buttons["serve-IN_POINT"].tap()
        app.buttons["undo"].tap()

        app.buttons["Game"].tap()
        XCTAssertTrue(app.staticTexts["1/1"].waitForExistence(timeout: 3), "one serve reversed, not two")
    }

    func testTheFiveServeAlertInterrupts() {
        launch()
        addPlayers(["7": "Ella", "5": "Aria"])
        app.buttons["Track"].tap()
        app.buttons["Start game"].tap()
        firstPlayerChip().tap()

        for _ in 0..<5 { app.buttons["serve-IN_POINT"].tap() }

        let alert = app.otherElements["serve-limit-alert"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3), "five serves must interrupt")

        alert.tap()
        XCTAssertFalse(alert.exists, "any tap clears it")
    }

    func testASixthServeIsRecordedWithoutNaggingAgain() {
        launch()
        addPlayers(["7": "Ella", "5": "Aria"])
        app.buttons["Track"].tap()
        app.buttons["Start game"].tap()
        firstPlayerChip().tap()

        for _ in 0..<5 { app.buttons["serve-IN_POINT"].tap() }
        app.otherElements["serve-limit-alert"].tap()
        app.buttons["serve-IN_POINT"].tap()

        XCTAssertFalse(app.otherElements["serve-limit-alert"].exists, "a miscount is recorded, not nagged about")
    }

    func testTheDockNeverShowsBothOutcomesAndThePicker() {
        launch()
        addPlayers(["7": "Ella", "5": "Aria"])
        app.buttons["Track"].tap()
        app.buttons["Start game"].tap()

        // Before a server is chosen: the picker, and no outcome controls.
        XCTAssertFalse(app.buttons["serve-OUT"].exists)
        firstPlayerChip().tap()

        // After: the outcome controls, and no picker.
        XCTAssertTrue(app.buttons["serve-OUT"].waitForExistence(timeout: 3))
        XCTAssertEqual(playerChips().count, 0, "a control that is present but wrong is a mis-tap")
    }

    // MARK: - Getting to a match

    private func addPlayers(_ players: [String: String]) {
        app.buttons["Roster"].tap()
        for (number, name) in players.sorted(by: { $0.key < $1.key }) {
            app.textFields["Name"].tap()
            app.textFields["Name"].typeText(name)
            app.textFields["Number"].tap()
            app.textFields["Number"].typeText(number)
            app.buttons["Add"].tap()
        }
    }

    private func playerChips() -> [XCUIElement] {
        app.buttons.allElementsBoundByIndex.filter { $0.identifier.hasPrefix("player-") }
    }

    private func firstPlayerChip() -> XCUIElement {
        let chip = playerChips().first
        XCTAssertNotNil(chip, "the picker must offer someone to serve")
        return chip ?? app.buttons.firstMatch
    }
}

/// Saving a copy of everything, and where it can be reached from.
@MainActor
final class TransferUITests: XCTestCase {
    func testTheExportIsReachableWithNoGameInProgress() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestFreshStore"]
        app.launch()

        // It used to live on the game screen, which shows nothing until a game exists -- so
        // an operator between games had no way to save their season.
        app.buttons["Season"].tap()
        XCTAssertTrue(app.buttons["export-data"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["import-data"].exists)
    }
}

/// Building a rotation on the court, and using it.
///
/// Three bugs shipped here at once, and every one of them was invisible to the domain suite
/// because every one was about what a tap does to a screen. This is the suite that would
/// have caught them.
@MainActor
final class RotationUITests: XCTestCase {
    private var app = XCUIApplication()

    private func launchWithSix() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFreshStore"]
        app.launch()

        app.buttons["Roster"].tap()
        for number in ["1", "2", "3", "4", "5", "6", "7"] {
            app.textFields["Name"].tap()
            app.textFields["Name"].typeText("Player \(number)")
            app.textFields["Number"].tap()
            app.textFields["Number"].typeText(number)
            app.buttons["Add"].tap()
        }
        app.buttons["Track"].tap()
        app.buttons["Start game"].tap()
    }

    private func emptySpots() -> [XCUIElement] {
        app.buttons.allElementsBoundByIndex.filter { $0.identifier == "empty-spot" }
    }

    private func playerChips() -> [XCUIElement] {
        app.buttons.allElementsBoundByIndex.filter { $0.identifier.hasPrefix("player-") }
    }

    func testAnEmptySpotIsTappableAnywhereInsideIt() {
        launchWithSix()

        let spot = emptySpots().first
        XCTAssertNotNil(spot, "six empty places must be offered")
        guard let spot else { return }

        // The middle of the box, which is where anybody aims. The box used to be drawn with
        // a stroked border and no fill, so only the 1pt outline was hittable and taps in
        // the middle did nothing at all.
        spot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue(
            app.staticTexts["WHO?"].waitForExistence(timeout: 3),
            "one tap in the middle of a spot must pick it up"
        )
    }

    func testAPlayerCanBePickedUpBeforeASpotIsChosen() {
        launchWithSix()

        let chip = playerChips().first
        XCTAssertNotNil(chip)
        chip?.tap()

        // It used to start recording that player's serves, which made building a rotation
        // player-first impossible.
        XCTAssertFalse(app.buttons["serve-OUT"].exists, "a first tap must not start a turn")
        XCTAssertTrue(emptySpots().count > 0, "the court is still there to place them on")

        emptySpots().first?.tap()
        XCTAssertEqual(emptySpots().count, 5, "one of the six places is now filled")
    }

    func testTheCourtClosesOnceServingAndStaysClosedThroughARotation() {
        launchWithSix()

        // Six players, spot first each time.
        for _ in 0..<6 {
            guard let spot = emptySpots().first, let chip = playerChips().first else { break }
            spot.tap()
            chip.tap()
        }
        XCTAssertEqual(emptySpots().count, 0, "the order is full")

        // Hand the ball over and record a turn that ends.
        playerChips().first?.tap()
        XCTAssertTrue(app.buttons["serve-OUT"].waitForExistence(timeout: 3))
        app.buttons["serve-OUT"].tap()

        // The rotation hands the serve on. The court must NOT come back: it used to, and
        // the operator had to find Cancel before they could record the next rally.
        XCTAssertTrue(
            app.buttons["serve-OUT"].waitForExistence(timeout: 3),
            "the outcome controls must survive a rotation"
        )
        XCTAssertEqual(emptySpots().count, 0)
    }

    func testTappingWhoeverIsServingPutsTheCourtAway() {
        launchWithSix()

        for _ in 0..<6 {
            guard let spot = emptySpots().first, let chip = playerChips().first else { break }
            spot.tap()
            chip.tap()
        }
        playerChips().first?.tap()
        XCTAssertTrue(app.buttons["serve-OUT"].waitForExistence(timeout: 3))

        // Ask for the court, then change your mind by tapping whoever already has the ball.
        app.buttons["Change"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 3))

        let serving = playerChips().first
        serving?.tap()

        XCTAssertTrue(
            app.buttons["serve-OUT"].waitForExistence(timeout: 3),
            "tapping the current server means carry on, not stay here"
        )
    }
}
