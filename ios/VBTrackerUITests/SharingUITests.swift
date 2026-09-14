// Sharing a match is a button somebody can find and press.
//
// Two failures worth a test each, both of which shipped. The control was drawn in secondary
// grey at caption size directly under another caption, so it read as a label and the one
// person who knew it existed could not find it. And the sheet behind it never opened, because
// three `sheet(isPresented:)` were stacked on one view.
//
// Neither is a compile error, and neither shows up in a unit test. They show up here.
import XCTest

final class SharingUITests: XCTestCase {
    private let squad = [
        (number: "5", name: "Aria"), (number: "7", name: "Bea"), (number: "9", name: "Cass"),
        (number: "11", name: "Dee"), (number: "13", name: "Eve"), (number: "15", name: "Fay"),
    ]

    func testSharingAMatchIsOfferedOnTheMatchScreen() {
        let driver = AppDriver.launch(self)
        driver.addPlayers(squad)
        driver.startGame()

        // On the match screen, where the match is -- not in a settings list a tab away.
        let share = driver.app.buttons["share-match"]
        XCTAssertTrue(share.waitForExistence(timeout: 5), "the match screen must offer to share the match")
        XCTAssertTrue(share.isHittable, "a control nobody can press is a control nobody has")
        driver.photograph("20-share-this-match")
    }

    func testSharingStartsAtOnceAndTheInvitationIsOneStepFurtherIn() {
        let driver = AppDriver.launch(self)
        driver.addPlayers(squad)
        driver.startGame()

        let share = driver.app.buttons["share-match"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        share.tap()

        // Sharing starts on that tap and nothing stands in front of it. The file is the
        // fallback for a phone that cannot see this one, so it lives one step further in.
        let invite = driver.app.buttons["invite-again"]
        XCTAssertTrue(invite.waitForExistence(timeout: 5), "sharing must start, and then offer to invite")
        invite.tap()

        // The sheet's own control, not the button that opened it. A sheet that never appears
        // would otherwise pass on the strength of the row still being on screen -- which is
        // exactly how the stacked-sheet bug got as far as a phone.
        let send = driver.app.buttons["share-invitation"]
        XCTAssertTrue(send.waitForExistence(timeout: 5), "the invitation sheet must open")
        driver.photograph("21-invitation-sheet")
    }

    func testNothingOffersToShareBeforeThereIsAMatch() {
        let driver = AppDriver.launch(self)

        // There is nothing to share until there is a match, which is the answer to whether
        // you set the match up first or share it first.
        let share = driver.app.buttons["share-match"]
        XCTAssertFalse(
            share.waitForExistence(timeout: 2),
            "sharing is offered for a match, so it cannot be offered before one exists"
        )
    }
}
