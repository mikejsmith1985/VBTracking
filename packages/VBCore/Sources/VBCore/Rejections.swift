// Why an event would be refused, or nil when it would be accepted.
//
// A refusal is a returned sentence, never a thrown error: the operator is standing at the
// side of a court, and the only useful thing the app can do is say what is wrong in words
// they can act on. The wording is carried over from the shipped web app unchanged, because
// it has already been read in a gym.
import Foundation

/// Why the event would be refused, or nil when it would be accepted.
public func rejectionReason(_ state: AppState, _ event: Event) -> String? {
    switch event.kind {
    case let .createSeason(id, name, _, _):
        if state.season(id: id) != nil { return "That season already exists." }
        return namePresence(name, of: "season")

    case let .renameSeason(id, name, _):
        guard state.season(id: id) != nil else { return "That season does not exist." }
        return namePresence(name, of: "season")

    case let .activateSeason(id):
        guard state.season(id: id) != nil else { return "That season does not exist." }
        // Ending one match of three opens the next, so "end the match" would be misleading
        // advice: the game is what has to finish.
        if state.currentMatch != nil {
            return "Finish or discard the game in progress before switching seasons."
        }
        return nil

    case let .addPlayer(id, name, _, seasonId):
        return addPlayerRejection(state, id: id, name: name, seasonId: seasonId)

    case let .editPlayer(id, name, _, _):
        guard state.player(id: id) != nil else { return "That player does not exist." }
        return namePresence(name, of: "player")

    case let .removePlayer(id, _):
        return state.player(id: id) != nil ? nil : "That player is not on the roster."

    case let .removeFromSeason(playerId, seasonId):
        let resolved = seasonIdFor(state, seasonId)
        guard state.season(id: resolved) != nil else { return "That season does not exist." }
        guard state.number(inSeason: resolved, playerId: playerId) != nil else {
            return "That player is not on this roster."
        }
        return nil

    case let .startGame(id, _, _):
        if state.games.contains(where: { $0.id == id }) { return "That game already exists." }
        if state.currentMatch != nil { return "Finish the current game before starting another." }
        return nil

    case let .discardGame(id):
        return state.games.contains { $0.id == id } ? nil : "That game no longer exists."

    case let .setGameContext(gameId, _):
        return state.game(id: gameId) != nil ? nil : "That game no longer exists."

    case let .setGameNotes(gameId, _):
        return state.game(id: gameId) != nil ? nil : "That game no longer exists."

    case let .setMatchResult(gameId, matchIndex, result):
        return setMatchResultRejection(state, gameId: gameId, matchIndex: matchIndex, result: result)

    case let .addHistoricalGame(id, seasonId, _, entries, _, _):
        return historicalGameRejection(state, id: id, seasonId: seasonId, entries: entries, isNew: true)

    case let .editHistoricalGame(id, _, entries, _, _):
        return historicalGameRejection(state, id: id, seasonId: nil, entries: entries, isNew: false)

    case let .setLineup(playerIds):
        return setLineupRejection(state, playerIds: playerIds)

    case .clearLineup:
        return state.currentMatch != nil ? nil : "No match is in progress."

    case let .substitute(outPlayerId, inPlayerId):
        return substituteRejection(state, outPlayerId: outPlayerId, inPlayerId: inPlayerId)

    case let .selectServer(playerId):
        if state.currentMatch == nil { return "No match is in progress." }
        return state.rosterEntry(id: playerId) != nil ? nil : "That player is not on the roster."

    case let .recordServe(outcome):
        if outcome == nil { return "Unrecognised serve outcome." }
        return state.currentMatch?.openTurn != nil ? nil : "Select the server first."

    case let .endMatch(result):
        return endMatchRejection(state, result: result)

    case let .endGame(result):
        return endMatchRejection(state, result: result)

    case let .setTurnServes(gameId, matchIndex, ordinal, outcomes):
        return turnCorrectionRejection(
            state, gameId: gameId, matchIndex: matchIndex, ordinal: ordinal,
            check: .serves(outcomes)
        )

    case let .reassignTurn(gameId, matchIndex, ordinal, playerId):
        return turnCorrectionRejection(
            state, gameId: gameId, matchIndex: matchIndex, ordinal: ordinal,
            check: .player(playerId)
        )

    case let .deleteTurn(gameId, matchIndex, ordinal):
        return turnCorrectionRejection(
            state, gameId: gameId, matchIndex: matchIndex, ordinal: ordinal, check: .delete
        )

    case let .insertTurn(gameId, matchIndex, afterOrdinal, playerId):
        return insertTurnRejection(
            state, gameId: gameId, matchIndex: matchIndex,
            afterOrdinal: afterOrdinal, playerId: playerId
        )

    case .unrecognised:
        return "Unrecognised event."
    }
}

// MARK: - Individual rules

private func addPlayerRejection(_ state: AppState, id: String, name: String, seasonId: String?) -> String? {
    let resolved = seasonIdFor(state, seasonId)
    if let season = state.season(id: resolved) {
        if season.members.count >= maxRoster {
            return "The roster is full — \(maxRoster) players maximum."
        }
        if season.members.contains(where: { $0.playerId == id }) {
            return "That player is already on this season\u{2019}s roster."
        }
    }
    return namePresence(name, of: "player")
}

private func setMatchResultRejection(
    _ state: AppState,
    gameId: String,
    matchIndex: Int,
    result: ResultField
) -> String? {
    guard let game = state.game(id: gameId) else { return "That game no longer exists." }
    guard game.kind == .tracked else {
        return "That game was recorded from paper; set its result instead."
    }
    guard game.matches.contains(where: { $0.index == matchIndex }) else {
        return "That match is not part of this game."
    }
    // Absent is as wrong as unrecognised here: setting a result to nothing says nothing.
    guard case .value = result else { return "Unrecognised match result." }
    return nil
}

