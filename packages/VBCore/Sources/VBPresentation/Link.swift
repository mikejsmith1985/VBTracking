// What travels between the phone and the wrist.
//
// Two directions, two different guarantees, because they want opposite things. Out goes a
// picture where only the newest one matters. Back come events, where every one matters and
// none may arrive twice.
//
// The shapes and the rules live here so they can be tested without two devices — and
// without a Mac.
import Foundation
import VBCore

/// One box, as it travels to the wrist.
public struct SnapshotSlot: Equatable, Codable, Sendable {
    public var court: Int
    public var number: String?

    /// Nil when the player has not served. A dash on the wrist, never `0%`.
    public var inPercentage: Double?

    /// Nil where points were never recorded.
    public var points: Int?

    public var isServing: Bool
    public var isOnDeck: Bool

    public init(
        court: Int,
        number: String?,
        inPercentage: Double?,
        points: Int?,
        isServing: Bool,
        isOnDeck: Bool
    ) {
        self.court = court
        self.number = number
        self.inPercentage = inPercentage
        self.points = points
        self.isServing = isServing
        self.isOnDeck = isOnDeck
    }
}

/// The court, as it travels to the wrist.
///
/// Figures, not the log: the watch draws six boxes and has no use for a season.
public struct CourtSnapshot: Equatable, Codable, Sendable {
    /// Increases by one per snapshot. The watch discards anything not newer than it holds,
    /// because snapshots can arrive out of order and the older one must never win.
    public var sequence: Int

    /// When the phone made it, so the wrist can say how current it is.
    public var capturedAt: Date

    /// Which match or game the figures cover, in words.
    public var scopeLabel: String

    /// Nil when there is no order, in which case the watch must say it cannot name the next
    /// server rather than presenting one.
    public var hasOrder: Bool

    public var slots: [SnapshotSlot]

    public init(sequence: Int, capturedAt: Date, scopeLabel: String, hasOrder: Bool, slots: [SnapshotSlot]) {
        self.sequence = sequence
        self.capturedAt = capturedAt
        self.scopeLabel = scopeLabel
        self.hasOrder = hasOrder
        self.slots = slots
    }

    /// Builds the snapshot the wrist should be showing.
    public init(court: CourtView, sequence: Int, capturedAt: Date) {
        self.sequence = sequence
        self.capturedAt = capturedAt
        self.scopeLabel = court.scopeLabel
        self.hasOrder = court.hasOrder
        self.slots = court.slots.map { slot in
            SnapshotSlot(
                court: slot.position.rawValue,
                number: slot.number,
                inPercentage: slot.inPercentage,
                points: slot.points,
                isServing: slot.isServing,
                // Without an order there is nobody on deck, and nothing may be marked as
                // though there were.
                isOnDeck: slot.isOnDeck && court.hasOrder
            )
        }
    }
}

/// How current the wrist's picture is.
public struct LinkFreshness: Equatable, Sendable {
    public var secondsOld: Int
    public var isCurrent: Bool

    /// Past this, the wrist stops presenting its court as the truth.
    ///
    /// A quietly stale court is worse than a blank one: the coach would substitute on a
    /// percentage that has since moved.
    public static let stalenessThreshold = 20

    public init(capturedAt: Date, now: Date) {
        let age = Int(now.timeIntervalSince(capturedAt).rounded())
        self.secondsOld = max(0, age)
        self.isCurrent = self.secondsOld < Self.stalenessThreshold
    }

    /// What the wrist says about its own picture.
    public var label: String {
        isCurrent ? text(secondsAgo: secondsOld) : "not current · \(text(secondsAgo: secondsOld))"
    }
}

/// The events the wrist has recorded and the phone has not yet confirmed.
///
/// Delivery is guaranteed but not immediate, so the wrist shows what has not landed. A
/// serve recorded out of range must never be assumed safe.
public struct PendingQueue: Equatable, Sendable {
    public private(set) var events: [RawEvent] = []

    public init() {}

    public var count: Int { events.count }

    /// Adds an event to be sent.
    public mutating func add(_ event: RawEvent) {
        events.append(event)
    }

    /// Drops the events the phone has confirmed, whatever order the confirmation arrives in.
    public mutating func confirm(_ ids: Set<String>) {
        events.removeAll { ids.contains($0["eventId"]?.stringValue ?? "") }
    }

    /// What the wrist shows: nothing at all when everything has landed.
    public var label: String? {
        switch count {
        case 0: nil
        case 1: "1 serve not sent"
        default: "\(count) serves not sent"
        }
    }
}

/// Applies events arriving from the wrist to the phone's own log.
///
/// Exactly once: an identifier already held is ignored. Delivery may retry freely, which is
/// what makes "exactly once" a fact rather than a hope.
public func merge(
    incoming: [RawEvent],
    into log: [RawEvent]
) -> (log: [RawEvent], accepted: [String]) {
    let known = Set(log.compactMap { $0["eventId"]?.stringValue })
    var merged = log
    var accepted: [String] = []

    for event in incoming {
        guard let id = event["eventId"]?.stringValue, !id.isEmpty else { continue }
        guard !known.contains(id), !accepted.contains(id) else { continue }
        merged.append(event)
        accepted.append(id)
    }
    return (merged, accepted)
}
