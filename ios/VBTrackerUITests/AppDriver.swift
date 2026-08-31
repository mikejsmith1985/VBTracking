// Driving the app the way an operator does, in the words the tests want to use.
//
// Every one of these used to be duplicated in each suite, and each copy did a little less
// checking than the last. When adding a player quietly failed, the failure surfaced several
// lines later as "Start game does not exist" -- true, because the Track screen offers no
// game to a team with nobody in it, and useless, because it says nothing about the roster
// screen where the fault was.
//
// So each step proves it happened.
import XCTest

@MainActor
struct AppDriver {
    let app: XCUIApplication
    let test: XCTestCase

    /// A clean container each run: a test that inherits the last one's season proves nothing.
    @discardableResult
    static func launch(_ test: XCTestCase) -> AppDriver {
        test.continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestFreshStore"]
        app.launch()
        return AppDriver(app: app, test: test)
    }

    /// Adds players, and proves each one landed.
    func addPlayers(_ players: [(number: String, name: String)]) {
        app.buttons["Roster"].tap()

        for player in players {
            let nameField = app.textFields["Name"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 5), "the roster must offer a name field")
            nameField.tap()
            nameField.typeText(player.name)

            let numberField = app.textFields["Number"]
            numberField.tap()
            numberField.typeText(player.number)

            // The keyboard covers the bottom of the screen, and Add is underneath it.
            if app.keyboards.count > 0 {
                app.keyboards.buttons["return"].firstMatch.tap()
            }

            let add = app.buttons["Add"]
            XCTAssertTrue(add.waitForExistence(timeout: 3), "the Add button must be reachable")
            add.tap()

            XCTAssertTrue(
                app.staticTexts[player.name].waitForExistence(timeout: 3),
                "\(player.name) was not added to the roster"
            )
        }
    }

    /// Starts a game, having checked there is one to start.
    func startGame() {
        app.buttons["Track"].tap()
        let start = app.buttons["Start game"]
        XCTAssertTrue(
            start.waitForExistence(timeout: 5),
            "no game to start — the Track screen offers one only once the roster has players"
        )
        start.tap()
    }

    func playerChips() -> [XCUIElement] {
        app.buttons.allElementsBoundByIndex.filter { $0.identifier.hasPrefix("player-") }
    }

    func emptySpots() -> [XCUIElement] {
        app.buttons.allElementsBoundByIndex.filter { $0.identifier == "empty-spot" }
    }

    /// Hands the ball to the first player offered.
    ///
    /// Two taps, not one. While an order is still being built a tap picks a player up so
    /// they can be placed on the court; tapping them again is what says "no, they serve".
    func chooseFirstServer() {
        guard let chip = playerChips().first else {
            return XCTFail("the picker must offer somebody to serve")
        }
        chip.tap()
        chip.tap()
        XCTAssertTrue(
            app.buttons["serve-OUT"].waitForExistence(timeout: 3),
            "two taps on a player must start their turn"
        )
    }

    /// Fills all six places, spot first each time.
    func buildFullRotation() {
        for _ in 0..<6 {
            guard let spot = emptySpots().first, let chip = playerChips().first else { break }
            spot.tap()
            chip.tap()
        }
        XCTAssertEqual(emptySpots().count, 0, "six places, six players")
    }
}
