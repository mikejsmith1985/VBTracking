// What a glance is allowed to show.
//
// A glance is read in a second, from a distance, by somebody about to decide whether to
// substitute. The one thing it must never do is show a figure that stopped being true --
// because a coach reading a frozen percentage has no way to know it froze, and will act on
// it exactly as confidently as on a live one.
//
// So a glance either vouches for what it shows or it shows nothing and says why. There is no
// third state where old figures sit on screen looking current. Dimming them is not enough: a
// percentage is read as a percentage however it is styled.
import Foundation
import VBCore

/// A court, prepared for a screen nobody is going to study.
public struct Glance: Equatable, Sendable {
    /// The boxes to draw. Empty whenever the figures cannot be vouched for.
    public let slots: [SnapshotSlot]

    /// Whether what is being shown is current enough to act on.
    public let isVouchedFor: Bool

    /// What to say instead of figures. Empty when there are figures to show.
    public let headline: String

    /// How long ago the court was captured, in words.
    public let age: String

    /// Which jersey number serves next, or nil where there is no order to say.
    public let onDeckNumber: String?

    /// Whether the boxes are being drawn at all.
    public var hasCourt: Bool { !slots.isEmpty }

    public init(court: CourtSnapshot?, now: Date = Date()) {
        guard let court else {
            self.slots = []
            self.isVouchedFor = false
            // Distinct from a court that went stale. One means the match has not reached this
            // phone; the other means it stopped. They need different things done about them.
            self.headline = "No match yet"
            self.age = ""
            self.onDeckNumber = nil
            return
        }

        // The wrist's own rule, not a second one. Two thresholds would drift, and the wrist
        // and the lock screen would then disagree in front of the same coach.
        let freshness = LinkFreshness(capturedAt: court.capturedAt, now: now)
        self.isVouchedFor = freshness.isCurrent
        self.age = text(secondsAgo: freshness.secondsOld)

        guard freshness.isCurrent else {
            self.slots = []
            self.headline = "Open the app to catch up"
            self.onDeckNumber = nil
            return
        }

        self.slots = court.slots
        self.headline = ""
        self.onDeckNumber = court.hasOrder ? court.slots.first(where: \.isOnDeck)?.number : nil
    }
}
