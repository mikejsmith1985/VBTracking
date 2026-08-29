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
  REMOVE_FROM_SEASON: 'REMOVE_FROM_SEASON',
  CREATE_SEASON: 'CREATE_SEASON',
  RENAME_SEASON: 'RENAME_SEASON',
  ACTIVATE_SEASON: 'ACTIVATE_SEASON',
  START_GAME: 'START_GAME',
  DISCARD_GAME: 'DISCARD_GAME',
  SET_GAME_CONTEXT: 'SET_GAME_CONTEXT',
  SET_GAME_NOTES: 'SET_GAME_NOTES',
  SET_MATCH_RESULT: 'SET_MATCH_RESULT',
  ADD_HISTORICAL_GAME: 'ADD_HISTORICAL_GAME',
  EDIT_HISTORICAL_GAME: 'EDIT_HISTORICAL_GAME',
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

/** How a match ended. Silence is not a defeat, so an unmarked match is undecided. */
export const MATCH_RESULT = Object.freeze({ WON: 'won', LOST: 'lost', UNDECIDED: 'undecided' })

/** How a game was recorded: serve by serve, or as figures copied from paper. */
export const GAME_KIND = Object.freeze({ TRACKED: 'tracked', HISTORICAL: 'historical' })

/**
 * The format a season is played under. Recorded with each season so a later release can
 * vary it without changing stored data. Not editable in this release.
 */
export const DEFAULT_FORMAT = Object.freeze({
  matchesPerGame: MATCHES_PER_GAME,
  targetScore: 21,
  playersOnCourt: LINEUP_SIZE,
})

/**
 * Records a player joining a season's roster: the person is created if new, and given the
 * number they wear THIS season. A number belongs to the membership, never to the person --
 * next season the same child may wear a different one for a different team.
 */
export function addPlayer(id, name, number, seasonId) {
  return { t: EVENT.ADD_PLAYER, id, name, number, seasonId }
}

/** Corrects a player's name (career-wide) and their number (this season only). */
export function editPlayer(id, name, number, seasonId) {
  return { t: EVENT.EDIT_PLAYER, id, name, number, seasonId }
}

/**
 * The destructive removal kept from releases 001 and 002: it discards the player's
 * recorded turns, as its confirmation warned. Retained only so replaying an older log
 * reproduces the figures it produced then; release 003 uses removeFromSeason instead.
 */
export function removePlayer(id, seasonId) {
  return { t: EVENT.REMOVE_PLAYER, id, seasonId }
}

/**
 * Records a player leaving a season's roster. The person continues to exist, and every
 * serve they recorded stays theirs -- leaving a team is not the same as never playing.
 */
export function removeFromSeason(playerId, seasonId) {
  return { t: EVENT.REMOVE_FROM_SEASON, playerId, seasonId }
}

/** Records a new season, for a named team, played under a given format. */
export function createSeason(id, name, team, format = DEFAULT_FORMAT) {
  return { t: EVENT.CREATE_SEASON, id, name, team, format: { ...format } }
}

/** Corrects a season's name or the team it is played for. */
export function renameSeason(id, name, team) {
  return { t: EVENT.RENAME_SEASON, id, name, team }
}

/** Records which season new games now belong to. */
export function activateSeason(id) {
  return { t: EVENT.ACTIVATE_SEASON, id }
}

/** Records the start of a new game within a season, which opens its first match. */
export function startGame(id, seasonId) {
  return { t: EVENT.START_GAME, id, seasonId }
}

/** Records who was played, where, on which court, and when. */
export function setGameContext(gameId, context) {
  return { t: EVENT.SET_GAME_CONTEXT, gameId, ...normaliseContext(context) }
}

/**
 * Corrects how one match of a tracked game turned out.
 *
 * A result is a record of what happened, not part of the play, so it stays editable after
 * the match has ended -- exactly as the opponent and the notes do. Without this the only
 * chance to say who won is the instant the match ends, and a match ended in a hurry could
 * never be put right.
 */
export function setMatchResult(gameId, matchIndex, result) {
  return { t: EVENT.SET_MATCH_RESULT, gameId, matchIndex, result }
}

/**
 * Records the three things a scoresheet actually carries: what went well, what to work on,
 * and anything else worth remembering.
 *
 * Every paper sheet keeps the first two as separate lists, which is a stronger statement of
 * how the record is used than one free-text box could be. `notes` is kept alongside them so
 * that remarks belonging to neither list -- and everything already written into it -- has
 * somewhere to live.
 */
export function setGameNotes(gameId, notes) {
  return { t: EVENT.SET_GAME_NOTES, gameId, ...normaliseNotes(notes) }
}

/** Accepts either the three-part shape or a plain string, which older events carry. */
export function normaliseNotes(notes) {
  if (typeof notes === 'string') return { wentWell: '', needsWork: '', notes }
  return {
    wentWell: notes?.wentWell ?? '',
    needsWork: notes?.needsWork ?? '',
    notes: notes?.notes ?? '',
  }
}

/**
 * Records a game that was never tracked serve by serve -- figures copied from paper.
 * Entries are per player, game level: serves in and serves out, and nothing else, because
 * nothing else was written down.
 */
export function addHistoricalGame(id, seasonId, context, entries, notes = '') {
  return {
    t: EVENT.ADD_HISTORICAL_GAME,
    id,
    seasonId,
    ...normaliseContext(context),
    entries: entries.map((entry) => ({ playerId: entry.playerId, in: entry.in, out: entry.out })),
    ...normaliseNotes(notes),
  }
}

/** Corrects a historical game's context, figures, or notes. */
export function editHistoricalGame(id, context, entries, notes) {
  return {
    t: EVENT.EDIT_HISTORICAL_GAME,
    id,
    ...normaliseContext(context),
    entries: entries.map((entry) => ({ playerId: entry.playerId, in: entry.in, out: entry.out })),
    ...normaliseNotes(notes),
  }
}

function normaliseContext(context = {}) {
  return {
    date: context.date ?? null,
    opponent: context.opponent ?? '',
    location: context.location ?? '',
    court: context.court ?? '',
  }
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

/**
 * Records that the operator declared the current match finished, and how it went.
 * The opponent's score is still not tracked, so the app cannot know -- one tap does.
 */
export function endMatch(result = MATCH_RESULT.UNDECIDED) {
  return { t: EVENT.END_MATCH, result }
}

/** True when the value is a result the app recognises. */
export function isValidResult(result) {
  return Object.values(MATCH_RESULT).includes(result)
}

/** True when the outcome is one the app recognises. */
export function isValidOutcome(outcome) {
  return Object.values(OUTCOME).includes(outcome)
}

/** True when the serve landed in, whether or not it won the rally. */
export function isServeIn(serve) {
  return serve.outcome === OUTCOME.IN_POINT || serve.outcome === OUTCOME.IN_NO_POINT
}
