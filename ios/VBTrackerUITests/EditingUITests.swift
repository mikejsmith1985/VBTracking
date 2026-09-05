// Correcting a game after it was played.
//
// Every one of these was reported by the person holding the phone, not found by the suite:
// a paper sheet that could be read and not corrected, a serve record nobody could find, and
// edits that were typed and then silently thrown away.
import XCTest

@MainActor
final class EditingUITests: XCTestCase {
    private let squad = [
        (number: "5", name: "Aria"), (number: "7", name: "Bea"), (number: "9", name: "Cass"),
        (number: "11", name: "Dee"), (number: "13", name: "Eve"), (number: "15", name: "Fay"),
    ]

    /// A finished game, reached from the Season tab the way an operator reaches one.
    private func playAGame(_ driver: AppDriver) {
        driver.addPlayers(squad)
        driver.go(to: "track")
        driver.app.buttons["Start game"].tap()
        driver.buildFullRotation()
        driver.chooseFirstServer()
        driver.app.buttons["serve-OUT"].tap()
    }

    func testAGameOpenedFromTheSeasonCanBeRenamed() {
        let driver = AppDriver.launch(self)
        playAGame(driver)
        driver.go(to: "season")

        // The game's own row, whatever it is called at this point.
        let row = driver.app.buttons.containing(NSPredicate(format: "label CONTAINS 'in'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the season must list the game just played")
        row.tap()

        let opponent = driver.app.textFields["Opposing team"]
        XCTAssertTrue(opponent.waitForExistence(timeout: 5), "a game must be editable after the fact")
        opponent.tap()
        opponent.typeText("Westbrook")
        driver.putTheKeyboardAway()
        driver.photograph("12-editing-a-game")
    }

    func testTheServeRecordSaysWhatItOpens() {
        let driver = AppDriver.launch(self)
        playAGame(driver)
        driver.go(to: "season")

        let row = driver.app.buttons.containing(NSPredicate(format: "label CONTAINS 'in'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let record = driver.app.buttons["open-record"]
        XCTAssertTrue(record.waitForExistence(timeout: 5), "the tracking history must be reachable")
        record.tap()

        XCTAssertTrue(
            driver.app.navigationBars["Serve record"].waitForExistence(timeout: 5),
            "the serve record must actually open"
        )
        driver.photograph("13-serve-record")
    }

    func testTheGameTabOffersAWayToEditWhatItShows() {
        let driver = AppDriver.launch(self)
        playAGame(driver)
        driver.go(to: "game")

        let edit = driver.app.buttons["edit-game"]
        XCTAssertTrue(
            edit.waitForExistence(timeout: 5),
            "the tab that shows a game's figures must offer a way to correct them"
        )
        edit.tap()

        XCTAssertTrue(
            driver.app.textFields["Opposing team"].waitForExistence(timeout: 5),
            "editing from the Game tab must reach the same form"
        )
        driver.photograph("14-editing-from-the-game-tab")
    }
}

/// Correcting a serve turn, which is where a mis-tap costs recorded data.
@MainActor
final class TurnCorrectionUITests: XCTestCase {
    private let squad = [
        (number: "5", name: "Aria"), (number: "7", name: "Bea"), (number: "9", name: "Cass"),
        (number: "11", name: "Dee"), (number: "13", name: "Eve"), (number: "15", name: "Fay"),
    ]

    /// A game with one finished turn in it, sitting open in the serve record.
    private func openTheFirstTurn(_ driver: AppDriver) {
        driver.addPlayers(squad)
        driver.go(to: "track")
        driver.app.buttons["Start game"].tap()
        driver.buildFullRotation()
        driver.chooseFirstServer()
        driver.app.buttons["serve-IN-POINT"].tap()
        driver.app.buttons["serve-IN-POINT"].tap()
        driver.app.buttons["serve-OUT"].tap()

        driver.go(to: "season")
        let row = driver.app.buttons.containing(NSPredicate(format: "label CONTAINS 'in'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let record = driver.app.buttons["open-record"]
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()

        let turn = driver.app.buttons["turn-0-0"]
        XCTAssertTrue(turn.waitForExistence(timeout: 5), "the first turn must be listed")
        turn.tap()
    }

    func testRemovingAServeLeavesTheEditorOpen() {
        let driver = AppDriver.launch(self)
        openTheFirstTurn(driver)

        let drop = driver.app.buttons["drop-serve"]
        XCTAssertTrue(drop.waitForExistence(timeout: 5))
        drop.tap()

        XCTAssertTrue(
            driver.app.buttons["drop-serve"].waitForExistence(timeout: 3),
            "removing a serve must not close the editor: the next correction is usually on the same turn"
        )
        driver.photograph("15-turn-after-dropping-a-serve")
    }

    func testCorrectingAServeNeverDeletesTheTurn() {
        let driver = AppDriver.launch(self)
        openTheFirstTurn(driver)

        // Arm the delete, then think better of it and correct a serve instead. The turn must
        // survive: a delete armed by one tap must never be fired by a different button.
        driver.app.buttons["delete-turn"].tap()
        driver.app.buttons["cycle-serve-0"].tap()

        XCTAssertTrue(
            driver.app.buttons["turn-0-0"].waitForExistence(timeout: 5)
                || driver.app.buttons["drop-serve"].exists,
            "the turn must still exist after a correction, armed delete or not"
        )
        driver.photograph("16-turn-survives-an-armed-delete")
    }
}
