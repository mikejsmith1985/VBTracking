// Taking in a season somebody else recorded, without losing the one already here.
//
// A coach and an assistant coach at the same match need the same figures, and only one of
// them is tracking. Handing the season over must add what the other phone does not have and
// touch nothing it does. Restoring a backup replaces everything, which is right for a lost
// phone and wrong for this.
//
// Pure, like everything else in this file's neighbourhood: no storage, no clock, no
// network. The caller supplies both logs and is handed a third.
import Foundation

/// The result of merging one log into another.
public struct MergeResult: Equatable, Sendable {
    /// The log to keep. Unchanged from `mine` when the merge was refused.
    public var events: [RawEvent]

    /// Why nothing was taken, or nil when the merge went through.
    public var refusal: String?

    /// How many events arrived, so the operator can be told rather than guess.
    public var eventsAdded: Int

    /// How many whole seasons arrived.
    public var seasonsAdded: Int

    /// How many people arrived who were not already known.
    public var playersAdded: Int

    public init(
        events: [RawEvent],
        refusal: String? = nil,
        eventsAdded: Int = 0,
        seasonsAdded: Int = 0,
        playersAdded: Int = 0
    ) {
        self.events = events
        self.refusal = refusal
        self.eventsAdded = eventsAdded
        self.seasonsAdded = seasonsAdded
        self.playersAdded = playersAdded
    }
}

/// Merges another phone's log into this one.
///
/// Everything already here is kept, in the order it was recorded, and the other log's events
/// are appended in theirs. An event already held is recognised by its identifier and skipped,
/// so the same file arriving twice adds nothing the second time.
///
/// All or nothing. If the rulebook would refuse any arriving event -- two phones that both
/// recorded the same game, most likely -- the whole merge is refused and the log is left
/// exactly as it was. Taking the half that fits would leave a season part arrived, which is
/// worse than not taking it.
public func merge(mine: [RawEvent], theirs: [RawEvent]) -> MergeResult {
    let named = theirs.enumerated().map { index, event in VBCore.named(event, at: index) }
    let held = Set(mine.compactMap { $0["eventId"]?.stringValue })
    let arriving = named.filter { event in
        guard let id = event["eventId"]?.stringValue else { return true }
        return !held.contains(id)
    }

    guard !arriving.isEmpty else { return MergeResult(events: mine) }

    guard let accepted = accepting(mine, arriving) else {
        return MergeResult(
            events: mine,
            refusal: "That season cannot be merged with this one. They record some of the same"
                + " games, and joining them would double what is on the court."
        )
    }

    let before = replay(raw: mine)
    let after = replay(raw: accepted)
    return MergeResult(
        events: accepted,
        eventsAdded: arriving.count,
        seasonsAdded: after.seasons.count - before.seasons.count,
        playersAdded: after.players.count - before.players.count
    )
}

/// The joined log, or nil when the rulebook would refuse any of the arriving events.
///
/// Each arriving event is checked against the state it would actually meet, not against an
/// empty one, because whether an event is allowed depends entirely on what came before it.
private func accepting(_ mine: [RawEvent], _ arriving: [RawEvent]) -> [RawEvent]? {
    var state = replay(raw: mine)
    for raw in arriving {
        guard let event = Event(raw: raw) else { return nil }
        guard isEventValid(state, event) else { return nil }
        state = applyEvent(state, event)
    }
    return mine + arriving
}
