// What the coach has chosen about their own wrist.
//
// The rotate alert interrupts. That is right when it is wanted and intolerable when it is
// not — a coach who already watches the rotation themselves does not need their wrist
// telling them, and an app that insists is one that gets taken off. But "off" is not the
// only answer short of insisting: most of the time a ding and a glance is the whole job,
// and only sometimes is it worth being nagged until you act.
//
// So there are three answers, not two. Which one does what is decided here, where it can be
// tested; only the storing of it happens on the watch.
import Foundation

/// How hard the wrist should press about the five-serve rule.
public enum RotateAlertStyle: String, CaseIterable, Codable, Sendable {
    /// Nothing at all. The coach is watching the rotation themselves.
    case off

    /// A ding, a buzz, and the message on screen long enough to read — then it goes on its
    /// own. Enough to look down, not enough to have to deal with.
    case brief

    /// Buzzes on a beat until it is cleared. For when the rule is being enforced and a
    /// missed rotation costs the point.
    case persistent

    /// How long the message stays before it clears itself, or nil when it waits to be
    /// cleared.
    ///
    /// Five seconds: long enough to look down mid-rally and read two numbers, short enough
    /// that it is gone before the next serve.
    public var clearsAfter: TimeInterval? {
        self == .brief ? 5 : nil
    }

    /// Whether it keeps buzzing rather than buzzing once.
    public var isRepeating: Bool { self == .persistent }

    /// Whether it appears at all.
    public var isOn: Bool { self != .off }

    /// The name on the settings page.
    public var label: String {
        switch self {
        case .off: "Off"
        case .brief: "Brief"
        case .persistent: "Persistent"
        }
    }

    /// What choosing it means, in the words of what will happen in a gym.
    public var detail: String {
        switch self {
        case .off: "The wrist never mentions the rule."
        case .brief: "One buzz, then the message clears itself after 5 seconds."
        case .persistent: "Buzzes until you clear it."
        }
    }
}

/// The coach's settings for the wrist.
public struct WatchPreferences: Equatable, Codable, Sendable {
    /// How the five-serve rule is announced.
    ///
    /// Defaults to persistent: a coach who has never opened the settings page has not
    /// decided anything, and the safe reading of that is that the alert they asked for
    /// still behaves the way it did when they asked.
    public var rotateAlert: RotateAlertStyle

    public init(rotateAlert: RotateAlertStyle = .persistent) {
        self.rotateAlert = rotateAlert
    }

    /// Reads a choice back out of storage.
    ///
    /// Anything unrecognised is the default, never "off" — a key that has never been written,
    /// or one holding a style written by some later version, must not silence an alert
    /// nobody chose to silence.
    public init(storedRotateAlert: Any?) {
        let stored = (storedRotateAlert as? String).flatMap(RotateAlertStyle.init(rawValue:))
        self.init(rotateAlert: stored ?? .persistent)
    }

    /// The key this is stored under. One place, so a rename cannot half-happen.
    public enum Key {
        public static let rotateAlert = "rotateAlertStyle"
    }

    /// Whether this notice should be put in front of the coach.
    public func shouldShow(_ notice: ServeLimitNotice?) -> Bool {
        notice != nil && rotateAlert.isOn
    }

    /// What the settings page says under the choices, so the coach knows what they have
    /// turned off before they find out in a gym.
    public var summary: String { rotateAlert.detail }
}
