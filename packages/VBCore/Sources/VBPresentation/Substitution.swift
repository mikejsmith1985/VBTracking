// What a tap on a player means.
//
// It means one of two things, and which one is decided by where the player is standing
// rather than by how fast the operator taps. Someone already in the order is simply the
// next server. Someone on the bench is the player coming ON: the next tap names who they
// replace, and they take that exact slot.
//
// Bench first, then the player leaving — the same order the swap happens on the court. The
// gesture this replaced asked for a double tap, which is a thing to remember rather than a
// thing to do, and it put a delay on every tap of the picker.
import Foundation
import VBCore

/// What tapping a player should do next.
public enum TapIntent: Equatable, Sendable {
    /// Hand them the ball.
    case serve(playerId: String)

    /// Hold them as the player coming on; the next tap says who they replace.
    case armSubstitution(incomingPlayerId: String)

    /// Complete a substitution: the armed player comes on where this one goes off.
    case substitute(outPlayerId: String, inPlayerId: String)

    /// Nothing — the tap lands on the player who is already serving.
    case ignore
}

/// Works out what a tap means, given who is already armed.
///
/// Pure, and tested, because getting this wrong during a rally means a substitution nobody
/// asked for or a server nobody chose.
public func intent(
    ofTapping playerId: String,
    state: AppState,
    armedIncoming: String?
) -> TapIntent {
    let match = state.currentMatch
    let isOnCourt = match?.lineup?.contains(playerId) == true

    if let armedIncoming {
        // Tapping the armed player again means "they serve now" -- the recorded case where
        // the referee lets someone out of the order take the ball.
        if armedIncoming == playerId { return .serve(playerId: playerId) }
        if isOnCourt { return .substitute(outPlayerId: playerId, inPlayerId: armedIncoming) }
        // A different bench player: re-aim rather than refuse.
        return .armSubstitution(incomingPlayerId: playerId)
    }

    guard match?.lineup != nil, !isOnCourt else {
        return playerId == state.activeServerId ? .ignore : .serve(playerId: playerId)
    }
    return .armSubstitution(incomingPlayerId: playerId)
}

/// The words under the picker, which change what the next tap will do and so must say so.
public func pickerHint(state: AppState, armedIncoming: String?) -> String {
    if let armedIncoming {
        let name = state.rosterEntry(id: armedIncoming)?.name ?? "That player"
        return "\(name) is coming on — tap who they replace. Tap them again to serve without substituting."
    }
    guard state.currentMatch?.lineup != nil else { return "Tap the next server" }
    return "Serving corner is bottom right · tap a bench player to sub them on"
}
