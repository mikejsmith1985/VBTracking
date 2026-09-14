// What a tap means.
//
// Two things are tappable: a player, and a place on the court. What either tap means
// depends on what the operator is already holding — because the whole gesture is two taps,
// and the first tap is what makes the second one unambiguous.
//
// Arranging the rotation works in both directions, because before a match people think in
// both: tap the empty spot then the player who stands there, or tap the player then the
// spot they go to. Neither is the "right" order, so neither is required.
//
// Substituting is bench first, then the player leaving — the same order the swap happens on
// the court. The gesture this replaced asked for a double tap, which is a thing to remember
// rather than a thing to do, and it put a delay on every tap of the picker.
import Foundation
import VBCore

/// What the operator has picked up, waiting for the tap that says what to do with it.
public enum Armed: Equatable, Sendable {
    /// A player, waiting for a destination: a spot to stand in, or someone to replace.
    case player(String)

    /// A place in the serving order, waiting for whoever is to stand in it.
    case position(Int)

    /// The player being held, if it is a player.
    public var playerId: String? {
        if case let .player(id) = self { return id }
        return nil
    }

    /// The place being held, if it is a place.
    public var lineupIndex: Int? {
        if case let .position(index) = self { return index }
        return nil
    }
}

/// What tapping a player, or a place, should do next.
public enum TapIntent: Equatable, Sendable {
    /// Hand them the ball.
    case serve(playerId: String)

    /// Hold them as the player coming on; the next tap says where they go.
    case armSubstitution(incomingPlayerId: String)

    /// Hold a place in the order; the next tap says who stands in it.
    case armPosition(lineupIndex: Int)

    /// Stand a player at a place in the serving order.
    case place(playerId: String, lineupIndex: Int)

    /// Complete a substitution: the armed player comes on where this one goes off.
    case substitute(outPlayerId: String, inPlayerId: String)

    /// Exchange two places in the serving order. A correction, not a substitution --
    /// both players are already on court and neither is leaving it.
    case swap(firstIndex: Int, secondIndex: Int)

    /// Nothing — put down whatever is being held and carry on.
    case ignore
}

/// Works out what tapping a player means, given what is already held.
///
/// Pure, and tested, because getting this wrong during a rally means a substitution nobody
/// asked for or a server nobody chose.
public func intent(
    ofTapping playerId: String,
    state: AppState,
    armed: Armed?
) -> TapIntent {
    let match = state.currentMatch
    let lineup = match?.lineup
    let isOnCourt = lineup?.contains(playerId) == true

    switch armed {
    case let .position(lineupIndex):
        return .place(playerId: playerId, lineupIndex: lineupIndex)

    case let .player(incoming):
        // Tapping the held player again means "they serve now" -- the recorded case where
        // the referee lets someone out of the order take the ball.
        if incoming == playerId { return .serve(playerId: playerId) }

        let isIncomingOnCourt = lineup?.contains(incoming) == true

        if isOnCourt {
            // Two players already on court exchange places. Nobody is leaving the floor, so
            // this is a correction to the order and never a substitution -- recording it as
            // one would put a swap in the history that did not happen.
            if isIncomingOnCourt,
                let held = lineup?.firstIndex(of: incoming),
                let tapped = lineup?.firstIndex(of: playerId)
            {
                return .swap(firstIndex: held, secondIndex: tapped)
            }

            // Before the first serve this is still arranging, not substituting: writing a
            // substitution into a match nobody has played would put a swap in the record
            // that never happened on the floor.
            if state.canArrangeRotation, let index = lineup?.firstIndex(of: playerId) {
                return .place(playerId: incoming, lineupIndex: index)
            }
            return .substitute(outPlayerId: playerId, inPlayerId: incoming)
        }

        // Holding somebody on court and tapping the bench is the same substitution said the
        // other way round. Re-aiming there would refuse the more natural order of the two.
        if isIncomingOnCourt, !state.canArrangeRotation {
            return .substitute(outPlayerId: incoming, inPlayerId: playerId)
        }

        // A different bench player: re-aim rather than refuse.
        return .armSubstitution(incomingPlayerId: playerId)

    case nil:
        // An order still being built: a tap picks the player up, and the next tap says
        // where they stand. Serving them instead was the old behaviour and it made
        // building a rotation player-first impossible -- the first tap started recording
        // their serves.
        if state.canArrangeRotation, !isLineupComplete(lineup) {
            return playerId == state.activeServerId ? .ignore : .armSubstitution(incomingPlayerId: playerId)
        }

        // Nothing held, and a tap on somebody already on court picks them up -- it does not
        // hand them the ball. Serving on a single tap meant one stray touch of the court
        // started a turn for the wrong player, and it made exchanging two players on court
        // impossible, because the first tap served instead of selecting. Tapping the held
        // player again is what serves.
        guard lineup != nil else {
            return playerId == state.activeServerId ? .ignore : .serve(playerId: playerId)
        }
        return .armSubstitution(incomingPlayerId: playerId)
    }
}

