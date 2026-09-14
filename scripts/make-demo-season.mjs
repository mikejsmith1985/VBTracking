// Builds a backup file holding a whole season, for showing the app to somebody who has
// just installed it.
//
// It is built with the app's own event constructors and then replayed through the app's own
// reducer, so what it writes is a log the app can genuinely produce -- not JSON shaped to
// look right. If the reducer refuses an event, this script stops rather than writing a file
// that would be refused on the phone.
//
// The names are invented. No real child appears in a file that goes to App Review.
import { writeFileSync } from 'node:fs'
import {
  addPlayer,
  createSeason,
  activateSeason,
  startGame,
  setGameContext,
  setGameNotes,
  setLineup,
  selectServer,
  recordServe,
  endMatch,
  addHistoricalGame,
  OUTCOME,
  MATCH_RESULT,
} from '../src/domain/events.js'
import { replay, gamesInSeason, isEventValid, applyEvent, emptyState } from '../src/domain/reducer.js'
import { seasonStats } from '../src/domain/aggregate.js'
import { buildExport } from '../src/state/backup.js'

/** The squad. Eight, so substitutions have somewhere to come from. */
const SQUAD = [
  { id: 'p1', name: 'Avery Brooks', number: '4' },
  { id: 'p2', name: 'Riley Chen', number: '5' },
  { id: 'p3', name: 'Jordan Cole', number: '7' },
  { id: 'p4', name: 'Sam Delgado', number: '9' },
  { id: 'p5', name: 'Casey Doyle', number: '11' },
  { id: 'p6', name: 'Morgan Ellis', number: '13' },
  { id: 'p7', name: 'Quinn Farrow', number: '15' },
  { id: 'p8', name: 'Taylor Grant', number: '21' },
]

const SEASON = { id: 's1', name: '2026 Fall', team: 'Riverside Thunder' }

/**
 * A repeatable pseudo-random source.
 *
 * Seeded rather than `Math.random`, so running this twice writes the same season. A demo
 * file that changes every time it is generated cannot be checked against a screenshot.
 */
function makeRandom(seed) {
  let state = seed >>> 0
  return () => {
    state = (state * 1664525 + 1013904223) >>> 0
    return state / 4294967296
  }
}

const random = makeRandom(20260901)

/**
 * One serve turn: serves until the player loses the rally, capped at the league's five.
 *
 * `skill` is how often this player lands a serve in, which is what makes the season's
 * figures differ from player to player instead of all landing on the same percentage.
 */
function serveTurn(skill) {
  const serves = []
  for (let serve = 0; serve < 5; serve += 1) {
    if (random() > skill) {
      serves.push(OUTCOME.OUT)
      break
    }
    if (random() < 0.62) {
      serves.push(OUTCOME.IN_POINT)
    } else {
      serves.push(OUTCOME.IN_NO_POINT)
      break
    }
  }
  return serves
}

/** How well each player serves, so the season table has a real order in it. */
const SKILL = {
  p1: 0.86, p2: 0.72, p3: 0.91, p4: 0.64, p5: 0.79, p6: 0.83, p7: 0.58, p8: 0.75,
}

/** One tracked match: a lineup, then turns handed round it until somebody has enough. */
function trackedMatch(lineup, turnCount) {
  const events = [setLineup(lineup)]
  let position = 0
  for (let turn = 0; turn < turnCount; turn += 1) {
    const playerId = lineup[position % lineup.length]
    events.push(selectServer(playerId))
    for (const outcome of serveTurn(SKILL[playerId])) {
      events.push(recordServe(outcome))
    }
    position += 1
  }
  return events
}

/** A game recorded serve by serve: three matches, a context, notes, and results. */
function trackedGame(id, context, notes, results, lineup, turnsPerMatch) {
  const events = [startGame(id, SEASON.id, true), setGameContext(id, context)]
  results.forEach((result, match) => {
    events.push(...trackedMatch(lineup, turnsPerMatch[match]))
    events.push(endMatch(result))
  })
  events.push(setGameNotes(id, notes))
  return events
}

const lineupA = ['p1', 'p2', 'p3', 'p4', 'p5', 'p6']
const lineupB = ['p2', 'p3', 'p5', 'p6', 'p7', 'p8']
const lineupC = ['p1', 'p3', 'p4', 'p6', 'p7', 'p8']

