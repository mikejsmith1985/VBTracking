// Two phones at the same match, only one of them tracking.
//
// The coach's watch pairs to the coach's phone and to nothing else, so a court cannot travel
// from the tracker's phone to the coach's wrist directly. It goes phone to phone, and the
// coach's phone feeds her own watch by the link that already exists -- which is why the watch
// app needs no change at all for this.
//
// Everything here is pure: no radio, no storage, no clock. The transport is a thin shim that
// carries what these types decide, so the decisions can be tested on a machine with no phone
// attached.
import Foundation
import VBCore

/// What this phone is allowed to do while two are linked.
public enum PeerRole: Equatable, Sendable {
    /// No other phone. Every phone shipped so far, and the ordinary case.
    case alone

    /// This phone is keeping the record. The other one is watching it.
    case tracking

    /// This phone is watching somebody else's match.
    case following

    /// Whether the operator may record a serve.
    ///
    /// A follower may not. Two phones both recording the same game produce two logs of it,
    /// and those cannot be joined afterwards -- the merge refuses them, because appending one
    /// to the other would say every serve happened twice. Refusing to start the second log is
    /// the only point at which that is preventable.
    public var canRecord: Bool {
        switch self {
        case .alone, .tracking: true
        case .following: false
        }
    }

    /// Why the recording controls are not there, for the one role where they are missing.
    ///
    /// Nil where nothing is missing: a sentence explaining why everything is normal is worse
    /// than silence.
    public var explanation: String? {
        switch self {
        case .alone, .tracking: nil
        case .following:
            "You are following this match on another phone. Only the phone doing the tracking"
                + " records serves, so the two records cannot disagree."
        }
    }
}

/// Whether the other phone can be reached, in the words a screen shows.
public enum PeerLinkState: Equatable, Sendable {
    /// Not sharing with anybody. The resting state.
    case off

    /// Sharing is on and no other phone has answered yet.
    case looking

    /// Joined to another phone.
    case connected(peerName: String)

    /// Whether what is on screen is arriving from the other phone right now.
    ///
    /// A link that is down must never be presented as current: a coach substituting on a
    /// percentage that stopped updating ten minutes ago is worse off than one with no figures
    /// at all, because they do not know to distrust it.
    public var isLive: Bool {
        if case .connected = self { return true }
        return false
    }

    /// What the row says.
    public var label: String {
        switch self {
        case .off: "Not sharing"
        case .looking: "Looking for another phone\u{2026}"
        case let .connected(peerName): "Sharing with \(peerName)"
        }
    }
}

/// What travels between two phones, and what does not.
public enum PeerSync {
    /// An event's identifier, or nil for one that has none.
    public static func identifier(_ event: RawEvent) -> String? {
        event["eventId"]?.stringValue
    }

    /// The identifiers this phone holds, which is what it announces to the other.
    ///
    /// Identifiers rather than the log itself. A season is thousands of events; sending it
    /// every few seconds to ask what is missing would put the whole record on the air over
    /// and over for no gain.
    public static func identifiersHeld(_ events: [RawEvent]) -> [String] {
        events.compactMap(identifier)
    }

    /// The events the other phone does not have.
    ///
    /// An event with no identifier is always sent: it cannot be recognised on the far side,
    /// so leaving it out would lose it entirely, and the receiving merge names it from its own
    /// content before deciding whether it is already held.
    public static func eventsToSend(mine: [RawEvent], theyHold: Set<String>) -> [RawEvent] {
        mine.filter { event in
            guard let id = identifier(event) else { return true }
            return !theyHold.contains(id)
        }
    }

    /// Convenience for a caller holding a list rather than a set.
    public static func eventsToSend(mine: [RawEvent], theyHold: [String]) -> [RawEvent] {
        eventsToSend(mine: mine, theyHold: Set(theyHold))
    }
}
