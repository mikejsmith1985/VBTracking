// Handing a season to another phone, as far as one phone can be driven.
//
// AirDrop itself cannot be exercised by a test: it needs two devices in the same room and a
// person to accept on the second one. What can be proved here is everything up to that
// point -- that the control exists, that it is reachable without a season, and that it
// opens the share sheet rather than doing nothing.
import XCTest

final class HandoverUITests: XCTestCase {
    private var driver: AppDriver!

    override func setUp() {
        continueAfterFailure = false
        driver = AppDriver(test: self)
        driver.launch()
    }

    func testTheHandoverControlIsReachableOnAFreshPhone() {
        driver.go(to: "season")

        let handOver = driver.app.buttons["hand-over"]
        XCTAssertTrue(
            handOver.waitForExistence(timeout: 5),
            "a coach must be able to hand a season over without first making one"
        )
        driver.photograph("10-season-data-controls")
    }

    func testHandingOverOpensTheShareSheet() {
        driver.go(to: "season")

        let handOver = driver.app.buttons["hand-over"]
        XCTAssertTrue(handOver.waitForExistence(timeout: 5))
        handOver.tap()

        // The sheet's own control, not the button that opened it: a sheet that never
        // appears would otherwise pass on the strength of the row still being on screen.
        let share = driver.app.buttons["share-season"]
        XCTAssertTrue(share.waitForExistence(timeout: 5), "the share sheet must open")
        driver.photograph("11-handover-sheet")
    }

    func testSavingACopyAndHandingOverAreDifferentControls() {
        driver.go(to: "season")

        XCTAssertTrue(driver.app.buttons["export-data"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            driver.app.buttons["hand-over"].exists,
            "a backup and a hand-over answer different questions and must not be one button"
        )
    }
}
