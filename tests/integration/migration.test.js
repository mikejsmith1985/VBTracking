// @vitest-environment jsdom
//
// The test this release exists for. A log written by the SHIPPED release-001 code is
// committed as a fixture and loaded by release-002 code through a REAL Storage. If this
// passes, the stakeholder's recorded games survive the upgrade; if it fails, nothing ships.
//
// The fixture is generated, not hand-written, so it is the format as shipped rather than
// the format as remembered.
import { describe, it, expect, beforeEach } from 'vitest'
import { readFileSync } from 'node:fs'
import { createLocalStoragePersistence, STORAGE_KEY, SCHEMA_VERSION } from '../../src/state/persistence.js'
import { replay, currentGame } from '../../src/domain/reducer.js'
import { matchStats, gameStats, matchScore } from '../../src/domain/stats.js'

// Read relative to the working directory rather than import.meta.url: under jsdom the
// module URL is an http: one, and fileURLToPath rejects it.
const v1Log = JSON.parse(readFileSync('tests/fixtures/v1-log.json', 'utf8'))
const expected = JSON.parse(readFileSync('tests/fixtures/v1-expected.json', 'utf8'))

function loadFixture() {
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(v1Log))
  return createLocalStoragePersistence(window.localStorage).load()
}

describe('a real release-001 log', () => {
  beforeEach(() => window.localStorage.clear())

  it('is stored at version 1, so this test is exercising a real upgrade', () => {
    expect(v1Log.schemaVersion).toBe(1)
    expect(v1Log.schemaVersion).toBeLessThan(SCHEMA_VERSION)
    expect(v1Log.events.length).toBeGreaterThan(40)
  })

  it('loads without the operator being asked anything (FR-001, FR-002)', () => {
    const result = loadFixture()
    expect(result.status).toBe('ok')
    expect(result.migratedFrom).toBe(1)
    expect(result.events).toHaveLength(v1Log.events.length)
  })

  it('preserves every event exactly (FR-007)', () => {
    expect(loadFixture().events).toEqual(v1Log.events)
  })

  it('replays to the same roster, games, matches and turns', () => {
    const state = replay(loadFixture().events)
    const game = currentGame(state)

    expect(state.roster).toHaveLength(expected.roster)
    expect(game.matches.map((match) => ({
      index: match.index, status: match.status, turns: match.turns.length, score: matchScore(match),
    }))).toEqual(expected.matches)
  })

  it('reports statistics identical to before the upgrade (FR-007, SC-001)', () => {
    const state = replay(loadFixture().events)
    const actual = Object.fromEntries([...gameStats(currentGame(state))])

    expect(Object.keys(actual).sort()).toEqual(Object.keys(expected.game).sort())
    for (const [playerId, stats] of Object.entries(expected.game)) {
      expect(actual[playerId], `player ${playerId}`).toEqual(stats)
    }
  })

  it('keeps per-match figures intact, not just game totals', () => {
    const state = replay(loadFixture().events)
    for (const match of currentGame(state).matches) {
      const perMatch = matchStats(match)
      const summed = [...perMatch.values()].reduce((total, each) => total + each.points, 0)
      expect(summed).toBe(matchScore(match))
    }
  })

  it('stamps the carried-forward log so it is not migrated twice (FR-004)', () => {
    loadFixture()
    expect(JSON.parse(window.localStorage.getItem(STORAGE_KEY)).schemaVersion).toBe(SCHEMA_VERSION)

    const second = createLocalStoragePersistence(window.localStorage).load()
    expect(second.migratedFrom).toBeNull()
    expect(second.events).toEqual(v1Log.events)
  })
})

describe('data from a newer release', () => {
  beforeEach(() => window.localStorage.clear())

  it('is refused, and left completely unmodified (FR-005)', () => {
    const future = JSON.stringify({ schemaVersion: SCHEMA_VERSION + 1, events: v1Log.events })
    window.localStorage.setItem(STORAGE_KEY, future)

    const result = createLocalStoragePersistence(window.localStorage).load()
    expect(result.status).toBe('unsupported-version')
    expect(result.events).toEqual([])
    expect(window.localStorage.getItem(STORAGE_KEY)).toBe(future)
  })
})

describe('when the carried-forward log cannot be written back', () => {
  it('still loads, and does not destroy the original (FR-008)', () => {
    const original = JSON.stringify(v1Log)
    const readOnly = {
      getItem: () => original,
      setItem: () => { throw new DOMException('quota', 'QuotaExceededError') },
      removeItem: () => {},
    }

    const result = createLocalStoragePersistence(readOnly).load()
    expect(result.status).toBe('ok')
    expect(result.events).toEqual(v1Log.events)
  })
})
