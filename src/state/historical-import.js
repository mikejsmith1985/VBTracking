// Reads a batch of games copied from paper and turns them into events. It dispatches
// nothing and writes nothing -- the caller decides -- so its rules are testable in Node.
//
// Kept separate from backup.js on purpose: that file REPLACES everything and carries an
// event log; this one ADDS games and carries figures. Different verbs, different shapes.
import { addHistoricalGame, MATCH_RESULT, isValidResult } from '../domain/events.js'

/** Marks a file as one of ours, so an unrelated JSON file is refused rather than read. */
export const IMPORT_MARKER = 'vbtracking'
export const IMPORT_KIND = 'historical-games'

/**
 * Parses a batch into events ready to dispatch.
 *
 * Players are matched **by name** against the season's roster, because the file is written
 * by a person reading handwriting and ids mean nothing to them. An unknown name fails the
 * whole import rather than creating a tenth player on a nine-player squad -- a typo must
 * not quietly invent a person.
 *
 * All or nothing (`FR-041`): a partial import leaves the operator unable to tell what
 * landed. Refusing wholesale is recoverable; half-applied is not.
 *
 * Never throws; every failure is a returned reason.
 */
export function parseHistoricalGames(text, season, makeId) {
  let parsed
  try {
    parsed = JSON.parse(text)
  } catch {
    return failure('That file is not readable. It may be damaged or incomplete.')
  }

  if (!parsed || typeof parsed !== 'object') return failure('That file is not a Serve Tracker import.')
  if (parsed.app !== IMPORT_MARKER || parsed.kind !== IMPORT_KIND) {
    return failure('That file is not a Serve Tracker game import.')
  }
  if (!Array.isArray(parsed.games) || parsed.games.length === 0) {
    return failure('That file holds no games.')
  }
  if (!season) return failure('Create a season before importing games into it.')

  const byName = new Map(season.members.map((member) => [normalise(member.name), member.id]))
  const events = []

  for (const [index, game] of parsed.games.entries()) {
    const built = buildGame(game, index, byName, season, makeId)
    if (!built.ok) return built
    events.push(built.event)
  }

  return { events, ok: true, reason: null }
}

function buildGame(game, index, byName, season, makeId) {
  const where = game.opponent ? `the game against ${game.opponent}` : `game ${index + 1}`

  if (!Array.isArray(game.serves) || game.serves.length === 0) {
    return failure(`${capitalise(where)} has no serve figures.`)
  }
  if (game.result !== undefined && !isValidResult(game.result)) {
    return failure(`${capitalise(where)} has an unrecognised result.`)
  }

  const entries = []
  for (const row of game.serves) {
    const playerId = byName.get(normalise(row.name))
    if (!playerId) {
      return failure(`"${row.name}" is not on the ${season.name} roster. Nothing was imported.`)
    }
    if (!isCount(row.in) || !isCount(row.out)) {
      return failure(`${capitalise(where)} has a serve count that is not a whole number of zero or more.`)
    }
    entries.push({ playerId, in: row.in, out: row.out })
  }

  const context = {
    date: game.date ?? null,
    opponent: game.opponent ?? '',
    location: game.location ?? '',
    court: game.court ?? '',
  }
  const event = addHistoricalGame(makeId(), season.id, context, entries, game.notes ?? '')
  event.result = game.result ?? MATCH_RESULT.UNDECIDED

  return { event, ok: true, reason: null }
}

function isCount(value) {
  return Number.isInteger(value) && value >= 0
}

function normalise(name) {
  return String(name ?? '').trim().toLowerCase()
}

function capitalise(text) {
  return text.charAt(0).toUpperCase() + text.slice(1)
}

function failure(reason) {
  return { events: [], ok: false, reason }
}
