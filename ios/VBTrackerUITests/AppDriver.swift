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

    /// What the tab bar exposes for each tab.
    ///
    /// The symbol name, because that is what a SwiftUI tab bar puts in the accessibility
    /// tree -- the `Label`'s text is dropped and an `.accessibilityLabel` on it does not
    /// take. The title is tried first anyway, so the day that stops being true the suite
    /// needs no edit.
    private static let tabCandidates: [String: [String]] = [
        "track": ["Track", "record.circle"],
        "game": ["Game", "list.number"],
        "season": ["Season", "calendar"],
        "roster": ["Roster", "person.3"],
    ]

    /// Moves to a tab.
    ///
    /// The search is confined to the tab bar. Looking across the whole app found matches
    /// inside a tab's own content -- off-screen and unhittable -- and tapping one moved
    /// nothing.
    func go(to tab: String) {
        putTheKeyboardAway()

        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 5), "the app must show a tab bar")

        for candidate in Self.tabCandidates[tab] ?? [tab] {
            let item = bar.buttons[candidate]
            if item.exists {
                item.tap()
                return
            }
        }

        // Nothing matched, so say what the bar does hold rather than only that it does not
        // hold this.
        let inBar = bar.buttons.allElementsBoundByIndex
            .map { $0.identifier.isEmpty ? $0.label : $0.identifier }
            .filter { !$0.isEmpty }
        XCTFail("No \(tab) tab. The bar holds: \(inBar.joined(separator: " | "))")
    }

    /// Dismisses any keyboard before going anywhere.
    ///
    /// A keyboard sits on top of the tab bar. XCUITest reports the tab as existing either
    /// way -- it is in the hierarchy whether or not anything covers it -- so the tap went to
    /// its frame, landed on the keyboard, and nothing moved. Every test then sat on the
    /// roster screen insisting there was no game to start, which is true of the roster
    /// screen and says nothing about why it was still showing.
    private func putTheKeyboardAway() {
        guard app.keyboards.element.exists else { return }

        // The navigation bar is always there and takes focus away from a field.
        app.navigationBars.firstMatch.tap()
        if app.keyboards.element.waitForNonExistence(timeout: 3) { return }

        app.swipeDown()
        XCTAssertTrue(
            app.keyboards.element.waitForNonExistence(timeout: 3),
            "the keyboard must go away, or it covers the tab bar and no test can navigate"
        )
    }

    /// Adds players, and proves each one landed.
    ///
    /// The proof is the roster's own count, not the name appearing somewhere on screen. A
    /// text field exposes what has been typed into it as static text, so looking for the
    /// name found the half-filled form and reported success while nothing had been added --
    /// and the failure surfaced two screens later as "no game to start".
    func addPlayers(_ players: [(number: String, name: String)]) {
        go(to: "roster")

        for (index, player) in players.enumerated() {
            let nameField = app.textFields["Name"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 5), "the roster must offer a name field")
            nameField.tap()
            nameField.typeText(player.name)

            let numberField = app.textFields["Number"]
            numberField.tap()
            numberField.typeText(player.number)

            // No reaching for a "return" key: the number field brings up a numeric pad and
            // has none. The navigation bar is always there and always takes focus away, so
            // the keyboard goes with it and the Add button underneath comes back.
            app.navigationBars.firstMatch.tap()

            let add = app.buttons["Add"]
            XCTAssertTrue(add.waitForExistence(timeout: 3), "the Add button must exist")
            add.tap()

            // The roster says how many it holds. Nothing else on this screen can be
            // mistaken for a player who is not there.
            let count = "\(index + 1) of \(Self.maxRoster)"
            XCTAssertTrue(
                app.staticTexts[count].waitForExistence(timeout: 3),
                "the roster should read \(count) after adding \(player.name)"
            )
        }
    }

    /// The roster cap, as the roster screen prints it.
    private static let maxRoster = 20

    /// Starts a game, having checked there is one to start.
    ///
    /// When it cannot find the button it says what it CAN see. Three rounds of this failure
    /// were spent guessing at why a screen was not what it should be, and a list of what is
    /// actually on it ends that in one run.
    func startGame() {
        go(to: "track")

        let start = app.buttons["Start game"]
        if !start.waitForExistence(timeout: 5) {
            let buttons = app.buttons.allElementsBoundByIndex
                .map { "\($0.identifier.isEmpty ? $0.label : $0.identifier)" }
                .filter { !$0.isEmpty }
            let texts = app.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
            XCTFail(
                """
                No game to start.
                Buttons on screen: \(buttons.joined(separator: " | "))
                Text on screen: \(texts.prefix(15).joined(separator: " | "))
                """
            )
            return
        }
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
