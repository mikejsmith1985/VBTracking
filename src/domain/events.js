// Constructors and constants for the append-only event log. Events are plain,
// JSON-serializable objects: an event's meaning comes from its position in the log,
// never from ambient state read at the time it was built.

/** The three outcomes a serve can have. Nothing else is a valid outcome. */
export const OUTCOME = Object.freeze({
  OUT: 'OUT',
  IN_NO_POINT: 'IN_NO_POINT',
  IN_POINT: 'IN_POINT',
})

/** Every event type the reducer understands. */
export const EVENT = Object.freeze({
  ADD_PLAYER: 'ADD_PLAYER',
  EDIT_PLAYER: 'EDIT_PLAYER',
  REMOVE_PLAYER: 'REMOVE_PLAYER',
  START_GAME: 'START_GAME',
  DISCARD_GAME: 'DISCARD_GAME',
  SET_LINEUP: 'SET_LINEUP',
  CLEAR_LINEUP: 'CLEAR_LINEUP',
  SUBSTITUTE: 'SUBSTITUTE',
  SELECT_SERVER: 'SELECT_SERVER',
  RECORD_SERVE: 'RECORD_SERVE',
  END_MATCH: 'END_MATCH',
})

/** A roster may never hold more than this many players. */
export const MAX_ROSTER = 20

/** A game is exactly this many matches. */
export const MATCHES_PER_GAME = 3

/** Players on court, and therefore positions in the serving order. */
export const LINEUP_SIZE = 6

/** Records that a player joined the roster. */
export function addPlayer(id, name, number) {
  return { t: EVENT.ADD_PLAYER, id, name, number }
}

/** Records a correction to a player's name or jersey number. The id never changes. */
export function editPlayer(id, name, number) {
  return { t: EVENT.EDIT_PLAYER, id, name, number }
}

/** Records that a player left the roster, discarding their recorded turns. */
export function removePlayer(id) {
  return { t: EVENT.REMOVE_PLAYER, id }
}

/** Records the start of a new game, which opens its first match. */
export function startGame(id) {
  return { t: EVENT.START_GAME, id }
}

/** Records that a game and everything recorded in it was deliberately thrown away. */
export function discardGame(id) {
  return { t: EVENT.DISCARD_GAME, id }
}

/** Records the six players on court for the current match, in serving order. */
export function setLineup(playerIds) {
  return { t: EVENT.SET_LINEUP, playerIds }
}

/** Records that the current match reverts to picking each server by hand. */
export function clearLineup() {
  return { t: EVENT.CLEAR_LINEUP }
}

/** Records one player replacing another at that player's position in the serving order. */
export function substitute(outPlayerId, inPlayerId) {
  return { t: EVENT.SUBSTITUTE, outPlayerId, inPlayerId }
}

/** Records that a player has taken the serving position, opening a new turn. */
export function selectServer(playerId) {
  return { t: EVENT.SELECT_SERVER, playerId }
}

/** Records one serve for the currently open turn. */
export function recordServe(outcome) {
  return { t: EVENT.RECORD_SERVE, outcome }
}

/** Records the operator declaring the current match finished. */
export function endMatch() {
  return { t: EVENT.END_MATCH }
}

/** True when the outcome is one the app recognises. */
export function isValidOutcome(outcome) {
  return Object.values(OUTCOME).includes(outcome)
}

/** True when the serve landed in, whether or not it won the rally. */
export function isServeIn(serve) {
  return serve.outcome === OUTCOME.IN_POINT || serve.outcome === OUTCOME.IN_NO_POINT
}
