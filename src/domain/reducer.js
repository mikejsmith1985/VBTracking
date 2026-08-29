// The rulebook. Every rule in the specification lives here and nowhere else.
// Pure: no DOM, no storage, no clock, no randomness. State is never mutated in place,
// because undo works by replaying the event log from empty.
import { EVENT, OUTCOME, MAX_ROSTER, MATCHES_PER_GAME, LINEUP_SIZE, isValidOutcome } from './events.js'
import { colorIndexForTurn } from './palette.js'

/** The state of an application that has recorded nothing. */
export function emptyState() {
  return { roster: [], games: [], currentGameId: null }
}

/** Rebuilds derived state from an event log. Deterministic for a given log. */
export function replay(events) {
  return events.reduce(applyEvent, emptyState())
}

/**
 * Applies one event, returning new state. A rejected event returns the state it was
 * given, unchanged, so that a corrupt stored log can never crash startup.
 */
export function applyEvent(state, event) {
  if (rejectionReason(state, event)) return state

  switch (event.t) {
    case EVENT.ADD_PLAYER: return withPlayerAdded(state, event)
    case EVENT.EDIT_PLAYER: return withPlayerEdited(state, event)
    case EVENT.REMOVE_PLAYER: return withPlayerRemoved(state, event)
    case EVENT.START_GAME: return withGameStarted(state, event)
    case EVENT.DISCARD_GAME: return withGameDiscarded(state, event)
    case EVENT.SET_LINEUP: return withLineupSet(state, event)
    case EVENT.CLEAR_LINEUP: return withLineupCleared(state)
    case EVENT.SUBSTITUTE: return withSubstitution(state, event)
    case EVENT.SELECT_SERVER: return withServerSelected(state, event)
    case EVENT.RECORD_SERVE: return withServeRecorded(state, event)
    case EVENT.END_MATCH: return withMatchEnded(state)
    default: return state
  }
}

/** True when the event would be accepted against the state given. */
export function isEventValid(state, event) {
  return rejectionReason(state, event) === null
}

/** Why the event would be refused, or null when it would be accepted. */
export function rejectionReason(state, event) {
  if (!event || typeof event.t !== 'string') return 'Unrecognised event.'

  switch (event.t) {
    case EVENT.ADD_PLAYER: return addPlayerRejection(state, event)
    case EVENT.EDIT_PLAYER: return editPlayerRejection(state, event)
    case EVENT.REMOVE_PLAYER: return findPlayer(state, event.id) ? null : 'That player is not on the roster.'
    case EVENT.START_GAME: return startGameRejection(state, event)
    case EVENT.DISCARD_GAME:
      return state.games.some((game) => game.id === event.id) ? null : 'That game no longer exists.'
    case EVENT.SET_LINEUP: return setLineupRejection(state, event)
    case EVENT.CLEAR_LINEUP: return currentMatch(state) ? null : 'No match is in progress.'
    case EVENT.SUBSTITUTE: return substituteRejection(state, event)
    case EVENT.SELECT_SERVER: return selectServerRejection(state, event)
    case EVENT.RECORD_SERVE: return recordServeRejection(state, event)
    case EVENT.END_MATCH: return currentMatch(state) ? null : 'No match is in progress.'
    default: return 'Unrecognised event.'
  }
}

// --- Readers -----------------------------------------------------------------

/** The game currently being played, or null. */
export function currentGame(state) {
  if (!state.currentGameId) return null
  return state.games.find((game) => game.id === state.currentGameId) ?? null
}

/** The match currently in progress within the current game, or null. */
export function currentMatch(state) {
  const game = currentGame(state)
  if (!game) return null
  return game.matches.find((match) => match.status === 'in_progress') ?? null
}

/** The serve turn accepting serves right now, or null when the team is between servers. */
export function openTurn(match) {
  if (!match) return null
  return match.turns.find((turn) => turn.isOpen) ?? null
}

/** The player with the given id, or null. */
export function findPlayer(state, playerId) {
  return state.roster.find((player) => player.id === playerId) ?? null
}

