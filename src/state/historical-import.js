// Reads a batch of games copied from paper and turns them into events. It dispatches
// nothing and writes nothing -- the caller decides -- so its rules are testable in Node.
//
// Kept separate from backup.js on purpose: that file REPLACES everything and carries an
// event log; this one ADDS games and carries figures. Different verbs, different shapes.
import { addHistoricalGame, MATCH_RESULT, isValidResult } from '../domain/events.js'

/** Marks a file as one of ours, so an unrelated JSON file is refused rather than read. */
export const IMPORT_MARKER = 'vbtracking'
export const IMPORT_KIND = 'historical-games'

/** More than one player answers to this name; the file has to be more specific. */
const AMBIGUOUS = Symbol('ambiguous')

/**
 * Parses a batch into events ready to dispatch.
 *
 * All or nothing: a partial import leaves the operator unable to tell what landed.
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

  const resolve = buildResolver(parsed.season, season)
  const events = []

  for (const [index, game] of parsed.games.entries()) {
    const built = buildGame(game, index, resolve, season, makeId)
    if (!built.ok) return built
    events.push(built.event)
  }

  return { events, ok: true, reason: null }
}

/**
 * Matches a name in the file to a player on the roster, by three routes in order of
 * confidence.
 *
 * Both sides were typed by a person -- the roster on a phone before a match, the file from
 * handwriting afterwards -- so demanding they agree character for character is a rule the
 * data cannot keep. "Layna" and "Layna Blankenship" are the same child, and refusing the
 * whole import over that helps nobody.
 *
 * Ambiguity is still refused: if two players answer to one first name, guessing would put
 * a serve against the wrong child, which is worse than asking.
 */
function buildResolver(fileSeason, season) {
  const byFullName = new Map()
  const byNumber = new Map()
  const byFirstName = new Map()

  for (const member of season.members) {
    byFullName.set(normalise(member.name), member.id)

    const number = String(member.number ?? '').trim()
    if (number) byNumber.set(number, byNumber.has(number) ? AMBIGUOUS : member.id)

    const first = firstName(member.name)
    if (first) byFirstName.set(first, byFirstName.has(first) ? AMBIGUOUS : member.id)
  }

  // The file declares its own roster with jersey numbers. A number is the least ambiguous
  // thing either side holds, so it is the best bridge between two spellings of a name.
  const fileNameToNumber = new Map(
    (fileSeason?.roster ?? [])
      .map((player) => [normalise(player.name), String(player.number ?? '').trim()])
      .filter(([, number]) => number),
  )

  return function resolve(name) {
    const full = normalise(name)
    if (byFullName.has(full)) return { id: byFullName.get(full) }

    const number = fileNameToNumber.get(full)
    if (number && byNumber.has(number)) {
      const match = byNumber.get(number)
      if (match !== AMBIGUOUS) return { id: match, matchedBy: `number ${number}` }
    }

    const first = firstName(name)
    const match = byFirstName.get(first)
    if (match === AMBIGUOUS) return { ambiguous: first }
    if (match) return { id: match, matchedBy: 'first name' }

    return {}
  }
}

function buildGame(game, index, resolve, season, makeId) {
  const where = game.opponent ? `the game against ${game.opponent}` : `game ${index + 1}`

  if (!Array.isArray(game.serves) || game.serves.length === 0) {
    return failure(`${capitalise(where)} has no serve figures.`)
  }
  if (game.result !== undefined && !isValidResult(game.result)) {
    return failure(`${capitalise(where)} has an unrecognised result.`)
  }

  const entries = []
  for (const row of game.serves) {
    const match = resolve(row.name)

    if (match.ambiguous) {
      return failure(
        `More than one player on the ${season.name} roster is called "${match.ambiguous}", `
        + `so "${row.name}" is ambiguous. Give those players full names and try again. `
        + 'Nothing was imported.',
      )
    }
    if (!match.id) {
      return failure(
        `"${row.name}" does not match anyone on the ${season.name} roster `
        + `(${rosterNames(season)}). Nothing was imported.`,
      )
    }
    if (!isCount(row.in) || !isCount(row.out)) {
      return failure(`${capitalise(where)} has a serve count that is not a whole number of zero or more.`)
    }

    entries.push({ playerId: match.id, in: row.in, out: row.out })
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

/** Names the roster in the failure, so the mismatch can be seen rather than guessed at. */
function rosterNames(season) {
  const names = season.members.map((member) => member.name)
  if (names.length <= 12) return names.join(', ')
  return `${names.slice(0, 12).join(', ')}, and ${names.length - 12} more`
}

function isCount(value) {
  return Number.isInteger(value) && value >= 0
}

function normalise(name) {
  return String(name ?? '').trim().toLowerCase().replace(/\s+/g, ' ')
}

function firstName(name) {
  return normalise(name).split(' ')[0] ?? ''
}

function capitalise(text) {
  return text.charAt(0).toUpperCase() + text.slice(1)
}

function failure(reason) {
  return { events: [], ok: false, reason }
}
