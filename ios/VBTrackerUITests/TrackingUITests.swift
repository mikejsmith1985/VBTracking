// A match, driven through the real app by real taps.
//
// The domain suite proves the rules; this proves the rules are wired to the things the
// operator actually touches. It runs on the build machine, because it is the only place a
// screen exists.
import XCTest

// XCUITest drives a running app, so every one of its APIs is main-actor isolated. A test
// class that is not says so in 123 compiler errors.
@MainActor
final class TrackingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // A clean container each run: a test that inherits last run's season proves nothing.
        app.launchArguments = ["-uiTestFreshStore"]
        app.launch()
    }

    func testAServeIsRecordedInOneTap() {
        addPlayers(["7": "Ella", "5": "Aria"])
        app.buttons["Track"].tap()
        app.buttons["Start game"].tap()

        firstPlayerChip().tap()
        app.buttons["serve-IN_POINT"].tap()

        app.buttons["Game"].tap()
        XCTAssertTrue(app.staticTexts["1/1"].waitForExistence(timeout: 3), "one serve, one landed in")
    }

    func testOneUndoReversesExactlyOneAction() {
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
