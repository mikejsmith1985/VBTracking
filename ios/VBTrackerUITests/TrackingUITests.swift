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
    private let squad = [(number: "5", name: "Aria"), (number: "7", name: "Ella")]

    func testAServeIsRecordedInOneTap() {
        let driver = AppDriver.launch(self)
        driver.addPlayers(squad)
        driver.startGame()
        driver.chooseFirstServer()

        driver.app.buttons["serve-IN_POINT"].tap()

        driver.app.buttons["Game"].tap()
        XCTAssertTrue(driver.app.staticTexts["1/1"].waitForExistence(timeout: 3), "one serve, one landed in")
    }

    func testOneUndoReversesExactlyOneAction() {
        let driver = AppDriver.launch(self)
        driver.addPlayers(squad)
        driver.startGame()
        driver.chooseFirstServer()

        driver.app.buttons["serve-IN_POINT"].tap()
        driver.app.buttons["serve-IN_POINT"].tap()
        driver.app.buttons["undo"].tap()

        driver.app.buttons["Game"].tap()
        XCTAssertTrue(driver.app.staticTexts["1/1"].waitForExistence(timeout: 3), "one serve reversed, not two")
    }

    func testTheFiveServeAlertInterrupts() {
        let driver = AppDriver.launch(self)
        driver.addPlayers(squad)
        driver.startGame()
        driver.chooseFirstServer()

        for _ in 0..<5 { driver.app.buttons["serve-IN_POINT"].tap() }

        let alert = driver.app.otherElements["serve-limit-alert"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3), "five serves must interrupt")

        alert.tap()
        XCTAssertFalse(alert.exists, "any tap clears it")
    }

    func testASixthServeIsRecordedWithoutNaggingAgain() {
        let driver = AppDriver.launch(self)
        driver.addPlayers(squad)
        driver.startGame()
        driver.chooseFirstServer()

        for _ in 0..<5 { driver.app.buttons["serve-IN_POINT"].tap() }
        driver.app.otherElements["serve-limit-alert"].tap()
        driver.app.buttons["serve-IN_POINT"].tap()

        XCTAssertFalse(
            driver.app.otherElements["serve-limit-alert"].exists,
            "a miscount is recorded, not nagged about"
        )
    }

    func testTheDockNeverShowsBothOutcomesAndThePicker() {
        let driver = AppDriver.launch(self)
        driver.addPlayers(squad)
        driver.startGame()

        // Before a server is chosen: the picker, and no outcome controls.
        XCTAssertFalse(driver.app.buttons["serve-OUT"].exists)

        driver.chooseFirstServer()

        // After: the outcome controls, and no picker.
        XCTAssertTrue(driver.app.buttons["serve-OUT"].waitForExistence(timeout: 3))
        XCTAssertEqual(driver.playerChips().count, 0, "a control that is present but wrong is a mis-tap")
    }
}

/// Saving a copy of everything, and where it can be reached from.
@MainActor
final class TransferUITests: XCTestCase {
    func testTheExportIsReachableWithNoGameInProgress() {
        let driver = AppDriver.launch(self)

        // It used to live on the game screen, which shows nothing until a game exists -- so
        // an operator between games had no way to save their season.
        driver.app.buttons["Season"].tap()
        XCTAssertTrue(driver.app.buttons["export-data"].waitForExistence(timeout: 3))
        XCTAssertTrue(driver.app.buttons["import-data"].exists)
    }
}

/// Building a rotation on the court, and using it.
///
/// Three bugs shipped here at once, and every one of them was invisible to the domain suite
/// because every one was about what a tap does to a screen.
@MainActor
final class RotationUITests: XCTestCase {
    private let squad = (1...7).map { (number: "\($0)", name: "Player \($0)") }

    func testAnEmptySpotIsTappableAnywhereInsideIt() {
        let driver = AppDriver.launch(self)
        driver.addPlayers(squad)
        driver.startGame()

        guard let spot = driver.emptySpots().first else {
            return XCTFail("six empty places must be offered")
        }

        // The middle of the box, which is where anybody aims. The box used to be drawn with
        // a stroked border and no fill, so only the 1pt outline was hittable and taps in the
        // middle did nothing at all.
        spot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue(
            driver.app.staticTexts["WHO?"].waitForExistence(timeout: 3),
            "one tap in the middle of a spot must pick it up"
        )
    }

    func testAPlayerCanBePickedUpBeforeASpotIsChosen() {
        let driver = AppDriver.launch(self)
        driver.addPlayers(squad)
        driver.startGame()

        driver.playerChips().first?.tap()

        // It used to start recording that player's serves, which made building a rotation
        // player-first impossible.
        XCTAssertFalse(driver.app.buttons["serve-OUT"].exists, "a first tap must not start a turn")
        XCTAssertTrue(driver.emptySpots().count > 0, "the court is still there to place them on")

        driver.emptySpots().first?.tap()
        XCTAssertEqual(driver.emptySpots().count, 5, "one of the six places is now filled")
    }

    func testTheCourtClosesOnceServingAndStaysClosedThroughARotation() {
        let driver = AppDriver.launch(self)
        driver.addPlayers(squad)
        driver.startGame()
        driver.buildFullRotation()

        // With six standing, one tap on a player hands them the ball.
        driver.playerChips().first?.tap()
        XCTAssertTrue(driver.app.buttons["serve-OUT"].waitForExistence(timeout: 3))

        driver.app.buttons["serve-OUT"].tap()

        // The rotation hands the serve on. The court must NOT come back: it used to, and the
        // operator had to find Cancel before they could record the next rally.
        XCTAssertTrue(
            driver.app.buttons["serve-OUT"].waitForExistence(timeout: 3),
            "the outcome controls must survive a rotation"
        )
        XCTAssertEqual(driver.emptySpots().count, 0)
    }

    func testTappingWhoeverIsServingPutsTheCourtAway() {
        let driver = AppDriver.launch(self)
        driver.addPlayers(squad)
        driver.startGame()
        driver.buildFullRotation()

        driver.playerChips().first?.tap()
        XCTAssertTrue(driver.app.buttons["serve-OUT"].waitForExistence(timeout: 3))

        // Ask for the court, then change your mind by tapping whoever already has the ball.
        driver.app.buttons["Change"].tap()
        XCTAssertTrue(driver.app.buttons["Cancel"].waitForExistence(timeout: 3))

        driver.playerChips().first?.tap()

        XCTAssertTrue(
            driver.app.buttons["serve-OUT"].waitForExistence(timeout: 3),
            "tapping the current server means carry on, not stay here"
        )
    }
}