/** True when the current game has played all three of its matches. */
export function isGameComplete(state) {
  const game = currentGame(state)
  if (!game) return false
  return game.matches.length === MATCHES_PER_GAME && game.matches.every((match) => match.status === 'ended')
}

/** The six on court for the match in progress, as it stands now, or null. */
export function currentLineup(state) {
  return currentMatch(state)?.lineup ?? null
}

/** Where a player stands in a match's serving order, or null when they are not in it. */
export function lineupPositionOf(match, playerId) {
  if (!match?.lineup) return null
  const position = match.lineup.indexOf(playerId)
  return position === -1 ? null : position
}

/**
 * The lineup position due to serve next: one past the most recent turn that occupied a
 * position. An off-lineup turn occupies the position that was due (see `newTurn`), so it
 * counts here too -- which is what stops the order lagging by one after an unrecorded
 * substitution.
 */
export function nextRotationPosition(match) {
  if (!match?.lineup) return null
  const last = lastKnownPosition(match.turns)
  if (last === null) return null
  return (last + 1) % LINEUP_SIZE
}

/** Who the rotation says serves next, or null when it cannot say. */
export function nextRotationPlayerId(match) {
  const position = nextRotationPosition(match)
  if (position === null) return null
  return match.lineup[position] ?? null
}

// --- Validation --------------------------------------------------------------

function addPlayerRejection(state, event) {
  if (state.roster.length >= MAX_ROSTER) return `The roster is full — ${MAX_ROSTER} players maximum.`
  if (!isPresent(event.name)) return 'A player name is required.'
  if (findPlayer(state, event.id)) return 'That player is already on the roster.'
  return null
}

function editPlayerRejection(state, event) {
  if (!findPlayer(state, event.id)) return 'That player is not on the roster.'
  if (!isPresent(event.name)) return 'A player name is required.'
  return null
}

function startGameRejection(state, event) {
  if (state.games.some((game) => game.id === event.id)) return 'That game already exists.'
  if (currentMatch(state)) return 'Finish the current game before starting another.'
  return null
}

function setLineupRejection(state, event) {
  const match = currentMatch(state)
  if (!match) return 'No match is in progress.'
  if (!Array.isArray(event.playerIds) || event.playerIds.length !== LINEUP_SIZE) {
    return `A lineup needs exactly ${LINEUP_SIZE} players.`
  }
  if (new Set(event.playerIds).size !== LINEUP_SIZE) return 'A player cannot hold two positions.'
  if (event.playerIds.some((playerId) => !findPlayer(state, playerId))) {
    return 'Every player in the lineup must be on the roster.'
  }
  // Turns already played were served under the existing order; rewriting it would make
  // the record disagree with what happened. A change mid-match is a substitution.
  if (hasRecordedServe(match)) return 'The match has started. Substitute instead of changing the lineup.'
  return null
}

function substituteRejection(state, event) {
  const match = currentMatch(state)
  if (!match) return 'No match is in progress.'
  if (!match.lineup) return 'This match has no lineup to substitute into.'
  if (event.outPlayerId === event.inPlayerId) return 'Choose a different player to come on.'
  if (!match.lineup.includes(event.outPlayerId)) return 'That player is not on court.'
  if (!findPlayer(state, event.inPlayerId)) return 'That player is not on the roster.'
  if (match.lineup.includes(event.inPlayerId)) return 'That player is already on court.'
  return null
}

function selectServerRejection(state, event) {
  if (!currentMatch(state)) return 'No match is in progress.'
  if (!findPlayer(state, event.playerId)) return 'That player is not on the roster.'
  return null
}

function recordServeRejection(state, event) {
  if (!isValidOutcome(event.outcome)) return 'Unrecognised serve outcome.'
  if (!openTurn(currentMatch(state))) return 'Select the server first.'
  return null
}

function isPresent(value) {
  return typeof value === 'string' && value.trim().length > 0
}

function hasRecordedServe(match) {
  return match.turns.some((turn) => turn.serves.length > 0)
}