const events = [
  createSeason(SEASON.id, SEASON.name, SEASON.team),
  activateSeason(SEASON.id),
  ...SQUAD.map((player) => addPlayer(player.id, player.name, player.number, SEASON.id)),

  // Two games copied from paper, which is where most seasons start: serves in and out only.
  // Points and time on court were never written down, so they stay dashes rather than zero.
  addHistoricalGame(
    'g1',
    SEASON.id,
    { date: '2026-09-06', opponent: 'Northside Hawks', location: 'Northside High', court: '2' },
    [
      { playerId: 'p1', in: 12, out: 3 },
      { playerId: 'p2', in: 8, out: 4 },
      { playerId: 'p3', in: 14, out: 2 },
      { playerId: 'p4', in: 6, out: 5 },
      { playerId: 'p5', in: 9, out: 3 },
      { playerId: 'p6', in: 11, out: 2 },
    ],
    { wentWell: 'Serve receive held up all three matches.', needsWork: 'Talk on the second touch.', notes: '' },
  ),
  addHistoricalGame(
    'g2',
    SEASON.id,
    { date: '2026-09-13', opponent: 'Eastvale Eagles', location: 'Riverside Middle', court: '1' },
    [
      { playerId: 'p1', in: 10, out: 4 },
      { playerId: 'p2', in: 11, out: 3 },
      { playerId: 'p3', in: 13, out: 1 },
      { playerId: 'p5', in: 7, out: 6 },
      { playerId: 'p6', in: 12, out: 3 },
      { playerId: 'p7', in: 5, out: 7 },
    ],
    { wentWell: 'Every server got through a full rotation.', needsWork: 'Short serves under pressure.', notes: '' },
  ),

  // Three games tracked serve by serve, which is what the app is for.
  ...trackedGame(
    'g3',
    { date: '2026-09-20', opponent: 'Westbrook Wolves', location: 'Westbrook Gym', court: '3' },
    { wentWell: 'Held serve twice from behind.', needsWork: 'First-ball attack.', notes: 'Short bench, no subs.' },
    [MATCH_RESULT.WON, MATCH_RESULT.LOST, MATCH_RESULT.WON],
    lineupA,
    [11, 9, 12],
  ),
  ...trackedGame(
    'g4',
    { date: '2026-09-27', opponent: 'Summit Storm', location: 'Riverside Middle', court: '1' },
    { wentWell: 'Best serving night of the season.', needsWork: 'Free ball coverage.', notes: '' },
    [MATCH_RESULT.WON, MATCH_RESULT.WON, MATCH_RESULT.UNDECIDED],
    lineupB,
    [13, 10, 6],
  ),
  ...trackedGame(
    'g5',
    { date: '2026-10-04', opponent: 'Northside Hawks', location: 'Riverside Middle', court: '2' },
    { wentWell: 'Much better talk than the first meeting.', needsWork: 'Serve deep on match point.', notes: '' },
    [MATCH_RESULT.LOST, MATCH_RESULT.WON, MATCH_RESULT.LOST],
    lineupC,
    [10, 12, 9],
  ),
]

// Every event is checked against the state it would actually meet. A backup the app would
// refuse is worse than no backup: it fails in front of whoever is being shown the app.
let state = emptyState()
events.forEach((event, index) => {
  if (!isEventValid(state, event)) {
    console.error(`Event ${index} (${event.t}) would be refused by the app. Nothing was written.`)
    process.exit(1)
  }
  state = applyEvent(state, event)
})

const replayed = replay(events)
const games = gamesInSeason(replayed, SEASON.id)
const stats = seasonStats(replayed, SEASON.id)

const out = process.argv[2] ?? 'vbtracking-demo-season.json'
writeFileSync(out, buildExport(events, new Date('2026-10-05T18:30:00Z')))

console.log(`Wrote ${out}`)
console.log(`  season   ${SEASON.name} - ${SEASON.team}`)
console.log(`  players  ${SQUAD.length}`)
console.log(`  games    ${games.length} (${games.filter((game) => game.kind === 'tracked').length} tracked, ${games.filter((game) => game.kind === 'historical').length} from paper)`)
console.log(`  events   ${events.length}`)
console.log('')
console.log('  player            serves   in    in%   pts')
for (const player of SQUAD) {
  const figures = stats.byPlayer.get(player.id)
  if (!figures) continue
  // The figure is a fraction, as it is everywhere else in the domain. A dash where nothing
  // was recorded, never a zero.
  const percentage = figures.inPercentage === null ? '-' : `${Math.round(figures.inPercentage * 100)}%`
  const points = figures.points === null ? '-' : figures.points
  console.log(
    `  ${player.number.padStart(2)} ${player.name.padEnd(15)} ${String(figures.serves).padStart(4)} ${String(figures.servesIn).padStart(5)} ${percentage.padStart(6)} ${String(points).padStart(5)}`,
  )
}
