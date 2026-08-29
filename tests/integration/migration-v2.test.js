// @vitest-environment jsdom
//
// The second real starting point. A log written by the SHIPPED release-002 code -- with
// lineups, a rotation and a substitution in it -- is committed as a fixture and loaded by
// release-003 code through a real Storage.
//
// One fixture proves the chain runs from its oldest point. Two prove it runs from where
// the operator's data actually is.
import { describe, it, expect, beforeEach } from 'vitest'
import { readFileSync } from 'node:fs'
import { createLocalStoragePersistence, STORAGE_KEY, SCHEMA_VERSION } from '../../src/state/persistence.js'
import {
  replay, currentGame, activeSeason, seasonMembers, numberFor, playerById, gamesInSeason,
} from '../../src/domain/reducer.js'
import { matchStats, gameStats, matchScore, turnsOnCourt, substitutionsFor } from '../../src/domain/stats.js'
import { gameResult, seasonStats } from '../../src/domain/aggregate.js'

const v2Log = JSON.parse(readFileSync('tests/fixtures/v2-log.json', 'utf8'))
const expected = JSON.parse(readFileSync('tests/fixtures/v2-expected.json', 'utf8'))

function loaded() {
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(v2Log))
  return createLocalStoragePersistence(window.localStorage).load()
}

describe('a real release-002 log', () => {
  beforeEach(() => window.localStorage.clear())

  it('is stored at version 2, so this is a real upgrade', () => {
    expect(v2Log.schemaVersion).toBe(2)
    expect(v2Log.schemaVersion).toBeLessThan(SCHEMA_VERSION)
    expect(v2Log.events.some((event) => event.t === 'SET_LINEUP')).toBe(true)
    expect(v2Log.events.some((event) => event.t === 'SUBSTITUTE')).toBe(true)
  })

  it('loads without the operator being asked anything (FR-001)', () => {
    const result = loaded()
    expect(result.status).toBe('ok')
    expect(result.migratedFrom).toBe(2)
  })

  it('keeps every original event, in order, after the season is prepended', () => {
    const carried = loaded().events
    expect(carried[0].t).toBe('CREATE_SEASON')
    expect(carried.slice(1).map((event) => event.t)).toEqual(v2Log.events.map((event) => event.t))
  })
})

describe('what the migrated log replays to', () => {
  beforeEach(() => window.localStorage.clear())

  const state = () => replay(loaded().events)

  it('turns the roster into a season, numbers intact (FR-002)', () => {
    const replayed = state()
    const members = seasonMembers(replayed, replayed.activeSeasonId)

    expect(members).toHaveLength(expected.roster.length)
    for (const player of expected.roster) {
      expect(numberFor(replayed, replayed.activeSeasonId, player.id), player.name).toBe(player.number)
      expect(playerById(replayed, player.id).name).toBe(player.name)
    }
  })

  it('makes each of them a career player carrying no number (FR-003, FR-019)', () => {
    const replayed = state()
    expect(replayed.players).toHaveLength(expected.roster.length)
    expect(replayed.players.every((player) => player.number === undefined)).toBe(true)
  })

  it('attaches every game to that season (FR-004)', () => {
    const replayed = state()
    expect(gamesInSeason(replayed, replayed.activeSeasonId)).toHaveLength(replayed.games.length)
    expect(replayed.games.length).toBeGreaterThan(0)
  })

  it('gives the season a name, a team, and the format that was played', () => {
    const season = activeSeason(state())
    expect(season.name).toBeTruthy()
    expect(season.team).toBeTruthy()
    expect(season.format).toEqual({ matchesPerGame: 3, targetScore: 21, playersOnCourt: 6 })
  })
})

describe('every figure is identical to before the upgrade (FR-005, SC-001)', () => {
  beforeEach(() => window.localStorage.clear())

  const game = () => currentGame(replay(loaded().events))

  it('matches, turns, scores, lineups and substitutions', () => {
    const actual = game().matches.map((match) => ({
      index: match.index,
      status: match.status,
      turns: match.turns.length,
      score: matchScore(match),
      lineup: match.lineup,
      subs: substitutionsFor(match).length,
    }))
    expect(actual).toEqual(expected.matches)
  })

  it('per-player game statistics', () => {
    const actual = Object.fromEntries([...gameStats(game())])
    expect(Object.keys(actual).sort()).toEqual(Object.keys(expected.game).sort())
    for (const [playerId, figures] of Object.entries(expected.game)) {
      expect(actual[playerId], playerId).toEqual(figures)
    }
  })

  it('turns on court, which depends on every lineup snapshot surviving', () => {
    const turns = game().matches.flatMap((match) => match.turns)
    for (const [playerId, count] of Object.entries(expected.onCourt)) {
      expect(turnsOnCourt(turns, playerId), playerId).toBe(count)
    }
  })

  it('per-match figures, not only game totals', () => {
    for (const match of game().matches) {
      const summed = [...matchStats(match).values()].reduce((total, each) => total + each.points, 0)
      expect(summed).toBe(matchScore(match))
    }
  })
})

describe('results and season figures after the upgrade', () => {
  beforeEach(() => window.localStorage.clear())

  it('makes every past match undecided, never lost', () => {
    const ended = currentGame(replay(loaded().events)).matches.filter((match) => match.status === 'ended')
    expect(ended.length).toBeGreaterThan(0)
    expect(ended.every((match) => match.result === 'undecided')).toBe(true)
  })

  it('so the game reads as undecided rather than as a defeat', () => {
    expect(gameResult(currentGame(replay(loaded().events)))).toBe('undecided')
  })

  it('reports the season as fully tracked, since nothing came from paper', () => {
    const replayed = replay(loaded().events)
    const { coverage } = seasonStats(replayed, replayed.activeSeasonId)
    expect(coverage.trackedGames).toBe(coverage.totalGames)
    expect(coverage.totalGames).toBeGreaterThan(0)
  })

  it('reports serve figures that agree with the pre-upgrade per-player totals', () => {
    const replayed = replay(loaded().events)
    const { byPlayer } = seasonStats(replayed, replayed.activeSeasonId)
    for (const [playerId, figures] of Object.entries(expected.game)) {
      expect(byPlayer.get(playerId).serves, playerId).toBe(figures.serves)
      expect(byPlayer.get(playerId).servesIn, playerId).toBe(figures.servesIn)
      expect(byPlayer.get(playerId).points, playerId).toBe(figures.points)
    }
  })
})
