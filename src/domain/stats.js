// Derived statistics. Nothing here is ever stored -- every figure is computed from the
// recorded serves on read, which is why undo cannot leave a total out of step with the
// underlying record.
import { EVENT, OUTCOME, SERVE_LIMIT, isServeIn } from './events.js'
import { currentMatch, openTurn } from './reducer.js'

// Re-exported so callers that already read it from here keep working. It lives with the
// other constants now, because the reducer needs it and cannot import this module.
export { SERVE_LIMIT }

/** The score a match is played to. Reaching it is advisory only -- see hasReachedTarget. */
export const TARGET_SCORE = 21

/** Serves, serves in, points, and in-percentage for a single serve turn. */
export function turnStats(turn) {
  const serves = turn?.serves ?? []
  const servesIn = serves.filter(isServeIn).length
  const points = serves.filter((serve) => serve.outcome === OUTCOME.IN_POINT).length
  return {
    serves: serves.length,
    servesIn,
    points,
    inPercentage: ratioOrNull(servesIn, serves.length),
  }
}

/** Per-player statistics for one match, keyed by player id. */
export function matchStats(match) {
  return aggregate(match?.turns ?? [])
}

/** Per-player statistics across every match of a game, keyed by player id. */
export function gameStats(game) {
  return aggregate((game?.matches ?? []).flatMap((match) => match.turns))
}

/**
 * The match score as this app can know it: points earned on serve. The opponent's score
 * is deliberately not tracked, so this is not the full rally-scoring total. See
 * research.md R-009.
 */
export function matchScore(match) {
  return (match?.turns ?? []).reduce((total, turn) => total + turnStats(turn).points, 0)
}

/** True when a turn ran past the expected rotation limit -- usually a referee miscount. */
export function isOverServeLimit(turn) {
  return (turn?.serves?.length ?? 0) > SERVE_LIMIT
}

/**
 * True when points on serve have reached the target. Advisory only: the opponent's score
 * is not tracked, so the app cannot know whether the two-point margin has been met. The
 * operator ends the match from the official scoreboard.
 */
export function hasReachedTarget(match, target = TARGET_SCORE) {
  return matchScore(match) >= target
}

/**
 * The player serving right now, derived from the open turn rather than stored.
 * Deriving it removes any chance of an active-server pointer disagreeing with the
 * turn list after an undo.
 */
export function activeServerId(state) {
  return openTurn(currentMatch(state))?.playerId ?? null
}

/**
 * How many events may still be undone: everything appended since the last match ended.
 * An ended match is immutable, so undo stops at that boundary.
 */
export function undoableCount(events) {
  const lastEnded = findLastIndex(events, (event) => event.t === EVENT.END_MATCH)
  return events.length - lastEnded - 1
}

/**
 * How many serve turns elapsed while this player was on court, whether or not they served.
 *
 * Read from each turn's lineup snapshot rather than folded from substitution history: it
 * distinguishes a player who sat the match out from one who was on court the whole time
 * and simply never reached the service position.
 */
export function turnsOnCourt(turns, playerId) {
  return played(turns).filter((turn) => turn.lineupSnapshot?.includes(playerId)).length
}

/** The substitutions made during a match, in the order they happened. */
export function substitutionsFor(match) {
  return match?.substitutions ?? []
}

// --- Internals ---------------------------------------------------------------

function aggregate(turns) {
  const byPlayer = new Map()

  for (const turn of played(turns)) {
    const running = byPlayer.get(turn.playerId) ?? { serves: 0, servesIn: 0, points: 0, turnsTaken: 0 }
    const stats = turnStats(turn)
    running.serves += stats.serves
    running.servesIn += stats.servesIn
    running.points += stats.points
    running.turnsTaken += 1
    byPlayer.set(turn.playerId, running)
  }

  for (const running of byPlayer.values()) {
    running.inPercentage = ratioOrNull(running.servesIn, running.serves)
  }
  return byPlayer
}

/**
 * Turns that have actually happened. A turn opened by a server selection or by the
 * rotation holds no serves until one is recorded; counting it would put a player on the
 * statistics table with nothing to their name, and credit them a turn they have not taken.
 */
function played(turns) {
  return (turns ?? []).filter((turn) => turn.serves.length > 0)
}

/** Null rather than NaN or zero when the denominator is zero, so the UI can say so. */
function ratioOrNull(numerator, denominator) {
  return denominator === 0 ? null : numerator / denominator
}

function findLastIndex(items, predicate) {
  for (let index = items.length - 1; index >= 0; index -= 1) {
    if (predicate(items[index])) return index
  }
  return -1
}