// --- Roster transitions ------------------------------------------------------

function withPlayerAdded(state, event) {
  const player = { id: event.id, name: event.name.trim(), number: String(event.number ?? '').trim() }
  return { ...state, roster: [...state.roster, player] }
}

function withPlayerEdited(state, event) {
  const roster = state.roster.map((player) =>
    player.id === event.id
      ? { ...player, name: event.name.trim(), number: String(event.number ?? '').trim() }
      : player,
  )
  return { ...state, roster }
}

// Removing a player discards their recorded turns, as the deletion confirmation warns.
// Remaining turns are renumbered so ordinals -- and therefore colours -- stay contiguous.
// A lineup slot they held is emptied rather than silently refilled with someone else.
function withPlayerRemoved(state, event) {
  const games = state.games.map((game) => ({
    ...game,
    matches: game.matches.map((match) => ({
      ...match,
      lineup: match.lineup
        ? match.lineup.map((playerId) => (playerId === event.id ? null : playerId))
        : null,
      turns: renumber(match.turns.filter((turn) => turn.playerId !== event.id)),
    })),
  }))
  return { ...state, roster: state.roster.filter((player) => player.id !== event.id), games }
}

// --- Game and match transitions ----------------------------------------------

function withGameStarted(state, event) {
  const game = { id: event.id, matches: [newMatch(0)] }
  return { ...state, games: [...state.games, game], currentGameId: event.id }
}

function withGameDiscarded(state, event) {
  const games = state.games.filter((game) => game.id !== event.id)
  const currentGameId = state.currentGameId === event.id ? null : state.currentGameId
  return { ...state, games, currentGameId }
}

function withMatchEnded(state) {
  const game = currentGame(state)
  const ending = currentMatch(state)
  const ended = { ...ending, status: 'ended', turns: closeOpenTurn(ending.turns) }

  const matches = game.matches.map((match) => (match.index === ended.index ? ended : match))
  // The next match starts from this one's lineup: with nine on a roster the six on court
  // are usually close, and editing beats rebuilding.
  if (ended.index < MATCHES_PER_GAME - 1) matches.push(newMatch(ended.index + 1, ended.lineup))

  return { ...state, games: state.games.map((each) => (each.id === game.id ? { ...game, matches } : each)) }
}

// --- Lineup transitions ------------------------------------------------------

function withLineupSet(state, event) {
  return updateCurrentMatch(state, (match) => ({ ...match, lineup: [...event.playerIds] }))
}

function withLineupCleared(state) {
  return updateCurrentMatch(state, (match) => ({ ...match, lineup: null }))
}

function withSubstitution(state, event) {
  return updateCurrentMatch(state, (match) => {
    const position = match.lineup.indexOf(event.outPlayerId)
    const lineup = match.lineup.map((playerId, index) => (index === position ? event.inPlayerId : playerId))
    const substitutions = [...match.substitutions, {
      outPlayerId: event.outPlayerId,
      inPlayerId: event.inPlayerId,
      position,
      afterTurnOrdinal: playedTurnCount(match) - 1,
    }]

    const open = openTurn(match)
    if (!open || open.playerId !== event.outPlayerId) {
      return { ...match, lineup, substitutions }
    }

    // The outgoing player was serving. Their turn is closed with the serves they actually
    // took -- reassigning those to the incoming player would credit serves never made --
    // and a fresh turn opens for whoever came on, at the same position.
    const turns = closeOpenTurn(match.turns)
    return { ...match, lineup, substitutions, turns: [...turns, newTurn(event.inPlayerId, turns.length, lineup)] }
  })
}

// --- Serve transitions -------------------------------------------------------

function withServerSelected(state, event) {
  return updateCurrentMatch(state, (match) => {
    const pending = pendingPositionFor(match)
    const turns = closeOpenTurn(match.turns)
    return { ...match, turns: [...turns, newTurn(event.playerId, turns.length, match.lineup, pending)] }
  })
}

