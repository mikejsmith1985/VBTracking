// Whether the watch app is actually on the wrist, and what to say when it is not.
//
// A watch app installs itself alongside the phone app, usually. When it does not -- and with
// a TestFlight build it often does not -- there is nothing on either screen to say so. The
// phone looks fine, the watch has no app on it, and the only clue is that the wrist never
// shows a court.
//
// iOS offers no way for an app to install its own watch app; that switch belongs to the Watch
// app on the iPhone and to nobody else. So what is offered here is the next best thing and
// the thing that was actually missing: saying plainly which of the four possible states the
// pair is in, and exactly what to do about it.
import Foundation

/// What the phone can find out about the watch beside it.
public struct WatchState: Equatable, Sendable {
    /// Whether this phone can talk to a watch at all. False on an iPad, and on a phone whose
    /// iOS has no Watch support.
    public let isSupported: Bool

    /// Whether a watch is paired to this phone.
    public let isPaired: Bool

    /// Whether this app's watch app is installed on it.
    public let isAppInstalled: Bool

    /// Whether the watch is awake and in range right now. Not a problem when false -- a wrist
    /// down at somebody's side is unreachable and perfectly well.
    public let isReachable: Bool

    public init(isSupported: Bool, isPaired: Bool, isAppInstalled: Bool, isReachable: Bool) {
        self.isSupported = isSupported
        self.isPaired = isPaired
        self.isAppInstalled = isAppInstalled
        self.isReachable = isReachable
    }
}

/// What to show about the watch, and whether anybody has to do anything.
public struct WatchReadiness: Equatable, Sendable {
    /// The one line that says where things stand.
    public let headline: String

    /// What to do about it, or nil when there is nothing to do.
    public let instruction: String?

    /// Whether this needs the operator's attention, which is what decides whether the row
    /// is drawn as a warning or as a quiet statement of fact.
    public let needsAttention: Bool

    public init(state: WatchState) {
        guard state.isSupported else {
            headline = "This device has no Apple Watch support"
            instruction = nil
            needsAttention = false
            return
        }

        guard state.isPaired else {
            headline = "No Apple Watch paired with this phone"
            instruction = "Pair a watch in the Watch app, and the court appears on it by itself."
            needsAttention = false
            return
        }

        guard state.isAppInstalled else {
            // The case this whole file exists for. Nothing on either screen said it, and the
            // only symptom is a wrist that never shows a court.
            headline = "The watch app is not installed"
            instruction =
                "Open the Watch app on this iPhone, go to My Watch, scroll to Volleyball Serve"
                + " Tracker, and turn on Show App on Apple Watch. A TestFlight build often has"
                + " to be switched on by hand."
            needsAttention = true
            return
        }

        // Installed but asleep is the ordinary resting state of a watch, so it is said
        // without alarm: a wrist at somebody's side is unreachable and perfectly well.
        headline = state.isReachable ? "Watch app installed and awake" : "Watch app installed"
        instruction = nil
        needsAttention = false
    }
}