private func historicalGameRejection(
    _ state: AppState,
    id: String,
    seasonId: String?,
    entries: [RawHistoricalEntry]?,
    isNew: Bool
) -> String? {
    let existing = state.game(id: id)
    if isNew, existing != nil { return "That game already exists." }
    if !isNew, existing == nil { return "That game no longer exists." }
    guard let entries else { return "A recorded game needs serve figures." }

    let resolved = isNew ? seasonIdFor(state, seasonId) : (existing?.seasonId ?? "")
    for entry in entries {
        guard let checked = entry.checked, checked.servesIn >= 0, checked.servesOut >= 0 else {
            return "Serve counts must be whole numbers, and cannot be negative."
        }
        guard state.number(inSeason: resolved, playerId: entry.playerId) != nil else {
            return "Every player in a recorded game must be on that season\u{2019}s roster."
        }
    }
    return nil
}

private func setLineupRejection(_ state: AppState, playerIds: [String]) -> String? {
    guard let match = state.currentMatch else { return "No match is in progress." }
    guard playerIds.count == lineupSize else { return "A lineup needs exactly \(lineupSize) players." }
    guard Set(playerIds).count == lineupSize else { return "A player cannot hold two positions." }
    guard playerIds.allSatisfy({ state.rosterEntry(id: $0) != nil }) else {
        return "Every player in the lineup must be on the roster."
    }
    // Turns already played were served under the existing order; rewriting it would make
    // the record disagree with what happened. A change mid-match is a substitution.
    if match.turns.contains(where: { !$0.serves.isEmpty }) {
        return "The match has started. Substitute instead of changing the lineup."
    }
    return nil
}

private func substituteRejection(_ state: AppState, outPlayerId: String, inPlayerId: String) -> String? {
    guard let match = state.currentMatch else { return "No match is in progress." }
    guard let lineup = match.lineup else { return "This match has no lineup to substitute into." }
    if outPlayerId == inPlayerId { return "Choose a different player to come on." }
    guard lineup.contains(outPlayerId) else { return "That player is not on court." }
    guard state.rosterEntry(id: inPlayerId) != nil else { return "That player is not on the roster." }
    if lineup.contains(inPlayerId) { return "That player is already on court." }
    return nil
}

private func endMatchRejection(_ state: AppState, result: ResultField) -> String? {
    if state.currentMatch == nil { return "No match is in progress." }
    if result.isUnrecognised { return "Unrecognised match result." }
    return nil
}

/// What a correction is trying to change about a turn.
private enum TurnCorrection {
    case serves([String]?)
    case player(String)
    case delete
}

/// Corrections to a recorded turn: its serves, whose turn it was, or whether it happened.
///
/// They apply to any tracked game, including one long finished, because a correction fixes
/// the record of what happened rather than changing what was played. The rule that an ended
/// match is immutable protects the play from being rewritten mid-game; it was never meant to
/// make a typo permanent.
private func turnCorrectionRejection(
    _ state: AppState,
    gameId: String,
    matchIndex: Int,
    ordinal: Int,
    check: TurnCorrection
) -> String? {
    guard let game = state.game(id: gameId) else { return "That game no longer exists." }
    guard game.kind == .tracked else {
        return "That game was recorded from paper; edit its figures instead."
    }
    guard let match = game.matches.first(where: { $0.index == matchIndex }) else {
        return "That match is not part of this game."
    }
    guard match.turns.contains(where: { $0.ordinal == ordinal }) else {
        return "That serve turn no longer exists."
    }

    switch check {
    case let .serves(outcomes):
        guard let outcomes else { return "A turn needs a list of serves." }
        if outcomes.isEmpty { return "A turn with no serves should be deleted instead." }
        if outcomes.contains(where: { Outcome(rawValue: $0) == nil }) {
            return "Unrecognised serve outcome."
        }
    case let .player(playerId):
        if state.rosterEntry(id: playerId) == nil { return "That player is not on the roster." }
    case .delete:
        break
    }
    return nil
}

/// A missed turn can be added anywhere in the match, including before the first turn and
/// after the last. It is the one correction not made against an existing turn, so it
/// validates the place rather than the turn.
private func insertTurnRejection(
    _ state: AppState,
    gameId: String,
    matchIndex: Int,
    afterOrdinal: Int?,
    playerId: String
) -> String? {
    guard let game = state.game(id: gameId) else { return "That game no longer exists." }
    guard game.kind == .tracked else {
        return "That game was recorded from paper; edit its figures instead."
    }
    guard let match = game.matches.first(where: { $0.index == matchIndex }) else {
        return "That match is not part of this game."
    }
    guard state.rosterEntry(id: playerId) != nil else { return "That player is not on the roster." }
    guard let afterOrdinal, afterOrdinal >= -1, afterOrdinal < match.turns.count else {
        return "There is no such place in this match."
    }
    return nil
}

// MARK: - Shared

private func namePresence(_ value: String, of what: String) -> String? {
    value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "A \(what) name is required." : nil
}

/// The season an event belongs to: the one it names, else the active one, else the implicit
/// first season that is created for an operator who has not made one.
func seasonIdFor(_ state: AppState, _ seasonId: String?) -> String {
    seasonId ?? state.activeSeasonId ?? "season-1"
}

extension [String?] {
    /// True when the lineup holds this player. Slots can be empty after a roster removal.
    func contains(_ playerId: String) -> Bool {
        contains { $0 == playerId }
    }

    /// Where the player stands, or nil.
    func firstIndex(of playerId: String) -> Int? {
        firstIndex { $0 == playerId }
    }
}
