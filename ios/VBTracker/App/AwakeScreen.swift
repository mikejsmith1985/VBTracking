// Whether the phone is allowed to go to sleep, and who is asking that it does not.
//
// Two different things want the screen kept on: the full-screen board propped beside the
// court, and a phone that is receiving somebody else's match. They overlap -- closing the
// board while still receiving must not put the phone to sleep -- so a single boolean owned
// by whichever screen ran last would be wrong in the ordinary case.
//
// So the reasons are counted. The screen sleeps again only when the last one lets go.
//
// This is the one place in the app that touches the idle timer. A phone left lit after
// somebody has put it away is a flat battery by the third set, and nothing on screen would
// say why -- so there is exactly one file to read to know when that can happen.
import UIKit

@MainActor
enum AwakeScreen {
    /// Why the screen is being held on. Named rather than counted, so releasing twice is
    /// harmless and a reason cannot be given back by somebody who never asked for it.
    enum Reason: String {
        /// The full-screen board, on a phone propped up beside the court.
        case board
        /// Receiving a match from another phone. iOS suspends a backgrounded app and
        /// Multipeer Connectivity disconnects with it, so a receiver that sleeps is a
        /// receiver that stops receiving.
        case receiving
    }

    private static var reasons: Set<Reason> = []

    /// Asks that the phone stay awake, for one named reason.
    static func hold(_ reason: Reason) {
        reasons.insert(reason)
        apply()
    }

    /// Gives up one reason. The screen sleeps again when none are left.
    static func release(_ reason: Reason) {
        reasons.remove(reason)
        apply()
    }

    private static func apply() {
        UIApplication.shared.isIdleTimerDisabled = !reasons.isEmpty
    }
}
