// What the coach has chosen about their own wrist.
//
// The rotate alert interrupts, and buzzes on a beat until it is cleared. That is right when
// it is wanted and intolerable when it is not — a coach who already watches the rotation
// themselves does not need their wrist telling them, and an app that insists is one that
// gets taken off.
//
// So it is a choice. The choice is decided here, where it can be tested, and only the
// storing of it happens on the watch.
import Foundation

/// The coach's settings for the wrist.
///
/// Both default to on: a coach who has not been to the settings page has not decided
/// anything, and the safe reading of that is that the rule they asked for still applies.
public struct WatchPreferences: Equatable, Codable, Sendable {
    /// Whether the five-serve alert appears at all.
    public var isRotateAlertOn: Bool

    /// Whether the alert buzzes as well as showing.
    ///
    /// Separate from the alert itself, because the two objections are different ones. A
    /// coach who finds the buzzing too much still wants to see the reminder; a coach who
    /// tracks the rotation themselves wants neither.
    public var isRotateBuzzOn: Bool

    public init(isRotateAlertOn: Bool = true, isRotateBuzzOn: Bool = true) {
        self.isRotateAlertOn = isRotateAlertOn
        self.isRotateBuzzOn = isRotateBuzzOn
    }

    /// Reads a choice back out of storage.
    ///
    /// Absence is the default, never "off". A key that has never been written reads as
    /// `false` through most storage, which would silence an alert nobody asked to silence —
    /// so what is read is the presence of a choice, not the value of a missing one.
    public init(storedRotateAlert: Any?, storedRotateBuzz: Any?) {
        self.init(
            isRotateAlertOn: storedRotateAlert as? Bool ?? true,
            isRotateBuzzOn: storedRotateBuzz as? Bool ?? true
        )
    }

    /// The keys these are stored under. One place, so a rename cannot half-happen.
    public enum Key {
        public static let rotateAlert = "rotateAlertOn"
        public static let rotateBuzz = "rotateBuzzOn"
    }

    /// Whether this notice should be put in front of the coach.
    public func shouldShow(_ notice: ServeLimitNotice?) -> Bool {
        notice != nil && isRotateAlertOn
    }

    /// Whether the alert, once shown, should buzz.
    ///
    /// Silencing the alert silences the buzz with it: there is no state where an invisible
    /// alert vibrates, because a buzz with nothing on screen to explain it is worse than
    /// either setting on its own.
    public var shouldBuzz: Bool {
        isRotateAlertOn && isRotateBuzzOn
    }

    /// What the settings page says under the two switches, so the coach knows what they
    /// have turned off before they find out in a gym.
    public var summary: String {
        switch (isRotateAlertOn, isRotateBuzzOn) {
        case (false, _): "The wrist will not mention the five-serve rule."
        case (true, false): "The alert appears, silently."
        case (true, true): "The alert appears and buzzes until you clear it."
        }
    }
}

/// Somewhere to keep the choice between sessions.
///
/// A protocol rather than a direct call to storage, for the same reason the link is one:
/// what is decided from a setting is tested here, and the storing of it happens on a device
/// this workstation cannot run.
public protocol PreferenceStore: AnyObject {
    var preferences: WatchPreferences { get set }
}
