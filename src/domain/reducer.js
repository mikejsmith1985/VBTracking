// The rulebook. Every rule in the specification lives here and nowhere else.
// Pure: no DOM, no storage, no clock, no randomness. State is never mutated in place,
// because undo works by replaying the event log from empty.
import { EVENT, OUTCOME, MAX_ROSTER, MATCHES_PER_GAME, isValidOutcome } from './events.js'
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

// --- Transitions -------------------------------------------------------------

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
function withPlayerRemoved(state, event) {
  const games = state.games.map((game) => ({
    ...game,
    matches: game.matches.map((match) => ({
      ...match,
      turns: renumber(match.turns.filter((turn) => turn.playerId !== event.id)),
    })),
  }))
  return { ...state, roster: state.roster.filter((player) => player.id !== event.id), games }
}

function withGameStarted(state, event) {
  const game = { id: event.id, matches: [newMatch(0)] }
  return { ...state, games: [...state.games, game], currentGameId: event.id }
}

function withServerSelected(state, event) {
  return updateCurrentMatch(state, (match) => {
    const turns = closeOpenTurn(match.turns)
    return { ...match, turns: [...turns, newTurn(event.playerId, turns.length)] }
  })
}

function withServeRecorded(state, event) {
  return updateCurrentMatch(state, (match) => ({
    ...match,
    turns: match.turns.map((turn) =>
      turn.isOpen
        ? { ...turn, serves: [...turn.serves, { outcome: event.outcome }], isOpen: event.outcome === OUTCOME.IN_POINT }
        : turn,
    ),
  }))
}

function withMatchEnded(state) {
  const game = currentGame(state)
  const ending = currentMatch(state)
  const ended = { ...ending, status: 'ended', turns: closeOpenTurn(ending.turns) }

  const matches = game.matches.map((match) => (match.index === ended.index ? ended : match))
  if (ended.index < MATCHES_PER_GAME - 1) matches.push(newMatch(ended.index + 1))

  return { ...state, games: state.games.map((each) => (each.id === game.id ? { ...game, matches } : each)) }
}

// --- Turn helpers ------------------------------------------------------------

function newMatch(index) {
  return { index, status: 'in_progress', turns: [] }
}

function newTurn(playerId, ordinal) {
  return { playerId, ordinal, colorIndex: colorIndexForTurn(ordinal), serves: [], isOpen: true }
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
