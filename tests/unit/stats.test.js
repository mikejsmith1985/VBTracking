// Proves derived statistics are correct at every scope, that nothing is ever capped
// at the five-serve rotation limit, and that an undefined percentage is null, not NaN.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'
import { currentGame, currentMatch } from '../../src/domain/reducer.js'
import {
  turnStats,
  matchStats,
  gameStats,
  matchScore,
  isOverServeLimit,
  activeServerId,
  SERVE_LIMIT,
} from '../../src/domain/stats.js'
import { build, roster, turn } from '../helpers.js'

const { OUT, IN_POINT, IN_NO_POINT } = E.OUTCOME

/** A match where p1 serves 3 (2 points) and p2 serves 2 (1 point, closing in-no-point). */
function sampleMatch() {
  const state = build(
    roster(3),
    E.startGame('g1'),
    E.selectServer('p1'), E.recordServe(IN_POINT), E.recordServe(IN_POINT), E.recordServe(OUT),
    E.selectServer('p2'), E.recordServe(IN_POINT), E.recordServe(IN_NO_POINT),
  )
  return { state, match: currentMatch(state) }
}

describe('turn statistics', () => {
  it('counts serves, serves in, and points (FR-017 to FR-019)', () => {
    const { match } = sampleMatch()
    expect(turnStats(match.turns[0])).toMatchObject({ serves: 3, servesIn: 2, points: 2 })
    expect(turnStats(match.turns[1])).toMatchObject({ serves: 2, servesIn: 2, points: 1 })
  })

  it('counts an out serve as a serve but not as a serve in (FR-018)', () => {
    const state = build(roster(1), E.startGame('g1'), E.selectServer('p1'), E.recordServe(OUT))
    expect(turnStats(currentMatch(state).turns[0])).toMatchObject({ serves: 1, servesIn: 0, points: 0 })
  })

  it('reports the in percentage as a ratio', () => {
    const { match } = sampleMatch()
    expect(turnStats(match.turns[0]).inPercentage).toBeCloseTo(2 / 3)
  })

  it('reports null, not NaN, when no serves were attempted (FR-039)', () => {
    expect(turnStats({ serves: [] }).inPercentage).toBeNull()
  })
})

describe('match statistics', () => {
  it('groups by player and counts turns taken (FR-036)', () => {
    const { match } = sampleMatch()
    const stats = matchStats(match)
    expect(stats.get('p1')).toMatchObject({ serves: 3, servesIn: 2, points: 2, turnsTaken: 1 })
    expect(stats.get('p2')).toMatchObject({ serves: 2, servesIn: 2, points: 1, turnsTaken: 1 })
  })

  it('counts two separate turns for a player who returns to serve (FR-028)', () => {
    const state = build(roster(2), E.startGame('g1'), turn('p1', 1), turn('p2', 1), turn('p1', 2))
    const stats = matchStats(currentMatch(state))
    expect(stats.get('p1')).toMatchObject({ turnsTaken: 2, serves: 5, points: 3 })
  })

  it('omits players who never served (FR-036)', () => {
    const { match } = sampleMatch()
    expect(matchStats(match).has('p3')).toBe(false)
  })

  it('reports points on serve as the match score', () => {
    const { match } = sampleMatch()
    expect(matchScore(match)).toBe(3)
  })
})

describe('game statistics', () => {
  it('equals the sum of the per-match totals (FR-037)', () => {
    const state = build(
      roster(2),
      E.startGame('g1'),
      turn('p1', 2), E.endMatch(),
      turn('p1', 3), E.endMatch(),
      turn('p1', 1),
    )
    const game = currentGame(state)
    const perMatch = game.matches.map((match) => matchStats(match).get('p1'))
    const total = gameStats(game).get('p1')

    expect(total.serves).toBe(perMatch.reduce((sum, each) => sum + each.serves, 0))
    expect(total.points).toBe(perMatch.reduce((sum, each) => sum + each.points, 0))
    expect(total.turnsTaken).toBe(3)
  })
})

describe('the five-serve rotation limit', () => {
  it('is five', () => {
    expect(SERVE_LIMIT).toBe(5)
  })

  it('does not flag a turn of exactly five serves (FR-030)', () => {
    const state = build(roster(1), E.startGame('g1'), turn('p1', 4))
    const only = currentMatch(state).turns[0]
    expect(turnStats(only).serves).toBe(5)
    expect(isOverServeLimit(only)).toBe(false)
  })

  it('flags a turn of six or more serves (FR-030)', () => {
    const state = build(roster(1), E.startGame('g1'), turn('p1', 5))
    expect(isOverServeLimit(currentMatch(state).turns[0])).toBe(true)
  })

  it('records every serve of a nine-serve turn without capping (FR-029, SC-008)', () => {
    const state = build(roster(1), E.startGame('g1'), turn('p1', 8))
    const only = currentMatch(state).turns[0]
    expect(only.serves).toHaveLength(9)
    expect(turnStats(only)).toMatchObject({ serves: 9, points: 8 })
    expect(matchStats(currentMatch(state)).get('p1').serves).toBe(9)
  })
})

describe('active server', () => {
  it('is the open turn\'s player', () => {
    const state = build(roster(2), E.startGame('g1'), E.selectServer('p2'), E.recordServe(IN_POINT))
    expect(activeServerId(state)).toBe('p2')
  })

  it('is null after a side-out (FR-022)', () => {
    const state = build(roster(2), E.startGame('g1'), E.selectServer('p2'), E.recordServe(OUT))
    expect(activeServerId(state)).toBeNull()
  })

  it('is null before a game starts', () => {
    expect(activeServerId(build(roster(2)))).toBeNull()
  })
})
