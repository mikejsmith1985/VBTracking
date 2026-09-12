// A court to measure, on a watch with no phone beside it.
//
// The layout requirements are visual ones -- the on-deck box is the biggest thing on the
// screen, an unserved player shows a dash rather than nought -- and there is no Mac here to
// look at a simulator. They are held instead by an interface test that reads the frames off
// the running app. That test needs a court on screen, and a court normally arrives from a
// paired phone, which a simulator in a build farm does not have.
//
// So the app can be launched with one. This is the same shape as the phone's own
// `-uiTestFreshStore`: a launch argument nobody can reach by using the app, read once at
// start-up, and inert on every real device.
import Foundation
import VBPresentation

enum CourtFixture {
    /// The court named on the command line, or nil when none was.
    ///
    /// Nil is the normal case: a watch on a wrist is handed its court by the phone, and
    /// nothing here changes that.
    static var requested: CourtSnapshot? {
        // Two channels, because only one of them is certain to arrive. A watchOS app under
        // XCUITest is launched by a runner rather than directly, and launch arguments have
        // not always survived that hop; the environment does. Reading both costs nothing
        // and removes a whole class of "the fixture was never there" from the diagnosis.
        if let name = ProcessInfo.processInfo.environment["UI_TEST_COURT"], let court = named(name) {
            return court
        }

        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-uiTestCourt"),
            arguments.index(after: flag) < arguments.endIndex
        else { return nil }

        return named(arguments[arguments.index(after: flag)])
    }

    /// The fixtures the interface suite asks for, by the names it uses.
    private static func named(_ name: String) -> CourtSnapshot? {
        switch name {
        case "full": return full
        case "unserved": return unserved
        case "no-order": return withoutAnOrder
        case "five": return oneShort
        default: return nil
        }
    }

    /// Six players, one serving, one on deck: the ordinary court, and the one the sizes are
    /// measured against.
    private static var full: CourtSnapshot {
        court(slots: [
            slot(1, "4", 0.82, 6),
            slot(2, "7", 0.91, 9),
            slot(3, "11", 0.64, 3),
            slot(4, "13", 0.77, 5, isOnDeck: true),
            slot(5, "15", 0.58, 2),
            slot(6, "21", 0.75, 4, isServing: true),
        ])
    }

    /// Nobody has served yet, so every figure is unknown -- and unknown is a dash, never a
    /// nought, because nought would say they served and missed.
    private static var unserved: CourtSnapshot {
        court(slots: [
            slot(1, "4", nil, nil),
            slot(2, "7", nil, nil),
            slot(3, "11", nil, nil),
            slot(4, "13", nil, nil, isOnDeck: true),
            slot(5, "15", nil, nil),
            slot(6, "21", nil, nil, isServing: true),
        ])
    }

    /// A court with no serving order, where the wrist must not name anybody as next.
    private static var withoutAnOrder: CourtSnapshot {
        court(
            hasOrder: false,
            slots: [
                slot(1, "4", 0.82, 6),
                slot(2, "7", 0.91, 9),
                slot(3, "11", 0.64, 3),
                slot(4, "13", 0.77, 5),
                slot(5, "15", 0.58, 2),
                slot(6, "21", 0.75, 4, isServing: true),
            ]
        )
    }

    /// Five on court and one position empty, which is still drawn rather than left out.
    private static var oneShort: CourtSnapshot {
        court(slots: [
            slot(1, "4", 0.82, 6),
            slot(2, "7", 0.91, 9),
            slot(3, nil, nil, nil),
            slot(4, "13", 0.77, 5, isOnDeck: true),
            slot(5, "15", 0.58, 2),
            slot(6, "21", 0.75, 4, isServing: true),
        ])
    }

    private static func court(hasOrder: Bool = true, slots: [SnapshotSlot]) -> CourtSnapshot {
        CourtSnapshot(
            sequence: 1,
            // Fixed rather than `Date()`, so the same launch draws the same screen and a
            // still can be compared with the one before it.
            capturedAt: Date(timeIntervalSince1970: 1_788_000_000),
            scopeLabel: "Match 2",
            hasOrder: hasOrder,
            slots: slots,
            serveLimit: nil,
            acknowledgedEventIds: []
        )
    }

    private static func slot(
        _ court: Int,
        _ number: String?,
        _ inPercentage: Double?,
        _ points: Int?,
        isServing: Bool = false,
        isOnDeck: Bool = false
    ) -> SnapshotSlot {
        SnapshotSlot(
            court: court,
            number: number,
            inPercentage: inPercentage,
            points: points,
            isServing: isServing,
            isOnDeck: isOnDeck
        )
    }
}
