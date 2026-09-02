// The two things an operator hit on a real phone that no test had ever tried: putting a
// keyboard away, and naming the game they were about to track.
//
// Both were found by the person holding the device, not by the suite, which is the whole
// reason they are written down here.
import XCTest

@MainActor
final class NamingUITests: XCTestCase {
    private let squad = [
        (number: "5", name: "Aria"), (number: "7", name: "Bea"), (number: "9", name: "Cass"),
        (number: "11", name: "Dee"), (number: "13", name: "Eve"), (number: "15", name: "Fay"),
    ]

    /// The opponent typed before the whistle is the opponent the game carries.
    func testAGameCanBeNamedBeforeItStarts() {
        let driver = AppDriver.launch(self)
        driver.addPlayers(squad)
        driver.go(to: "track")

        let field = driver.app.textFields["pre-game-opponent"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the game must be nameable before it starts")
        field.tap()
        field.typeText("Northside")
        driver.putTheKeyboardAway()

        driver.app.buttons["Start game"].tap()

        XCTAssertTrue(
            driver.app.buttons["name-game"].waitForExistence(timeout: 3),
            "a game in progress must show what it is called"
        )
        XCTAssertEqual(
            driver.app.buttons["name-game"].label, "Northside",
            "the name typed before the whistle must survive the whistle"
        )
    }

    /// And it can still be named afterwards, from the header, mid-game.
    func testAGameCanBeNamedOncePlayHasStarted() {
        let driver = AppDriver.launch(self)
        driver.addPlayers(squad)
        driver.startGame()

        let header = driver.app.buttons["name-game"]
        XCTAssertTrue(header.waitForExistence(timeout: 5), "an unnamed game must offer somewhere to name it")
        header.tap()

        let field = driver.app.textFields["game-opponent"]
        XCTAssertTrue(field.waitForExistence(timeout: 3), "the sheet must offer an opponent field")
        field.tap()
        field.typeText("Eastvale")
        driver.app.buttons["save-game-name"].tap()

        XCTAssertTrue(
            driver.app.buttons["Eastvale"].waitForExistence(timeout: 3),
            "the header must show the name that was just saved"
        )
    }

    /// A named game is findable in the season list, which is the point of naming it.
    func testANamedGameIsListedUnderItsName() {
        let driver = AppDriver.launch(self)
        driver.addPlayers(squad)
        driver.go(to: "track")

        let field = driver.app.textFields["pre-game-opponent"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "the game must be nameable before it starts")
        field.tap()
        field.typeText("Westbrook")
        driver.putTheKeyboardAway()
        driver.app.buttons["Start game"].tap()

        driver.go(to: "season")
        XCTAssertTrue(
            driver.app.staticTexts["Westbrook"].waitForExistence(timeout: 5),
            "the season list must name the game rather than call it unnamed"
        )
    }
}

@MainActor
final class KeyboardEscapeUITests: XCTestCase {
    /// Adding a player takes the keyboard with it.
    ///
    /// This is the trap itself: a number pad has no return key, and a keyboard left up after
    /// a successful Add covers the tab bar, so the screen cannot be left at all.
    func testAddingAPlayerPutsTheKeyboardAway() {
        let driver = AppDriver.launch(self)
        driver.go(to: "roster")

        let name = driver.app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "the roster must offer a name field")
        name.tap()
        name.typeText("Aria")

        let number = driver.app.textFields["Number"]
        number.tap()
        number.typeText("5")

        driver.app.buttons["add-player"].tap()

        XCTAssertTrue(
            driver.app.keyboards.element.waitForNonExistence(timeout: 3),
            "adding a player must give the screen back"
        )
    }

    /// And the way out is there while still typing, on the pad that has no return key.
    func testTheNumberPadOffersAWayOut() {
        let driver = AppDriver.launch(self)
        driver.go(to: "roster")

        let name = driver.app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "the roster must offer a name field")
        name.tap()
        name.typeText("Bea")

        let number = driver.app.textFields["Number"]
        number.tap()
        number.typeText("7")

        let done = driver.app.buttons["dismiss-keyboard"]
        XCTAssertTrue(done.waitForExistence(timeout: 3), "a number pad must still offer Done")
        done.tap()

        XCTAssertTrue(
            driver.app.keyboards.element.waitForNonExistence(timeout: 3),
            "Done must actually close the keyboard"
        )
        XCTAssertTrue(
            driver.app.tabBars.firstMatch.buttons.firstMatch.isHittable,
            "and the tab bar must be reachable again"
        )
    }
}
