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
    /// way -- being in the hierarchy is not the same as being reachable -- so the tap went
    /// to the tab's frame, landed on the keyboard, and nothing moved.
    ///
    /// It found a real one: a number pad has no return key, and until the Done button was
    /// added an operator on the roster screen could not leave the page either.
    func putTheKeyboardAway() {
        guard app.keyboards.element.exists else { return }

        let done = app.buttons["dismiss-keyboard"]
        XCTAssertTrue(done.waitForExistence(timeout: 3), "every keyboard must offer a way out")
        done.tap()

        XCTAssertTrue(
            app.keyboards.element.waitForNonExistence(timeout: 3),
            "the keyboard must go away, or it covers the tab bar and the page cannot be left"
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
            // has none. Done is the app's own way out of a keyboard, so using it here means
            // every run exercises the thing an operator has to reach for.
            putTheKeyboardAway()

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

    /// Only the players who are not standing on the court yet.
    ///
    /// A chip carries the same identifier wherever it is drawn, so "the first player" meant
    /// whoever came first in the hierarchy -- and after one placement that is somebody
    /// already on the court. Placing them again only moved them, which emptied one box to
    /// fill another, and six rounds of that left five boxes still empty.
    func benchChips() -> [XCUIElement] {
        playerChips().filter { $0.label.hasSuffix("on the bench") }
    }

    func emptySpots() -> [XCUIElement] {
        app.buttons.allElementsBoundByIndex.filter { $0.identifier == "empty-spot" }
    }

    /// The box that is holding a place open, waiting to be told who stands in it.
    ///
    /// Asked for by the label the app announces, not by the "WHO?" written inside it: the
    /// button carries an `.accessibilityLabel`, which makes it a leaf and hides its own text
    /// from anything reading the screen.
    func heldSpot() -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", "Empty spot, selected")).firstMatch
    }

    /// Records serves won on serve, proving each one before tapping the next.
    ///
    /// Tapped in a tight loop they outran the screen and some were simply lost, so five taps
    /// recorded four serves and the alert that fires on the fifth never came. The proof is
    /// the tally's own count.
    func recordPointsWon(_ count: Int) {
        for serve in 1...count {
            app.buttons["serve-IN_POINT"].tap()

            let landed = app.staticTexts["\(serve) · \(serve) in"]
            let interrupted = app.otherElements["serve-limit-alert"]
            XCTAssertTrue(
                landed.waitForExistence(timeout: 3) || interrupted.exists,
                "serve \(serve) must be recorded before the next is tapped"
            )
        }
    }

    /// The five-serve interrupt, or a failure that says what was on screen instead.
    ///
    /// A container in SwiftUI is not an accessibility element on its own, so the overlay's
    /// identifier had nothing to attach to and could not be addressed at all. When that
    /// happens again the dump is what tells the difference between "the alert did not
    /// appear" and "the alert appeared and cannot be named".
    @discardableResult
    func waitForServeLimitAlert() -> XCUIElement {
        let alert = app.otherElements["serve-limit-alert"]
        if alert.waitForExistence(timeout: 4) { return alert }

        let texts = app.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
        XCTFail(
            """
            The five-serve alert never arrived.
            Text on screen: \(texts.prefix(20).joined(separator: " | "))
            """
        )
        return alert
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
        for placed in 1...6 {
            guard let spot = emptySpots().first, let chip = benchChips().first else {
                return XCTFail("place \(placed): needs an empty box and somebody on the bench")
            }

            // The chip is asked for again by name after the box is tapped. An element bound
            // by index resolves to whatever sits at that index when it is used, and tapping
            // a box changes the hierarchy underneath it.
            let chipId = chip.identifier
            spot.tap()
            app.buttons[chipId].tap()

            XCTAssertEqual(emptySpots().count, 6 - placed, "place \(placed) must fill exactly one box")
        }
    }
}
