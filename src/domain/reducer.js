// The rulebook. Every rule in the specification lives here and nowhere else.
// Pure: no DOM, no storage, no clock, no randomness. State is never mutated in place,
// because undo works by replaying the event log from empty.
import {
  EVENT, OUTCOME, MAX_ROSTER, MATCHES_PER_GAME, LINEUP_SIZE,
  MATCH_RESULT, GAME_KIND, DEFAULT_FORMAT, SERVE_LIMIT, isValidOutcome, isValidResult,
} from './events.js'
import { colorIndexForTurn } from './palette.js'

/** The season created for an operator who has not made one. Renameable afterwards. */
const IMPLICIT_SEASON = { id: 'season-1', name: 'Season 1', team: 'My Team' }

/** The state of an application that has recorded nothing. */
export function emptyState() {
  return { players: [], seasons: [], activeSeasonId: null, games: [], currentGameId: null, roster: [] }
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
  const next = transition(state, event)
  return next === state ? state : withActiveRoster(next)
}

function transition(state, event) {
  switch (event.t) {
    case EVENT.CREATE_SEASON: return withSeasonCreated(state, event)
    case EVENT.RENAME_SEASON: return withSeasonRenamed(state, event)
    case EVENT.ACTIVATE_SEASON: return { ...state, activeSeasonId: event.id }
    case EVENT.ADD_PLAYER: return withPlayerAdded(state, event)
    case EVENT.EDIT_PLAYER: return withPlayerEdited(state, event)
    case EVENT.REMOVE_PLAYER: return withPlayerRemoved(state, event)
    case EVENT.REMOVE_FROM_SEASON: return withMembershipRemoved(state, event)
    case EVENT.START_GAME: return withGameStarted(state, event)
    case EVENT.DISCARD_GAME: return withGameDiscarded(state, event)
    case EVENT.SET_GAME_CONTEXT: return withGameContext(state, event)
    case EVENT.SET_GAME_NOTES: return withGameNotes(state, event)
    case EVENT.SET_MATCH_RESULT: return withMatchResultSet(state, event)
    case EVENT.SET_TURN_SERVES: return withTurnServesSet(state, event)
    case EVENT.REASSIGN_TURN: return withTurnReassigned(state, event)
    case EVENT.DELETE_TURN: return withTurnDeleted(state, event)
    case EVENT.ADD_HISTORICAL_GAME: return withHistoricalGameAdded(state, event)
    case EVENT.EDIT_HISTORICAL_GAME: return withHistoricalGameEdited(state, event)
    case EVENT.SET_LINEUP: return withLineupSet(state, event)
    case EVENT.CLEAR_LINEUP: return withLineupCleared(state)
    case EVENT.SUBSTITUTE: return withSubstitution(state, event)
    case EVENT.SELECT_SERVER: return withServerSelected(state, event)
    case EVENT.RECORD_SERVE: return withServeRecorded(state, event)
    case EVENT.END_MATCH: return withMatchEnded(state, event)
    case EVENT.END_GAME: return withGameEnded(state, event)
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
    case EVENT.CREATE_SEASON: return createSeasonRejection(state, event)
    case EVENT.RENAME_SEASON:
      return seasonById(state, event.id) ? namePresence(event.name, 'season') : 'That season does not exist.'
    case EVENT.ACTIVATE_SEASON: return activateSeasonRejection(state, event)
    case EVENT.ADD_PLAYER: return addPlayerRejection(state, event)
    case EVENT.EDIT_PLAYER: return editPlayerRejection(state, event)
    case EVENT.REMOVE_PLAYER: return findPlayer(state, event.id) ? null : 'That player is not on the roster.'
    case EVENT.REMOVE_FROM_SEASON: return removeFromSeasonRejection(state, event)
    case EVENT.START_GAME: return startGameRejection(state, event)
    case EVENT.DISCARD_GAME:
      return state.games.some((game) => game.id === event.id) ? null : 'That game no longer exists.'
    case EVENT.SET_GAME_CONTEXT:
    case EVENT.SET_GAME_NOTES:
      return gameById(state, event.gameId) ? null : 'That game no longer exists.'
    case EVENT.SET_MATCH_RESULT: return setMatchResultRejection(state, event)
    case EVENT.SET_TURN_SERVES: return turnCorrectionRejection(state, event, 'serves')
    case EVENT.REASSIGN_TURN: return turnCorrectionRejection(state, event, 'player')
    case EVENT.DELETE_TURN: return turnCorrectionRejection(state, event, 'delete')
    case EVENT.ADD_HISTORICAL_GAME: return historicalGameRejection(state, event, true)
    case EVENT.EDIT_HISTORICAL_GAME: return historicalGameRejection(state, event, false)
    case EVENT.SET_LINEUP: return setLineupRejection(state, event)
    case EVENT.CLEAR_LINEUP: return currentMatch(state) ? null : 'No match is in progress.'
    case EVENT.SUBSTITUTE: return substituteRejection(state, event)
    case EVENT.SELECT_SERVER: return selectServerRejection(state, event)
    case EVENT.RECORD_SERVE: return recordServeRejection(state, event)
    case EVENT.END_MATCH: return endMatchRejection(state, event)
    case EVENT.END_GAME: return endMatchRejection(state, event)
    default: return 'Unrecognised event.'
  }
}

