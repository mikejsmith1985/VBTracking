// Proves the release's integrity rule: a figure that was never recorded is reported as
// not recorded, never as zero. Averaging a paper game's missing points into a zero would
// report worse figures than the players earned.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'
import { replay, gamesInSeason } from '../../src/domain/reducer.js'
import {
  aggregate, seasonStats, careerStats, gameSummary,
  gameResult, seasonRecord, recordByOpponent,
} from '../../src/domain/aggregate.js'
import { build, roster } from '../helpers.js'

const { OUT, IN_POINT } = E.OUTCOME
const { WON, LOST, UNDECIDED } = E.MATCH_RESULT

const context = (opponent, date = '2026-08-08') => ({ date, opponent, location: 'Fayetteville', court: '1' })

/** A season with one tracked game and one game copied from paper. */
function mixedSeason() {
  return build(
    roster(3),
    E.startGame('g1'),
    E.setGameContext('g1', context('Georgetown A')),
    E.selectServer('p1'), E.recordServe(IN_POINT), E.recordServe(IN_POINT), E.recordServe(OUT),
    E.selectServer('p2'), E.recordServe(OUT),
    E.endMatch(WON), E.endMatch(WON), E.endMatch(LOST),
    E.addHistoricalGame('h1', 'season-1', context('Blanchester'), [
      { playerId: 'p1', in: 9, out: 2 },
      { playerId: 'p2', in: 10, out: 3 },
      { playerId: 'p3', in: 0, out: 4 },
    ], 'Lots of serves in'),
  )
}

describe('serves span every game; points do not', () => {
  const state = mixedSeason()
  const { byPlayer, coverage } = seasonStats(state, 'season-1')

  it('counts serves and serves in across tracked and paper games alike (FR-043)', () => {
    // p1: 3 tracked serves (2 in) + 11 paper serves (9 in)
    expect(byPlayer.get('p1')).toMatchObject({ serves: 14, servesIn: 11 })
  })

  it('reports the in percentage across both kinds', () => {
    expect(byPlayer.get('p1').inPercentage).toBeCloseTo(11 / 14)
  })

  it('counts points from the tracked game only (FR-044)', () => {
    expect(byPlayer.get('p1').points).toBe(2)
  })

  it('says how many of the games were tracked, so the UI can label honestly', () => {
    expect(coverage).toEqual({ totalGames: 2, trackedGames: 1 })
  })

  it('reports null, never zero, for a player who only has paper games (FR-045)', () => {
    expect(byPlayer.get('p3').points).toBeNull()
    expect(byPlayer.get('p3').turnsTaken).toBeNull()
    expect(byPlayer.get('p3').turnsOnCourt).toBeNull()
    expect(byPlayer.get('p3').serves).toBe(4)
  })

  it('never reports zero where nothing was recorded', () => {
    for (const figures of byPlayer.values()) {
      if (figures.trackedGames === 0) {
        expect(figures.points).not.toBe(0)
        expect(figures.turnsTaken).not.toBe(0)
      }
    }
  })
})

describe('season totals equal the sum of the games (FR-050)', () => {
  it('for every player', () => {
    const state = mixedSeason()
    const games = gamesInSeason(state, 'season-1')
    const season = seasonStats(state, 'season-1').byPlayer

    for (const playerId of season.keys()) {
      const summed = games.reduce((total, game) => {
        const figures = aggregate([game]).byPlayer.get(playerId)
        return total + (figures?.serves ?? 0)
      }, 0)
      expect(summed, playerId).toBe(season.get(playerId).serves)
    }
  })
})

describe('results', () => {
  it('a game is won when more matches were won than lost (FR-030)', () => {
    expect(gameResult(gamesInSeason(mixedSeason(), 'season-1')[0])).toBe(WON)
  })

  it('an unmarked match counts toward neither side (FR-029)', () => {
    const state = build(roster(2), E.startGame('g1'), E.selectServer('p1'),
      E.recordServe(OUT), E.endMatch())
    expect(state.games[0].matches[0].result).toBe(UNDECIDED)
    expect(gameResult(state.games[0])).toBe(UNDECIDED)
  })

  it('a game with equal wins and losses is undecided, not lost', () => {
    const state = build(roster(2), E.startGame('g1'), E.selectServer('p1'), E.recordServe(OUT),
      E.endMatch(WON), E.endMatch(LOST), E.endMatch())
    expect(gameResult(state.games[0])).toBe(UNDECIDED)
  })

  it('a paper game carries the result it was given', () => {
    const state = build(roster(1), E.addHistoricalGame('h1', 'season-1', context('CNE'),
      [{ playerId: 'p1', in: 1, out: 1 }]))
    state.games[0].result = LOST
    expect(gameResult(state.games[0])).toBe(LOST)
  })

  it('a season record counts undecided separately, never as a loss (FR-031)', () => {
    const games = [
      { kind: 'historical', result: WON, opponent: 'A', entries: [] },
      { kind: 'historical', result: LOST, opponent: 'B', entries: [] },
      { kind: 'historical', result: UNDECIDED, opponent: 'A', entries: [] },
    ]
    expect(seasonRecord(games)).toEqual({ won: 1, lost: 1, undecided: 1 })
  })

  it('breaks the record down by opponent', () => {
    const games = [
      { kind: 'historical', result: WON, opponent: 'Blanchester', entries: [] },
      { kind: 'historical', result: LOST, opponent: 'Blanchester', entries: [] },
      { kind: 'historical', result: WON, opponent: 'CNE', entries: [] },
    ]
    const byOpponent = recordByOpponent(games)
    expect(byOpponent.get('Blanchester')).toEqual({ won: 1, lost: 1, undecided: 0 })
    expect(byOpponent.get('CNE')).toEqual({ won: 1, lost: 0, undecided: 0 })
  })

  it('groups games with no opponent recorded rather than dropping them', () => {
    expect(recordByOpponent([{ kind: 'historical', result: WON, opponent: '', entries: [] }]).size).toBe(1)
  })
})

