// The link between the two devices, behind a door that can be shut.
//
// `WCSession` cannot be created in a test, and there is no Mac here to run one on. So every
// rule about ordering, staleness and delivery is written against this protocol, and the
// tests drive a fake. The real session is exercised on a real watch, in a real gym, which
// is the only place the three-second figure in SC-002 means anything.
import Foundation
import VBCore
import VBPresentation

/// What either device needs from the connection, and nothing more.
public protocol ConnectivitySession: AnyObject, Sendable {
    /// True while the other device can be reached right now.
    var isReachable: Bool { get }

    /// Sends the newest picture of the court. Latest wins; older ones are of no use.
    func send(context: [String: Any])

    /// Queues events for delivery. Guaranteed, in order, and it survives going out of range.
    func transfer(userInfo: [String: Any])
}

/// What arrives.
public protocol ConnectivityDelegate: AnyObject, Sendable {
    func received(context: [String: Any])
    func received(userInfo: [String: Any])
    func reachabilityChanged(isReachable: Bool)
}

/// The keys both sides agree on. One place, so a rename cannot half-happen.
public enum LinkKey {
    public static let snapshot = "snapshot"
    public static let events = "events"
    public static let confirmedEventIds = "confirmedEventIds"
    /// Phone to phone: the identifiers a phone already holds, so the other sends only the
    /// difference rather than the season.
    public static let heldEventIds = "heldEventIds"
}

/// The link between two phones in the same room.
///
/// Separate from `ConnectivitySession` because the two links answer different questions. The
/// watch link has exactly one peer, always the same one, paired at the factory of the
/// relationship; this one has to find a phone that may not be there, may be somebody else's,
/// and can leave halfway through a match.
public protocol PeerSession: AnyObject, Sendable {
    /// Starts looking, and starts being findable.
    func start()

    /// Stops both, and drops any phone already joined.
    func stop()

    /// Sends to whichever phone is joined. Does nothing when none is.
    func send(_ payload: [String: Any])
}

/// What arrives from the other phone.
public protocol PeerDelegate: AnyObject, Sendable {
    func received(fromPeer payload: [String: Any])
    func peerLinkChanged(_ state: PeerLinkState)
}

/// Encoding the two payloads.
///
/// `WCSession` carries property lists, not `Data` conveniences, so the shapes are converted
/// once here rather than at every call site.
public enum LinkPayload {
    /// The court, ready to send.
    public static func encode(snapshot: CourtSnapshot) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(snapshot) else { return [:] }
        return [LinkKey.snapshot: data]
    }

    /// The court, as it arrives.
    public static func decodeSnapshot(_ payload: [String: Any]) -> CourtSnapshot? {
        guard let data = payload[LinkKey.snapshot] as? Data else { return nil }
        return try? JSONDecoder().decode(CourtSnapshot.self, from: data)
    }

    /// Events recorded on the wrist, ready to send.
    public static func encode(events: [RawEvent]) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(events.map { JSONValue.object($0) }) else { return [:] }
        return [LinkKey.events: data]
    }

    /// Events recorded on the wrist, as they arrive.
    public static func decodeEvents(_ payload: [String: Any]) -> [RawEvent] {
        guard let data = payload[LinkKey.events] as? Data,
            let values = try? JSONDecoder().decode([JSONValue].self, from: data)
        else {
            return []
        }
        return values.compactMap(\.objectValue)
    }

    /// The identifiers the phone has taken, sent back so the wrist can stop showing them
    /// as unsent.
    public static func encode(confirmed ids: [String]) -> [String: Any] {
        [LinkKey.confirmedEventIds: ids]
    }

    public static func decodeConfirmed(_ payload: [String: Any]) -> Set<String> {
        Set(payload[LinkKey.confirmedEventIds] as? [String] ?? [])
    }

    /// What a phone holds, announced so the other sends only what is missing.
    public static func encode(held ids: [String]) -> [String: Any] {
        [LinkKey.heldEventIds: ids]
    }

    public static func decodeHeld(_ payload: [String: Any]) -> [String]? {
        payload[LinkKey.heldEventIds] as? [String]
    }

    /// Multipeer carries `Data`, not a property list, so a payload is flattened once here
    /// rather than at every call site.
    ///
    /// The values are `Data` and arrays of `String` only, which is what makes a plain
    /// property-list serialisation enough -- and keeps the wire format something a person
    /// can read in a debugger.
    public static func data(from payload: [String: Any]) -> Data? {
        try? PropertyListSerialization.data(fromPropertyList: payload, format: .binary, options: 0)
    }

    public static func payload(from data: Data) -> [String: Any]? {
        let decoded = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return decoded as? [String: Any]
    }
}