// --- Readers -----------------------------------------------------------------

/** The season new games belong to, or null. */
export function activeSeason(state) {
  return seasonById(state, state.activeSeasonId)
}

/** A season by id, or null. */
export function seasonById(state, seasonId) {
  return state.seasons.find((season) => season.id === seasonId) ?? null
}

/** A season's roster: player id, name, and the number worn THAT season. */
export function seasonMembers(state, seasonId) {
  const season = seasonById(state, seasonId)
  if (!season) return []
  return season.members
    .map((member) => {
      const player = playerById(state, member.playerId)
      return player ? { id: player.id, name: player.name, number: member.number } : null
    })
    .filter(Boolean)
}

/** The number a player wore in a given season, or null. A number never lives on a person. */
export function numberFor(state, seasonId, playerId) {
  const season = seasonById(state, seasonId)
  return season?.members.find((member) => member.playerId === playerId)?.number ?? null
}

/** A career player by id, or null. */
export function playerById(state, playerId) {
  return state.players.find((player) => player.id === playerId) ?? null
}

/** Every game recorded in a season. */
export function gamesInSeason(state, seasonId) {
  return state.games.filter((game) => game.seasonId === seasonId)
}

/** Every game a player appears in, across every season. */
export function gamesForPlayer(state, playerId) {
  return state.games.filter((game) => gameInvolves(game, playerId))
}

/** Every season a player has been a member of. */
export function seasonsForPlayer(state, playerId) {
  return state.seasons.filter((season) => season.members.some((member) => member.playerId === playerId))
}

/** A game by id, or null. */
export function gameById(state, gameId) {
  return state.games.find((game) => game.id === gameId) ?? null
}

/** The game currently being played, or null. */
export function currentGame(state) {
  return gameById(state, state.currentGameId)
}

/** The match in progress within the current game, or null. Historical games have none. */
export function currentMatch(state) {
  const game = currentGame(state)
  if (!game || game.kind !== GAME_KIND.TRACKED) return null
  return game.matches.find((match) => match.status === 'in_progress') ?? null
}

/** The serve turn accepting serves right now, or null when the team is between servers. */
export function openTurn(match) {
  if (!match) return null
  return match.turns.find((turn) => turn.isOpen) ?? null
}

/** A player on the ACTIVE season's roster, or null. Carries that season's number. */
export function findPlayer(state, playerId) {
  return state.roster.find((player) => player.id === playerId) ?? null
}

/**
 * True when the current game is over: every match it holds has ended.
 *
 * Not "three matches have ended" -- a game stopped early has fewer, and it is still over.
 */
