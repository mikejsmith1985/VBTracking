// What the phone shows under the thumb during a rally.
//
// The dock holds a status row over exactly ONE action block: the outcome controls, or the
// picker. Never both — a control that is present but wrong is a mis-tap waiting to happen,
// and this is the one screen where a mis-tap costs a recorded serve.
import Foundation
import VBCore

/// What the dock is showing right now.
public enum DockContent: Equatable, Sendable {
    /// Someone is serving: the three outcomes are under the thumb.
    case outcomes(servingPlayerId: String)

    /// Nobody is serving, or the operator asked to change: the court and bench are shown.
    case picker

    /// There is no match to record into.
    case nothing
}

/// The dock, decided from the state rather than from a pile of flags in a view.
public struct DockState: Equatable, Sendable {
    public var content: DockContent
    public var canUndo: Bool

    /// True when the order is set, so the picker can be drawn as a court.
    public var hasLineup: Bool

    /// Who has the ball, if anyone.
    public var servingPlayerId: String?

    /// True when the operator asked to change server while someone was serving — the only
    /// reason the picker appears mid-turn.
    public var isPickerRequested: Bool

    /// Works out what should be under the thumb.
    ///
    /// `isPickerRequested` is the operator's own override; everything else follows from the
    /// record. A dock that decided for itself would fight the operator at the worst moment.
    public init(state: State, isPickerRequested: Bool, canUndo: Bool) {
        self.canUndo = canUndo
        self.isPickerRequested = isPickerRequested
        self.hasLineup = state.currentMatch?.lineup != nil
        self.servingPlayerId = state.activeServerId

        guard state.currentMatch != nil else {
            self.content = .nothing
            return
        }
        if let serving = state.activeServerId, !isPickerRequested {
            self.content = .outcomes(servingPlayerId: serving)
        } else {
            self.content = .picker
        }
    }

    /// True when the outcome controls are the thing being shown.
    public var isRecording: Bool {
        if case .outcomes = content { return true }
        return false
    }
}

/// The alert raised when a server has taken their five.
///
/// It is the one thing in the app that interrupts, so what it says is worked out here and
/// tested, rather than assembled in a view nobody can run.
public struct ServeLimitAlert: Equatable, Sendable {
    public var finishedPlayerId: String

    /// Who has the ball now, or nil when there is no order to say — in which case the alert
    /// asks for a server rather than naming one.
    public var nextPlayerId: String?

    /// Whether a serve has just taken a player to the limit.
    ///
    /// Exactly at the limit, never past it: a sixth serve is a referee's miscount, recorded
    /// without being nagged about a second time.
    public static func raised(after state: State, servingPlayerId: String?) -> ServeLimitAlert? {
        guard let servingPlayerId,
            let match = state.currentMatch,
            let served = match.turns.last(where: { $0.playerId == servingPlayerId }),
            served.serves.count == serveLimit
        else {
            return nil
        }

        // Only name a next server when it is actually somebody else. Without an order the
        // same player is still holding the ball, and naming them would read as permission
        // to serve a sixth.
        let next = state.activeServerId
        return ServeLimitAlert(
            finishedPlayerId: servingPlayerId,
            nextPlayerId: next == servingPlayerId ? nil : next
        )
    }
}