/// True when somebody is standing in every place in the order.
///
/// Half an order is still being arranged; a whole one is ready to serve, and from then on a
/// tap on a player means hand them the ball.
public func isLineupComplete(_ lineup: [String?]?) -> Bool {
    guard let lineup, lineup.count >= lineupSize else { return false }
    return lineup.prefix(lineupSize).allSatisfy { $0 != nil }
}

/// Works out what tapping a place on the court means, given what is already held.
///
/// `lineupIndex` is the place in the serving order, not the number painted on the floor:
/// the court is drawn around whoever is serving, so the same box is a different place in
/// the order at different moments.
public func intent(
    ofTappingPosition lineupIndex: Int,
    state: AppState,
    armed: Armed?
) -> TapIntent {
    guard (0..<lineupSize).contains(lineupIndex) else { return .ignore }

    switch armed {
    case let .player(incoming):
        return .place(playerId: incoming, lineupIndex: lineupIndex)

    case let .position(held):
        // Tapping the held place again puts it down, so a mis-tap costs one tap to undo
        // rather than a placement the operator then has to unpick.
        return held == lineupIndex ? .ignore : .armPosition(lineupIndex: lineupIndex)

    case nil:
        return .armPosition(lineupIndex: lineupIndex)
    }
}

/// The words under the picker, which change what the next tap will do and so must say so.
public func pickerHint(state: AppState, armed: Armed?) -> String {
    switch armed {
    case let .position(lineupIndex):
        return "Tap the player who serves \(ordinal(lineupIndex + 1)). Tap the spot again to cancel."

    case let .player(playerId):
        let name = state.rosterEntry(id: playerId)?.name ?? "That player"
        if state.canArrangeRotation {
            return "\(name) — tap a spot to stand them there, or tap them again to serve first."
        }
        if state.currentMatch?.lineup?.contains(playerId) == true {
            // Held player already on court: the two useful things are swapping them
            // with somebody else out there, or handing them the ball.
            return "\(name) — tap another player on court to swap them, the bench to sub, or tap again to serve."
        }
        return "\(name) is coming on — tap who they replace. Tap them again to serve without substituting."

    case nil:
        if state.canArrangeRotation, !isLineupComplete(state.currentLineup) {
            return "Tap a spot then a player, or a player then a spot. Serving corner is bottom right."
        }
        guard state.currentLineup != nil else { return "Tap the next server" }
        if state.canArrangeRotation {
            return "Tap whoever serves first · serving corner is bottom right"
        }
        // The serving corner stays in it: it is the one thing on this screen somebody
        // has to be told once, and a test keeps it there for that reason.
        return "Serving corner is bottom right · tap to pick up, again to serve, another to swap"
    }
}

/// "1st", "2nd", "3rd" — how a place in the order is spoken.
public func ordinal(_ value: Int) -> String {
    switch value {
    case 1: "1st"
    case 2: "2nd"
    case 3: "3rd"
    default: "\(value)th"
    }
}
