// Figures across a list of games -- one game, a season, or a whole career.
//
// Season and career are the same question asked over different sets, so there is one
// aggregation and three callers. Writing them separately would put the tracked-versus-
// historical rule in three places, and that is exactly the rule that must not drift.
//
// Pure, like everything in this directory.
import { GAME_KIND, MATCH_RESULT } from './events.js'
import { gamesInSeason, gamesForPlayer, seasonsForPlayer, numberFor } from './reducer.js'
import { matchStats, turnsOnCourt } from './stats.js'

/**
 * How a game turned out. A tracked game's result follows from its matches; a match ended
 * without a marked result counts toward neither side, because silence is not a defeat.
 */
export function gameResult(game) {
  if (!game) return MATCH_RESULT.UNDECIDED
  if (game.kind === GAME_KIND.HISTORICAL) return game.result ?? MATCH_RESULT.UNDECIDED

  const ended = game.matches.filter((match) => match.status === 'ended')
  const won = ended.filter((match) => match.result === MATCH_RESULT.WON).length
  const lost = ended.filter((match) => match.result === MATCH_RESULT.LOST).length

  if (won > lost) return MATCH_RESULT.WON
  if (lost > won) return MATCH_RESULT.LOST
  return MATCH_RESULT.UNDECIDED
}

/** Wins, losses, and undecided games. Undecided is counted, never folded into losses. */
export function seasonRecord(games) {
  const record = { won: 0, lost: 0, undecided: 0 }
  for (const game of games ?? []) {
    const result = gameResult(game)
    if (result === MATCH_RESULT.WON) record.won += 1
    else if (result === MATCH_RESULT.LOST) record.lost += 1
    else record.undecided += 1
  }
  return record
}

/** The same record, grouped by who was played. */
export function recordByOpponent(games) {
  const byOpponent = new Map()
  for (const game of games ?? []) {
    const opponent = game.opponent?.trim() || 'Unnamed opponent'
    if (!byOpponent.has(opponent)) byOpponent.set(opponent, [])
    byOpponent.get(opponent).push(game)
  }
  return new Map([...byOpponent].map(([opponent, played]) => [opponent, seasonRecord(played)]))
}

/**
 * Per-player figures across a list of games, plus how many of those games were tracked
 * serve by serve.
 *
 * Serves, serves in, and the percentage span every game. Points and turns exist only where
 * play was tracked, so a player with no tracked games gets null for those -- never zero,
 * which would report worse figures than they actually earned.
 */
export function aggregate(games) {
  const list = games ?? []
  const byPlayer = new Map()

  for (const game of list) {
    if (game.kind === GAME_KIND.HISTORICAL) addHistorical(byPlayer, game)
    else addTracked(byPlayer, game)
  }

  for (const figures of byPlayer.values()) finalise(figures)

  return {
    byPlayer,
    coverage: {
      totalGames: list.length,
      trackedGames: list.filter((game) => game.kind !== GAME_KIND.HISTORICAL).length,
    },
  }
}

/** Per-player figures for one season. */
export function seasonStats(state, seasonId) {
  return aggregate(gamesInSeason(state, seasonId))
}

/**
 * One player across every season they appear in: each season separately, and combined.
 * This is what career identity is for -- the same child, two teams, two numbers.
 */
export function careerStats(state, playerId) {
  const seasons = seasonsForPlayer(state, playerId).map((season) => {
    const played = gamesInSeason(state, season.id).filter((game) => gameHasPlayer(game, playerId))
    const { byPlayer, coverage } = aggregate(played)
    return {
      seasonId: season.id,
      name: season.name,
      team: season.team,
      number: numberFor(state, season.id, playerId),
      games: played.length,
      record: seasonRecord(played),
      figures: byPlayer.get(playerId) ?? null,
      coverage,
    }
  })

  const everything = aggregate(gamesForPlayer(state, playerId))
  return {
    seasons,
    total: everything.byPlayer.get(playerId) ?? null,
    coverage: everything.coverage,
  }
}

/**
 * Who served most in, and who served most accurately -- the two figures tallied by hand at
 * the bottom of every paper sheet.
 */
export function gameSummary(game) {
  const entries = [...aggregate([game]).byPlayer.entries()]
  if (entries.length === 0) return { serves: 0, servesIn: 0, topScorer: null, topPercentage: null }

  const serves = entries.reduce((total, [, figures]) => total + figures.serves, 0)
  const servesIn = entries.reduce((total, [, figures]) => total + figures.servesIn, 0)

  const scorer = best(entries, ([, figures]) => figures.servesIn)
  const served = entries.filter(([, figures]) => figures.serves > 0)
  const accurate = served.length ? best(served, ([, figures]) => figures.inPercentage) : null

  return {
    serves,
    servesIn,
    topScorer: scorer ? { playerId: scorer[0], servesIn: scorer[1].servesIn } : null,
    topPercentage: accurate ? { playerId: accurate[0], inPercentage: accurate[1].inPercentage } : null,
  }
}

/** True when the player took any part in the game -- served, or was on court. */
export function gameHasPlayer(game, playerId) {
  if (game.kind === GAME_KIND.HISTORICAL) {
    return game.entries.some((entry) => entry.playerId === playerId)
  }
  return game.matches.some((match) => match.turns.some((turn) =>
    turn.playerId === playerId || (turn.lineupSnapshot ?? []).includes(playerId)))
}

// --- Internals ---------------------------------------------------------------

function blank() {
  return {
    serves: 0, servesIn: 0, inPercentage: null,
    points: 0, turnsTaken: 0, turnsOnCourt: 0,
    games: 0, trackedGames: 0,
  }
}

function reach(byPlayer, playerId) {
  if (!byPlayer.has(playerId)) byPlayer.set(playerId, blank())
  return byPlayer.get(playerId)
}

function addHistorical(byPlayer, game) {
  for (const entry of game.entries) {
    const figures = reach(byPlayer, entry.playerId)
    figures.serves += entry.in + entry.out
    figures.servesIn += entry.in
    figures.games += 1
  }
}

function addTracked(byPlayer, game) {
  const turns = game.matches.flatMap((match) => match.turns)
  const served = matchStats({ turns })

  for (const [playerId, stats] of served) {
    const figures = reach(byPlayer, playerId)
    figures.serves += stats.serves
    figures.servesIn += stats.servesIn
    figures.points += stats.points
    figures.turnsTaken += stats.turnsTaken
    figures.turnsOnCourt += turnsOnCourt(turns, playerId)
    figures.games += 1
    figures.trackedGames += 1
  }

  // Someone on court who never reached the service position still played the game.
  for (const playerId of onCourt(turns)) {
    if (served.has(playerId)) continue
    const figures = reach(byPlayer, playerId)
    figures.turnsOnCourt += turnsOnCourt(turns, playerId)
    figures.games += 1
    figures.trackedGames += 1
  }
}

function onCourt(turns) {
  const seen = new Set()
  for (const turn of turns) {
    for (const playerId of turn.lineupSnapshot ?? []) if (playerId) seen.add(playerId)
  }
  return seen
}

/**
 * A figure that was never recorded is null, never zero. Zero would say the player served
 * and won nothing; null says the game did not record it.
 */
function finalise(figures) {
  figures.inPercentage = figures.serves === 0 ? null : figures.servesIn / figures.serves
  if (figures.trackedGames === 0) {
    figures.points = null
    figures.turnsTaken = null
    figures.turnsOnCourt = null
  }
}

function best(entries, score) {
  return entries.reduce((leader, entry) => (score(entry) > score(leader) ? entry : leader))
}