describe('a game summary, so nobody tallies it by hand (FR-046)', () => {
  const state = mixedSeason()

  it('names who landed the most serves in', () => {
    const paper = gamesInSeason(state, 'season-1')[1]
    expect(gameSummary(paper).topScorer).toEqual({ playerId: 'p2', servesIn: 10 })
  })

  it('names who served most accurately, which need not be the top scorer', () => {
    const paper = gamesInSeason(state, 'season-1')[1]
    // p2 landed more in (10 of 13), but p1 was the more accurate server (9 of 11).
    expect(gameSummary(paper).topPercentage.playerId).toBe('p1')
    expect(gameSummary(paper).topScorer.playerId).toBe('p2')
  })

  it('ignores anyone who did not serve when ranking accuracy', () => {
    const summary = gameSummary({
      kind: 'historical',
      entries: [{ playerId: 'served', in: 1, out: 1 }, { playerId: 'benched', in: 0, out: 0 }],
    })
    expect(summary.topPercentage.playerId).toBe('served')
  })

  it('totals the game', () => {
    const paper = gamesInSeason(state, 'season-1')[1]
    expect(gameSummary(paper)).toMatchObject({ serves: 28, servesIn: 19 })
  })

  it('says nothing rather than guessing for a game with no serves', () => {
    expect(gameSummary({ kind: 'historical', entries: [] })).toMatchObject({ topScorer: null })
  })
})

describe('a career across seasons (FR-048)', () => {
  const state = build(
    E.createSeason('s1', '2026', 'Bethel Tigers'),
    E.addPlayer('kid', 'Aria Smith', '5', 's1'),
    E.addHistoricalGame('h1', 's1', context('CNE'), [{ playerId: 'kid', in: 8, out: 2 }]),
    E.createSeason('s2', '2027', 'School Team'),
    E.activateSeason('s2'),
    E.addPlayer('kid', 'Aria Smith', '12', 's2'),
    E.addHistoricalGame('h2', 's2', context('Felicity', '2027-08-08'), [{ playerId: 'kid', in: 12, out: 1 }]),
  )
  const career = careerStats(state, 'kid')

  it('lists each season separately, with that season’s team and number', () => {
    expect(career.seasons.map((season) => [season.name, season.team, season.number]))
      .toEqual([['2026', 'Bethel Tigers', '5'], ['2027', 'School Team', '12']])
  })

  it('reports each season’s own figures', () => {
    expect(career.seasons[0].figures).toMatchObject({ serves: 10, servesIn: 8 })
    expect(career.seasons[1].figures).toMatchObject({ serves: 13, servesIn: 12 })
  })

  it('combines them into a total equal to their sum', () => {
    expect(career.total).toMatchObject({ serves: 23, servesIn: 20 })
  })

  it('reports coverage across the whole career', () => {
    expect(career.coverage).toEqual({ totalGames: 2, trackedGames: 0 })
  })

  it('shows one season without implying others are missing', () => {
    expect(careerStats(state, 'kid').seasons).toHaveLength(2)
    const solo = build(roster(1), E.addHistoricalGame('h1', 'season-1', context('X'),
      [{ playerId: 'p1', in: 1, out: 0 }]))
    expect(careerStats(solo, 'p1').seasons).toHaveLength(1)
  })
})

describe('players on court who never served', () => {
  it('are counted as having played, with no serves', () => {
    const state = build(
      roster(7), E.startGame('g1'),
      E.setLineup(['p1', 'p2', 'p3', 'p4', 'p5', 'p6']),
      E.selectServer('p1'), E.recordServe(IN_POINT), E.recordServe(OUT),
    )
    const figures = aggregate(state.games).byPlayer.get('p6')
    expect(figures.serves).toBe(0)
    expect(figures.turnsOnCourt).toBeGreaterThan(0)
  })

  it('do not appear at all if they never took the court', () => {
    const state = build(
      roster(7), E.startGame('g1'),
      E.setLineup(['p1', 'p2', 'p3', 'p4', 'p5', 'p6']),
      E.selectServer('p1'), E.recordServe(OUT),
    )
    expect(aggregate(state.games).byPlayer.has('p7')).toBe(false)
  })
})

describe('an empty list', () => {
  it('aggregates to nothing rather than failing', () => {
    expect(aggregate([]).byPlayer.size).toBe(0)
    expect(aggregate(null).coverage).toEqual({ totalGames: 0, trackedGames: 0 })
  })
})
