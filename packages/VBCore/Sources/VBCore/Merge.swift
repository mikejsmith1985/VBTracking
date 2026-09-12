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
/// All or nothing, and refused for one reason only: both logs recording the same game.
/// That is the merge that would double what happened on court. Everything else joins, the
/// same way the log is loaded from disk -- the rulebook already ignores an event it cannot
/// accept rather than refusing to start, and a merge must not be stricter than that.
public func merge(mine: [RawEvent], theirs: [RawEvent]) -> MergeResult {
    let named = theirs.enumerated().map { index, event in VBCore.named(event, at: index) }
    let held = Set(mine.compactMap { $0["eventId"]?.stringValue })
    let arriving = named.filter { event in
        guard let id = event["eventId"]?.stringValue else { return true }
        return !held.contains(id)
    }

    guard !arriving.isEmpty else { return MergeResult(events: mine) }

    let before = replay(raw: mine)
    if let doubled = gameRecordedTwice(before, arriving) {
        return MergeResult(
            events: mine,
            refusal: "Both phones recorded \(doubled). Joining them would double what is on"
                + " the court, so nothing was changed."
        )
    }

    let joined = mine + arriving
    let after = replay(raw: joined)
    return MergeResult(
        events: joined,
        eventsAdded: arriving.count,
        seasonsAdded: after.seasons.count - before.seasons.count,
        playersAdded: after.players.count - before.players.count
    )
}

/// Names a game that both logs record, or nil when they record none in common.
///
/// This is the one merge that cannot be allowed: two people tracking the same match produce
/// two sets of serves for it, and appending one to the other would say every serve happened
/// twice. Every other overlap is harmless -- a shared roster, a season both phones know
/// about -- because an event already held is skipped by identifier before this is reached.
///
/// Checked by game identity rather than by asking the rulebook whether each event is
/// allowed. A real log contains events the rulebook itself ignores on replay, so refusing on
/// the first one of those refused whole seasons that were perfectly good.
private func gameRecordedTwice(_ mine: AppState, _ arriving: [RawEvent]) -> String? {
    let held = Set(mine.games.map(\.id))
    guard !held.isEmpty else { return nil }

    for raw in arriving {
        guard let event = Event(raw: raw) else { continue }
        switch event.kind {
        case let .startGame(id, _, _) where held.contains(id):
            return "that game"
        case let .addHistoricalGame(id, _, context, _, _, _) where held.contains(id):
            return context.opponent.isEmpty ? "that game" : "the game against \(context.opponent)"
        default:
            continue
        }
    }
    return nil
}
