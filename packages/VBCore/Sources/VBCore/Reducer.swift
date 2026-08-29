// The rulebook. Every rule in the specification lives here and nowhere else.
//
// Pure: no storage, no clock, no randomness, no interface. State is never mutated in
// place, because undo works by replaying the log from empty — so a state that could be
// changed after the fact would make undo a lie.
//
// This is a port of `src/domain/reducer.js` from the shipped web app, and it is not
// trusted because it reads correctly. It is trusted because `ParityTests` replays real
// logs through both and gets the same figures.
import Foundation

/// The season created for an operator who has not made one. Renameable afterwards.
private let implicitSeason = (id: "season-1", name: "Season 1", team: "My Team")

/// Rebuilds derived state from an event log. Deterministic for a given log.
public func replay(_ events: [Event]) -> State {
    events.reduce(State()) { applyEvent($0, $1) }
}

/// Rebuilds derived state from a log as it sits on disk.
public func replay(raw events: [RawEvent]) -> State {
    replay(events.compactMap(Event.init(raw:)))
}

/// Applies one event, returning new state.
///
/// A rejected event returns the state it was given, unchanged, so that a corrupt stored log
/// can never stop the app from starting.
public func applyEvent(_ state: State, _ event: Event) -> State {
    if rejectionReason(state, event) != nil { return state }
    let next = transition(state, event)
    if next == state { return state }
    return withActiveRoster(next)
}

/// True when the event would be accepted against the state given.
public func isEventValid(_ state: State, _ event: Event) -> Bool {
    rejectionReason(state, event) == nil
}

// MARK: - Transitions

private func transition(_ state: State, _ event: Event) -> State {
    switch event.kind {
    case let .createSeason(id, name, team, format):
        return withSeasonCreated(state, id: id, name: name, team: team, format: format)

    case let .renameSeason(id, name, team):
        return withSeasonRenamed(state, id: id, name: name, team: team)

    case let .activateSeason(id):
        var next = state
        next.activeSeasonId = id
        return next

    case let .addPlayer(id, name, number, seasonId):
        return withPlayerAdded(state, id: id, name: name, number: number, seasonId: seasonId)

    case let .editPlayer(id, name, number, seasonId):
        return withPlayerEdited(state, id: id, name: name, number: number, seasonId: seasonId)

    case let .removePlayer(id, seasonId):
        return withPlayerRemoved(state, id: id, seasonId: seasonId)

    case let .removeFromSeason(playerId, seasonId):
        return withMembershipRemoved(state, playerId: playerId, seasonId: seasonId)

    case let .startGame(id, seasonId, rotatesAtServeLimit):
        return withGameStarted(state, id: id, seasonId: seasonId, rotatesAtServeLimit: rotatesAtServeLimit)

    case let .discardGame(id):
        return withGameDiscarded(state, id: id)

    case let .setGameContext(gameId, context):
        return mapGame(state, gameId) { game in
            var next = game
            next.context = context
            return next
        }

    case let .setGameNotes(gameId, notes):
        return mapGame(state, gameId) { game in
            var next = game
            next.notes = notes
            return next
        }

    case let .setMatchResult(gameId, matchIndex, result):
        return mapMatch(state, gameId: gameId, matchIndex: matchIndex) { match in
            var next = match
            next.result = result.recorded
            return next
        }

    case let .addHistoricalGame(id, seasonId, context, entries, notes, result):
        return withHistoricalGameAdded(
            state, id: id, seasonId: seasonId, context: context,
            entries: entries ?? [], notes: notes, result: result
        )

    case let .editHistoricalGame(id, context, entries, notes, result):
        return withHistoricalGameEdited(
            state, id: id, context: context, entries: entries ?? [], notes: notes, result: result
        )

    case let .setLineup(playerIds):
        return updateCurrentMatch(state) { match, _ in
            var next = match
            next.lineup = playerIds.map { Optional($0) }
            return next
        }

    case .clearLineup:
        return updateCurrentMatch(state) { match, _ in
            var next = match
            next.lineup = nil
            return next
        }

    case let .substitute(outPlayerId, inPlayerId):
        return withSubstitution(state, outPlayerId: outPlayerId, inPlayerId: inPlayerId)

    case let .selectServer(playerId):
        return withServerSelected(state, playerId: playerId)

    case let .recordServe(outcome):
        guard let outcome else { return state }
        return withServeRecorded(state, outcome: outcome)

    case let .endMatch(result):
        return withMatchEnded(state, result: result.recorded)

    case let .endGame(result):
        return withGameEnded(state, result: result.recorded)

    case let .setTurnServes(gameId, matchIndex, ordinal, outcomes):
        return withTurnServesSet(state, gameId: gameId, matchIndex: matchIndex, ordinal: ordinal, outcomes: outcomes ?? [])

    case let .reassignTurn(gameId, matchIndex, ordinal, playerId):
        return withTurnReassigned(state, gameId: gameId, matchIndex: matchIndex, ordinal: ordinal, playerId: playerId)

    case let .deleteTurn(gameId, matchIndex, ordinal):
        return mapMatch(state, gameId: gameId, matchIndex: matchIndex) { match in
            var next = match
            next.turns = renumber(match.turns.filter { $0.ordinal != ordinal })
            return next
        }

    case let .insertTurn(gameId, matchIndex, afterOrdinal, playerId):
        guard let afterOrdinal else { return state }
        return withTurnInserted(
            state, gameId: gameId, matchIndex: matchIndex, afterOrdinal: afterOrdinal, playerId: playerId
        )

    case .unrecognised:
        return state
    }
}
