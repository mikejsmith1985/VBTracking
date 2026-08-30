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

/// The five-serve rule, as the wrist needs to hear it.
///
/// The watch cannot work this out for itself: the phone holds the record, and the count of
/// a turn is on the phone. So the phone says it, and says it in numbers a box can draw
/// without a roster.
public struct ServeLimitNotice: Equatable, Codable, Sendable {
    /// Who has just finished their five.
    public var finishedNumber: String?

    /// Who takes the ball next, or nil when there is no order to say — in which case the
    /// wrist asks for a server rather than naming one.
    public var nextNumber: String?

    /// How many serves stood on the record when this was raised.
    ///
    /// The wrist buzzes once per raising and stops once it is cleared. Two raisings always
    /// sit at different counts, so this tells them apart without a clock or a made-up id —
    /// and an undo that takes the count back down raises it again honestly.
    public var raisedAtServeCount: Int

    public init(finishedNumber: String?, nextNumber: String?, raisedAtServeCount: Int) {
        self.finishedNumber = finishedNumber
        self.nextNumber = nextNumber
        self.raisedAtServeCount = raisedAtServeCount
    }

    /// Reads the rule off the record, or nothing when it has not just fired.
    ///
    /// Derived rather than remembered, so it clears itself the moment the next serve is
    /// recorded: a notice held in a variable would still be true after play moved on.
    public static func raised(by state: AppState) -> ServeLimitNotice? {
        guard let match = state.currentMatch else { return nil }

        // The turn that has the ball, open or just closed. Both shapes happen: with an
        // order the fifth serve closes the turn and rotates, and without one the same
        // player is still standing there holding it -- which is the case the rule exists
        // for, so it must not be the case that goes unannounced.
        guard let recent = match.turns.last(where: { !$0.serves.isEmpty }),
            recent.serves.count == serveLimit
        else {
            // Fewer than five, or a sixth already served past a referee's miscount:
            // either way nothing is being raised now.
            return nil
        }

        // Only name a next server when it is actually somebody else. Without an order the
        // same player still holds the ball, and naming them would read as permission to
        // serve a sixth.
        let next = state.activeServerId
        return ServeLimitNotice(
            finishedNumber: state.rosterEntry(id: recent.playerId)?.number,
            nextNumber: next == recent.playerId ? nil : next.flatMap { state.rosterEntry(id: $0)?.number },
            raisedAtServeCount: match.turns.reduce(0) { $0 + $1.serves.count }
        )
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

    /// Set while a player has just taken their five and nothing has been recorded since.
    ///
    /// Optional so that a watch built before this existed still reads a snapshot sent by a
    /// phone that sends it.
    public var serveLimit: ServeLimitNotice?

    /// The identifiers of the most recent events the phone holds.
    ///
    /// This is how a serve recorded on the wrist stops showing as unsent. The confirmation
    /// used to travel on its own, by `transferUserInfo` -- which is guaranteed but
    /// opportunistic, and can take minutes. The court arrives at once, so the wrist could
    /// sit there saying "1 serve not sent" about a serve already safely on the phone and
    /// visible on its screen. Riding the fast channel makes the wrist honest.
    ///
    /// Read off the log rather than remembered, so it survives the phone app restarting,
    /// and capped so a season does not travel to a wrist that only needs the last few.
    public var acknowledgedEventIds: [String]

    public init(
        sequence: Int,
        capturedAt: Date,
        scopeLabel: String,
        hasOrder: Bool,
        slots: [SnapshotSlot],
        serveLimit: ServeLimitNotice? = nil,
        acknowledgedEventIds: [String] = []
    ) {
        self.sequence = sequence
        self.capturedAt = capturedAt
        self.scopeLabel = scopeLabel
        self.hasOrder = hasOrder
        self.slots = slots
        self.serveLimit = serveLimit
        self.acknowledgedEventIds = acknowledgedEventIds
    }

    /// Reads a court that may have been written by a different build.
    ///
    /// Every field added after the first release is read with `decodeIfPresent`, because the
    /// synthesised decoder does not fall back to a property's default value -- it throws on a
    /// missing key, `decodeSnapshot` turns that into nil, and the wrist shows no court at
    /// all. A watch and a phone are two installs that can be a version apart, and the cost
    /// of being wrong here is the whole screen rather than one line of it.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sequence = try container.decode(Int.self, forKey: .sequence)
        self.capturedAt = try container.decode(Date.self, forKey: .capturedAt)
        self.scopeLabel = try container.decode(String.self, forKey: .scopeLabel)
        self.hasOrder = try container.decode(Bool.self, forKey: .hasOrder)
        self.slots = try container.decode([SnapshotSlot].self, forKey: .slots)
        self.serveLimit = try container.decodeIfPresent(ServeLimitNotice.self, forKey: .serveLimit)
        // Nothing acknowledged, rather than everything: a phone that says nothing has
        // vouched for nothing, and a serve stays marked unsent until something says it
        // landed.
        self.acknowledgedEventIds =
            try container.decodeIfPresent([String].self, forKey: .acknowledgedEventIds) ?? []
    }

    /// Builds the snapshot the wrist should be showing.
    public init(
        court: CourtView,
        sequence: Int,
        capturedAt: Date,
        serveLimit: ServeLimitNotice? = nil,
        acknowledgedEventIds: [String] = []
    ) {
        self.sequence = sequence
        self.capturedAt = capturedAt
        self.scopeLabel = court.scopeLabel
        self.hasOrder = court.hasOrder
        self.serveLimit = serveLimit
        self.acknowledgedEventIds = acknowledgedEventIds
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

/// The identifiers of the newest events in a log, for the wrist to check its own against.
///
/// Capped, because the wrist only ever has a handful of serves outstanding and a season of
/// identifiers has no business travelling between two devices every time a court changes.
/// Fifty is far more than a gym evening ever needs.
public func acknowledgedIds(in log: [RawEvent], limit: Int = 50) -> [String] {
    log.suffix(limit).compactMap { $0["eventId"]?.stringValue }
}

/// Whether a court that has just arrived should replace the one on screen.
///
/// By the moment it was captured, not by the counter beside it. The counter lives in memory
/// on the phone and starts again at zero every time that app is launched -- and iOS relaunches
/// a backgrounded app constantly. A wrist holding sequence 47 from before the phone restarted
/// then rejected every snapshot that followed as though it were older, and went on showing a
/// court from twenty minutes ago until somebody force-quit the watch app.
///
/// `capturedAt` comes from one clock, the phone's, so it orders correctly across as many
/// relaunches as the evening produces. The sequence still breaks a tie inside the same
/// instant, which is the only thing it was ever good for.
public func isNewer(_ incoming: CourtSnapshot, than held: CourtSnapshot?) -> Bool {
    guard let held else { return true }
    if incoming.capturedAt != held.capturedAt { return incoming.capturedAt > held.capturedAt }
    return incoming.sequence > held.sequence
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