function withServeRecorded(state, event) {
  return updateCurrentMatch(state, (match) => {
    const turns = match.turns.map((turn) =>
      turn.isOpen
        ? { ...turn, serves: [...turn.serves, { outcome: event.outcome }], isOpen: event.outcome === OUTCOME.IN_POINT }
        : turn,
    )
    return advanceRotation({ ...match, turns })
  })
}

/**
 * Hands the serve to the next player in the order when a turn has just closed.
 *
 * This happens inside the RECORD_SERVE transition rather than as an event of its own, and
 * that is the whole trick: popping the serve removes the advance along with it, so one
 * undo reverses one operator action. An event would make undo take two taps to reverse
 * one tap, and a UI-triggered dispatch would not survive a replay.
 */
function advanceRotation(match) {
  if (!match.lineup) return match
  if (openTurn(match)) return match

  const position = nextRotationPosition(match)
  if (position === null) return match

  const playerId = match.lineup[position]
  if (!playerId) return match // the slot was emptied by a roster removal

  return { ...match, turns: [...match.turns, newTurn(playerId, match.turns.length, match.lineup)] }
}

// --- Turn helpers ------------------------------------------------------------

function newMatch(index, lineup = null) {
  return { index, status: 'in_progress', lineup: lineup ? [...lineup] : null, substitutions: [], turns: [] }
}

/**
 * A turn records the position it was served from and who was on court at the time.
 * The position drives the rotation -- positions are stable, occupants are not -- while the
 * snapshot answers who was on court then, which is what turns-on-court counts.
 *
 * A server who is not in the lineup still occupies the position that was due. Tapping
 * someone off-lineup nearly always means a substitution happened on court and has not been
 * entered yet, so that player is standing in the slot the rotation just reached: the turn
 * consumes the position, and `isOffLineup` marks it for the operator to reconcile. Leaving
 * the position unconsumed would make the whole order lag by one for the rest of the match.
 */
function newTurn(playerId, ordinal, lineup, pendingPosition = null) {
  if (!lineup) {
    return baseTurn(playerId, ordinal, { lineupPosition: null, isOffLineup: false, lineupSnapshot: null })
  }

  const inLineup = lineup.indexOf(playerId)
  return baseTurn(playerId, ordinal, {
    lineupPosition: inLineup === -1 ? pendingPosition : inLineup,
    isOffLineup: inLineup === -1,
    lineupSnapshot: [...lineup],
  })
}

function baseTurn(playerId, ordinal, lineupFields) {
  return {
    playerId,
    ordinal,
    colorIndex: colorIndexForTurn(ordinal),
    ...lineupFields,
    serves: [],
    isOpen: true,
  }
}

/**
 * The rotation position a newly chosen server takes over. When the rotation has already
 * opened a turn, that turn's position is the one being replaced -- not the one after it.
 */
function pendingPositionFor(match) {
  const open = openTurn(match)
  if (open && open.lineupPosition !== null && open.lineupPosition !== undefined) return open.lineupPosition
  return nextRotationPosition(match)
}

/** Closes the open turn, discarding it entirely when it recorded no serves. */
function closeOpenTurn(turns) {
  return turns
    .filter((turn) => !(turn.isOpen && turn.serves.length === 0))
    .map((turn) => (turn.isOpen ? { ...turn, isOpen: false } : turn))
}

function renumber(turns) {
  return turns.map((turn, index) => ({ ...turn, ordinal: index, colorIndex: colorIndexForTurn(index) }))
}

function lastKnownPosition(turns) {
  for (let index = turns.length - 1; index >= 0; index -= 1) {
    const position = turns[index].lineupPosition
    if (position !== null && position !== undefined) return position
  }
  return null
}

function playedTurnCount(match) {
  return match.turns.filter((turn) => turn.serves.length > 0).length
}

function updateCurrentMatch(state, transform) {
  return {
    ...state,
    games: state.games.map((game) =>
      game.id !== state.currentGameId
        ? game
        : { ...game, matches: game.matches.map((match) => (match.status === 'in_progress' ? transform(match) : match)) },
    ),
  }
}
