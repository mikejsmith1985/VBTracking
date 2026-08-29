// The requirement that cannot be judged by eye here.
//
// "The on-deck box is the biggest thing on the screen" is a visual claim, and there is no
// Mac on the machine this was written on — no simulator to open, no screenshot to look at.
// So it is measured instead: the frames are read off the running app and compared.
//
// This is the only honest way to hold FR-005 and SC-014 when the author cannot see the
// screen.
import XCTest

// XCUITest drives a running app, so every one of its APIs is main-actor isolated. A test
// class that is not says so in 123 compiler errors.
@MainActor
final class CourtLayoutUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // A fixture court, so the layout can be measured without a paired phone.
        app.launchArguments = ["-uiTestCourt", "full"]
        app.launch()
    }

    func testOnDeckBoxIsTheLargestOnScreen() {
        let onDeck = app.otherElements["court-box-on-deck"]
        XCTAssertTrue(onDeck.waitForExistence(timeout: 5), "the on-deck box must be identifiable")

        let others = boxes().filter { $0.identifier != "court-box-on-deck" }
        XCTAssertEqual(others.count, 5, "six boxes, one of them on deck")

        for box in others {
            XCTAssertGreaterThan(
                area(of: onDeck), area(of: box),
                "the on-deck box must be bigger than \(box.identifier)"
            )
        }
    }

    func testOnDeckBoxClearsTheStatedMargin() {
        let onDeck = app.otherElements["court-box-on-deck"]
        XCTAssertTrue(onDeck.waitForExistence(timeout: 5))

        let smallest = boxes().map(area(of:)).min() ?? 0
        // SC-014: at least one and a half times the smallest box. `CourtLayout` holds this
        // at every supported size; this checks the app the layout was actually built into.
        XCTAssertGreaterThanOrEqual(area(of: onDeck), smallest * 1.5)
    }

    func testEveryPositionIsDrawn() {
        XCTAssertTrue(app.otherElements["court-box-serving"].waitForExistence(timeout: 5))
        XCTAssertEqual(boxes().count, 6, "six positions, always")
    }

    func testTheCourtSaysWhatItsFiguresCover() {
        let header = app.otherElements["court-header"]
        XCTAssertTrue(header.waitForExistence(timeout: 5), "the scope must be stated")
    }

    // MARK: - Reading the screen

    private func boxes() -> [XCUIElement] {
        app.otherElements.allElementsBoundByIndex.filter {
            $0.identifier.hasPrefix("court-box")
        }
    }

    private func area(of element: XCUIElement) -> Double {
        Double(element.frame.width * element.frame.height)
    }
}

/// What the wrist says when there is nothing to say.
@MainActor
final class CourtContentUITests: XCTestCase {
    func testAPlayerWhoHasNotServedShowsADashRatherThanZero() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestCourt", "unserved"]
        app.launch()

        // A dash, never "0%": the player has no percentage, and reporting nought would say
        // they served and missed.
        XCTAssertTrue(app.staticTexts["—"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["0%"].exists)
    }

    func testWithoutAnOrderNobodyIsNamedAsNext() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestCourt", "no-order"]
        app.launch()

        XCTAssertTrue(app.otherElements["court-box-serving"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["court-box-on-deck"].exists, "nothing may be marked next")
    }

    func testAnEmptyPositionIsShownAsEmpty() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestCourt", "five"]
        app.launch()

        XCTAssertTrue(app.otherElements["court-box-serving"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["–"].exists, "a position nobody stands in is still drawn")
    }
}