export function isGameComplete(state) {
  const game = currentGame(state)
  if (!game || game.kind !== GAME_KIND.TRACKED) return false
  return game.matches.length > 0 && game.matches.every((match) => match.status === 'ended')
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

function createSeasonRejection(state, event) {
  if (seasonById(state, event.id)) return 'That season already exists.'
  return namePresence(event.name, 'season')
}

function activateSeasonRejection(state, event) {
  if (!seasonById(state, event.id)) return 'That season does not exist.'
  // Ending one match of three opens the next, so "end the match" would be misleading
  // advice: the game is what has to finish.
  if (currentMatch(state)) return 'Finish or discard the game in progress before switching seasons.'
  return null
}

function addPlayerRejection(state, event) {
  const seasonId = seasonIdFor(state, event)
  const season = seasonById(state, seasonId)
  if (season) {
    if (season.members.length >= MAX_ROSTER) return `The roster is full — ${MAX_ROSTER} players maximum.`
    if (season.members.some((member) => member.playerId === event.id)) {
      return 'That player is already on this season’s roster.'
    }
  }
  return namePresence(event.name, 'player')
}

function editPlayerRejection(state, event) {
  if (!playerById(state, event.id)) return 'That player does not exist.'
  return namePresence(event.name, 'player')
}

function removeFromSeasonRejection(state, event) {
  const seasonId = seasonIdFor(state, event)
  if (!seasonById(state, seasonId)) return 'That season does not exist.'
  if (numberFor(state, seasonId, event.playerId) === null) return 'That player is not on this roster.'
  return null
}

function startGameRejection(state, event) {
  if (state.games.some((game) => game.id === event.id)) return 'That game already exists.'
  if (currentMatch(state)) return 'Finish the current game before starting another.'
  return null
}

function historicalGameRejection(state, event, isNew) {
  const existing = gameById(state, event.id)
  if (isNew && existing) return 'That game already exists.'
  if (!isNew && !existing) return 'That game no longer exists.'
  if (!Array.isArray(event.entries)) return 'A recorded game needs serve figures.'

  const seasonId = isNew ? seasonIdFor(state, event) : existing.seasonId
  for (const entry of event.entries) {
    if (!Number.isInteger(entry.in) || !Number.isInteger(entry.out) || entry.in < 0 || entry.out < 0) {
      return 'Serve counts must be whole numbers, and cannot be negative.'
    }
    if (numberFor(state, seasonId, entry.playerId) === null) {
      return 'Every player in a recorded game must be on that season’s roster.'
    }
  }
  return null
}

function setMatchResultRejection(state, event) {
  const game = gameById(state, event.gameId)
  if (!game) return 'That game no longer exists.'
  if (game.kind !== GAME_KIND.TRACKED) return 'That game was recorded from paper; set its result instead.'
  if (!game.matches.some((match) => match.index === event.matchIndex)) return 'That match is not part of this game.'
  if (!isValidResult(event.result)) return 'Unrecognised match result.'
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

function endMatchRejection(state, event) {
  if (!currentMatch(state)) return 'No match is in progress.'
  if (event.result !== undefined && !isValidResult(event.result)) return 'Unrecognised match result.'
  return null
}

function namePresence(value, what) {
  return isPresent(value) ? null : `A ${what} name is required.`
}

function isPresent(value) {
  return typeof value === 'string' && value.trim().length > 0
}

function hasRecordedServe(match) {
  return match.turns.some((turn) => turn.serves.length > 0)
}

// --- Season transitions ------------------------------------------------------

function withSeasonCreated(state, event) {
  const season = {
    id: event.id,
    name: event.name.trim(),
    team: String(event.team ?? '').trim(),
    format: { ...DEFAULT_FORMAT, ...(event.format ?? {}) },
    members: [],
  }
  return {
    ...state,
    seasons: [...state.seasons, season],
    activeSeasonId: state.activeSeasonId ?? season.id,
  }
}

function withSeasonRenamed(state, event) {
  const seasons = state.seasons.map((season) =>
    season.id === event.id
      ? { ...season, name: event.name.trim(), team: String(event.team ?? season.team).trim() }
      : season,
  )
  return { ...state, seasons }
}

/**
 * A season always exists. Requiring the operator to create one before adding a player
 * would be ceremony; the first is made for them and can be renamed.
 */
function ensureSeason(state) {
  if (state.seasons.length > 0 && state.activeSeasonId) return state
  return withSeasonCreated(state, { ...IMPLICIT_SEASON, format: DEFAULT_FORMAT })
}

function seasonIdFor(state, event) {
  return event.seasonId ?? state.activeSeasonId ?? IMPLICIT_SEASON.id
}

// --- Roster transitions ------------------------------------------------------

/**
 * Adds a player to a season: the person is created when new, and given the number they
 * wear THIS season. The number goes on the membership, never on the person -- next season
 * the same child may wear a different one for a different team.
 */
function withPlayerAdded(state, event) {
  const seeded = ensureSeason(state)
  const seasonId = seasonIdFor(seeded, event)
  const name = event.name.trim()
  const number = String(event.number ?? '').trim()

  const players = playerById(seeded, event.id)
    ? seeded.players
    : [...seeded.players, { id: event.id, name }]

  return {
    ...seeded,
    players,
    seasons: mapSeason(seeded, seasonId, (season) => ({
      ...season,
      members: [...season.members, { playerId: event.id, number }],
    })),
  }
}

/** Corrects the name career-wide, and the number for this season only. */
function withPlayerEdited(state, event) {
  const seasonId = seasonIdFor(state, event)
  const players = state.players.map((player) =>
    player.id === event.id ? { ...player, name: event.name.trim() } : player,
  )
  const seasons = mapSeason({ ...state, players }, seasonId, (season) => ({
    ...season,
    members: season.members.map((member) =>
      member.playerId === event.id ? { ...member, number: String(event.number ?? '').trim() } : member,
    ),
  }))
  return { ...state, players, seasons }
}

/**
 * The destructive removal kept from releases 001 and 002: it discards the player's
 * recorded turns, as its confirmation warned.
 *
 * It is retained with its original meaning so that replaying an older log reproduces the
 * figures it produced then. Redefining it would have changed statistics for games already
 * played, which is the one thing a migration must never do. Release 003's roster screen
 * uses the non-destructive path instead.
 */
function withPlayerRemoved(state, event) {
  const seasonId = seasonIdFor(state, event)
  const games = state.games.map((game) => (game.kind === GAME_KIND.HISTORICAL ? game : {
    ...game,
    matches: game.matches.map((match) => ({
      ...match,
      lineup: match.lineup ? match.lineup.map((id) => (id === event.id ? null : id)) : null,
      turns: renumber(match.turns.filter((turn) => turn.playerId !== event.id)),
    })),
  }))

  return {
    ...state,
    players: state.players.filter((player) => player.id !== event.id),
    seasons: mapSeason(state, seasonId, (season) => ({
      ...season,
      members: season.members.filter((member) => member.playerId !== event.id),
    })),
    games,
  }
}

/**
 * Leaves the person, and everything they recorded, exactly where it is. Removing someone
 * from this year's squad says nothing about the serves they took last year.
 */
function withMembershipRemoved(state, event) {
  const seasonId = seasonIdFor(state, event)
  return {
    ...state,
    seasons: mapSeason(state, seasonId, (season) => ({
      ...season,
      members: season.members.filter((member) => member.playerId !== event.playerId),
    })),
  }
}

// --- Game transitions --------------------------------------------------------

function withGameStarted(state, event) {
  const seeded = ensureSeason(state)
  const game = {
    id: event.id,
    seasonId: seasonIdFor(seeded, event),
    kind: GAME_KIND.TRACKED,
    // Absent on games recorded before the rule existed, which is exactly the point.
    rotatesAtServeLimit: event.rotatesAtServeLimit === true,
    ...emptyContext(),
    ...emptyNotes(),
    matches: [newMatch(0)],
  }
  return { ...seeded, games: [...seeded.games, game], currentGameId: event.id }
}

function withGameDiscarded(state, event) {
  return {
    ...state,
    games: state.games.filter((game) => game.id !== event.id),
    currentGameId: state.currentGameId === event.id ? null : state.currentGameId,
  }
}

function withGameContext(state, event) {
  return mapGame(state, event.gameId, (game) => ({
    ...game,
    date: event.date,
    opponent: event.opponent,
    location: event.location,
    court: event.court,
  }))
}

function withGameNotes(state, event) {
  return mapGame(state, event.gameId, (game) => ({
    ...game,
    wentWell: event.wentWell ?? '',
    needsWork: event.needsWork ?? '',
    notes: event.notes ?? '',
  }))
}

/**
 * A game copied from paper: per player, serves in and serves out, at game level.
 * It holds no matches and no turns, because that detail was never written down.
 * Synthesising them would report turn counts that never happened.
 */
/**
 * A result records what happened rather than what was played, so it stays correctable long
 * after the match has ended -- the same reasoning that lets the opponent and the notes be
 * fixed. Nothing about the serves is touched.
 */
/**
 * Corrections to a recorded turn: its serves, whose turn it was, or whether it happened.
 *
 * They apply to any tracked game, including one long finished, because a correction fixes
 * the record of what happened rather than changing what was played. The rule that an ended
 * match is immutable protects the play from being rewritten mid-game; it was never meant to
 * make a typo permanent.
 */
function turnCorrectionRejection(state, event, kind) {
  const game = gameById(state, event.gameId)
  if (!game) return 'That game no longer exists.'
  if (game.kind !== GAME_KIND.TRACKED) return 'That game was recorded from paper; edit its figures instead.'

  const match = game.matches.find((each) => each.index === event.matchIndex)
  if (!match) return 'That match is not part of this game.'
  if (!match.turns.some((turn) => turn.ordinal === event.ordinal)) return 'That serve turn no longer exists.'

  if (kind === 'serves') {
    if (!Array.isArray(event.outcomes)) return 'A turn needs a list of serves.'
    if (event.outcomes.length === 0) return 'A turn with no serves should be deleted instead.'
    if (event.outcomes.some((outcome) => !isValidOutcome(outcome))) return 'Unrecognised serve outcome.'
  }
  if (kind === 'player' && !findPlayer(state, event.playerId)) return 'That player is not on the roster.'

  return null
}

function withTurnServesSet(state, event) {
  return mapTurn(state, event, (turn) => ({
    ...turn,
    serves: event.outcomes.map((outcome) => ({ outcome })),
    // A turn still in progress ends if its last serve no longer wins the rally, because
    // that is what ends a turn. It is never reopened: the serves after it in the match
    // already happened, and handing the ball back now would rewrite them.
    isOpen: turn.isOpen && event.outcomes.at(-1) === OUTCOME.IN_POINT,
  }))
}

/**
 * The turn keeps its place in the order. Only who took it changes -- a serve recorded
 * against the wrong player is still a serve that happened, at that point in the match.
 */
function withTurnReassigned(state, event) {
  return mapTurn(state, event, (turn) => ({
    ...turn,
    playerId: event.playerId,
    isOffLineup: turn.lineupSnapshot ? !turn.lineupSnapshot.includes(event.playerId) : false,
  }))
}

function withTurnDeleted(state, event) {
  return mapMatch(state, event, (match) => ({
    ...match,
    turns: renumber(match.turns.filter((turn) => turn.ordinal !== event.ordinal)),
  }))
}

function mapTurn(state, event, transform) {
  return mapMatch(state, event, (match) => ({
    ...match,
    turns: match.turns.map((turn) => (turn.ordinal === event.ordinal ? transform(turn) : turn)),
  }))
}

function mapMatch(state, event, transform) {
  return mapGame(state, event.gameId, (game) => ({
    ...game,
    matches: game.matches.map((match) => (match.index === event.matchIndex ? transform(match) : match)),
  }))
}

function withMatchResultSet(state, event) {
  return mapGame(state, event.gameId, (game) => ({
    ...game,
    matches: game.matches.map((match) =>
      match.index === event.matchIndex ? { ...match, result: event.result } : match),
  }))
}

function withHistoricalGameAdded(state, event) {
  const seeded = ensureSeason(state)
  const game = {
    id: event.id,
    seasonId: seasonIdFor(seeded, event),
    kind: GAME_KIND.HISTORICAL,
    date: event.date,
    opponent: event.opponent,
    location: event.location,
    court: event.court,
    wentWell: event.wentWell ?? '',
    needsWork: event.needsWork ?? '',
    notes: event.notes ?? '',
    result: event.result ?? MATCH_RESULT.UNDECIDED,
    entries: event.entries.map((entry) => ({ ...entry })),
  }
  return { ...seeded, games: [...seeded.games, game] }
}

function withHistoricalGameEdited(state, event) {
  return mapGame(state, event.id, (game) => ({
    ...game,
    date: event.date,
    opponent: event.opponent,
    location: event.location,
    court: event.court,
    wentWell: event.wentWell ?? game.wentWell,
    needsWork: event.needsWork ?? game.needsWork,
    notes: event.notes ?? game.notes,
    result: event.result ?? game.result,
    entries: event.entries.map((entry) => ({ ...entry })),
  }))
}

function withMatchEnded(state, event) {
  const game = currentGame(state)
  const ending = currentMatch(state)
  const ended = {
    ...ending,
    status: 'ended',
    result: event.result ?? MATCH_RESULT.UNDECIDED,
    turns: closeOpenTurn(ending.turns),
  }

  const matches = game.matches.map((match) => (match.index === ended.index ? ended : match))
  // The next match starts from this one's lineup: with nine on a roster the six on court
  // are usually close, and editing beats rebuilding.
  if (ended.index < MATCHES_PER_GAME - 1) matches.push(newMatch(ended.index + 1, ended.lineup))

  return mapGame(state, game.id, (each) => ({ ...each, matches }))
}

/**
 * Ends the game where it stands. The match in progress is closed and keeps every serve it
 * holds; no further match opens, because none was played.
 */
function withGameEnded(state, event) {
  const game = currentGame(state)
  const ending = currentMatch(state)
  const ended = {
    ...ending,
    status: 'ended',
    result: event.result ?? MATCH_RESULT.UNDECIDED,
    turns: closeOpenTurn(ending.turns),
  }

  return mapGame(state, game.id, (each) => ({
    ...each,
    matches: each.matches.map((match) => (match.index === ended.index ? ended : match)),
  }))
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
  return updateCurrentMatch(state, (match, game) => {
    const turns = match.turns.map((turn) =>
      turn.isOpen
        ? { ...turn, serves: [...turn.serves, { outcome: event.outcome }], isOpen: event.outcome === OUTCOME.IN_POINT }
        : turn,
    )
    return advanceRotation(closeAtServeLimit({ ...match, turns }, game.rotatesAtServeLimit))
  })
}

/**
 * Ends a turn once the server has taken their five, even when the fifth won the point.
 *
 * Without this a server on a run never rotates: the turn only closed on a serve that lost
 * the rally, so five straight points left them serving forever while the order stood still.
 *
 * It ends the turn; it does not discard anything. A referee who miscounts and lets someone
 * serve a sixth time is recorded by choosing that player again -- a second turn, every
 * serve kept.
 *
 * Only where a lineup exists. With manual selection there is no next server to move to,
 * and the operator is already deciding.
 */
function closeAtServeLimit(match, rotatesAtServeLimit) {
  if (!rotatesAtServeLimit || !match.lineup) return match

  const open = openTurn(match)
  if (!open || open.serves.length < SERVE_LIMIT) return match

  return { ...match, turns: match.turns.map((turn) => (turn.isOpen ? { ...turn, isOpen: false } : turn)) }
}

/**
 * Hands the serve to the next player in the order when a turn has just closed.
 *
 * This happens inside the RECORD_SERVE transition rather than as an event of its own, and
 * that is the whole trick: popping the serve removes the advance along with it, so one
 * undo reverses one operator action.
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

// --- Helpers -----------------------------------------------------------------

function emptyContext() {
  return { date: null, opponent: '', location: '', court: '' }
}

function emptyNotes() {
  return { wentWell: '', needsWork: '', notes: '' }
}

function newMatch(index, lineup = null) {
  return {
    index,
    status: 'in_progress',
    result: MATCH_RESULT.UNDECIDED,
    lineup: lineup ? [...lineup] : null,
    substitutions: [],
    turns: [],
  }
}

/**
 * A turn records the position it was served from and who was on court at the time.
 * A server who is not in the lineup still occupies the position that was due: tapping
 * someone off-lineup nearly always means a substitution has not been entered yet, and
 * leaving the position unconsumed would make the order lag by one for the rest of the match.
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

function gameInvolves(game, playerId) {
  if (game.kind === GAME_KIND.HISTORICAL) {
    return game.entries.some((entry) => entry.playerId === playerId)
  }
  return game.matches.some((match) => match.turns.some((turn) => turn.playerId === playerId))
}

function mapSeason(state, seasonId, transform) {
  return state.seasons.map((season) => (season.id === seasonId ? transform(season) : season))
}

function mapGame(state, gameId, transform) {
  return { ...state, games: state.games.map((game) => (game.id === gameId ? transform(game) : game)) }
}

function updateCurrentMatch(state, transform) {
  const game = currentGame(state)
  if (!game) return state
  return mapGame(state, game.id, (each) => ({
    ...each,
    matches: each.matches.map((match) => (match.status === 'in_progress' ? transform(match, each) : match)),
  }))
}

/**
 * `roster` is the ACTIVE season's members with their names and that season's numbers.
 * It is recomputed on every change and never stored -- a number resolved through a season
 * is the whole point of this release, and a cached copy is how it would drift.
 */
function withActiveRoster(state) {
  return { ...state, roster: seasonMembers(state, state.activeSeasonId) }
}
