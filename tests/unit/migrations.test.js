// The migration chain is what stands between a released schema change and a stakeholder's
// recorded season. It is pure -- it transforms an event array and knows nothing about
// storage -- so every branch is testable without a browser.
import { describe, it, expect } from 'vitest'
import { SCHEMA_VERSION, MIGRATIONS, migrate, MIGRATED_SEASON_ID } from '../../src/domain/migrations.js'
import * as E from '../../src/domain/events.js'

const sample = [E.addPlayer('p1', 'Rivera', '7'), E.startGame('g1'), E.selectServer('p1')]

describe('the chain', () => {
  it('declares a version at or above 3', () => {
    expect(SCHEMA_VERSION).toBeGreaterThanOrEqual(3)
  })

  it('has a step for every version below the current one', () => {
    for (let version = 1; version < SCHEMA_VERSION; version += 1) {
      expect(typeof MIGRATIONS[version], `no step for version ${version}`).toBe('function')
    }
  })

  it('has no step for the current version -- there is nothing above it to reach', () => {
    expect(MIGRATIONS[SCHEMA_VERSION]).toBeUndefined()
  })
})

describe('migrate', () => {
  it('returns a log already at the current version untouched', () => {
    const result = migrate(sample, SCHEMA_VERSION)
    expect(result.ok).toBe(true)
    expect(result.events).toEqual(sample)
  })

  it('carries a release-1 log forward through every step', () => {
    const result = migrate(sample, 1)
    expect(result.ok).toBe(true)
    // Gathered into a season, with every original event still present and in order.
    expect(result.events[0].t).toBe('CREATE_SEASON')
    expect(result.events.slice(1).map((event) => event.t)).toEqual(sample.map((event) => event.t))
  })

  it('never mutates the array it is given', () => {
    const original = [...sample]
    migrate(sample, 1)
    expect(sample).toEqual(original)
  })

  it('returns a new array, so a caller cannot write through it', () => {
    expect(migrate(sample, 1).events).not.toBe(sample)
  })

  it('refuses a version newer than it understands, and returns no events', () => {
    const result = migrate(sample, SCHEMA_VERSION + 1)
    expect(result.ok).toBe(false)
    expect(result.reason).toMatch(/newer/i)
    expect(result.events).toEqual([])
  })

  it('refuses a version with no path rather than guessing', () => {
    for (const bogus of [0, -1, 1.5, null, undefined, 'one', NaN]) {
      const result = migrate(sample, bogus)
      expect(result.ok, `accepted ${String(bogus)}`).toBe(false)
      expect(result.events).toEqual([])
    }
  })

  it('applies every intervening step in order', () => {
    // A stand-in chain proves the loop, independent of what the real steps happen to do.
    const trace = []
    const chain = {
      1: (events) => { trace.push(1); return [...events, 'from-1'] },
      2: (events) => { trace.push(2); return [...events, 'from-2'] },
      3: (events) => { trace.push(3); return [...events, 'from-3'] },
    }
    const result = migrate([], 1, { migrations: chain, targetVersion: 4 })

    expect(result.ok).toBe(true)
    expect(trace).toEqual([1, 2, 3])
    expect(result.events).toEqual(['from-1', 'from-2', 'from-3'])
  })

  it('stops with a reason when a step in the middle is missing', () => {
    const chain = { 1: (events) => events }
    const result = migrate([], 1, { migrations: chain, targetVersion: 3 })
    expect(result.ok).toBe(false)
    expect(result.events).toEqual([])
  })
})


describe('the 2 -> 3 step', () => {
  const legacy = [
    { t: 'ADD_PLAYER', id: 'p1', name: 'Rivera', number: '7' },
    { t: 'ADD_PLAYER', id: 'p2', name: 'Okafor', number: '3' },
    { t: 'EDIT_PLAYER', id: 'p1', name: 'Rivera-Smith', number: '17' },
    { t: 'START_GAME', id: 'g1' },
    { t: 'SET_LINEUP', playerIds: ['p1', 'p2'] },
    { t: 'SELECT_SERVER', playerId: 'p1' },
    { t: 'RECORD_SERVE', outcome: 'IN_POINT' },
    { t: 'END_MATCH' },
    { t: 'REMOVE_PLAYER', id: 'p2' },
  ]
  const carried = migrate(legacy, 2).events

  it('prepends exactly one season', () => {
    expect(carried[0].t).toBe('CREATE_SEASON')
    expect(carried.filter((event) => event.t === 'CREATE_SEASON')).toHaveLength(1)
    expect(carried).toHaveLength(legacy.length + 1)
  })

  it('gives the season a name, a team, and the format that was played', () => {
    expect(carried[0].id).toBe(MIGRATED_SEASON_ID)
    expect(carried[0].name).toBeTruthy()
    expect(carried[0].team).toBeTruthy()
    expect(carried[0].format).toEqual({ matchesPerGame: 3, targetScore: 21, playersOnCourt: 6 })
  })

  it('stamps a season onto membership and game events (FR-002, FR-004)', () => {
    for (const type of ['ADD_PLAYER', 'EDIT_PLAYER', 'REMOVE_PLAYER', 'START_GAME']) {
      for (const event of carried.filter((each) => each.t === type)) {
        expect(event.seasonId, type).toBe(MIGRATED_SEASON_ID)
      }
    }
  })

  it('makes every past match undecided, never lost', () => {
    for (const event of carried.filter((each) => each.t === 'END_MATCH')) {
      expect(event.result).toBe('undecided')
    }
  })

  it('leaves serve events completely untouched', () => {
    const before = legacy.filter((e) => ['SET_LINEUP', 'SELECT_SERVER', 'RECORD_SERVE'].includes(e.t))
    const after = carried.filter((e) => ['SET_LINEUP', 'SELECT_SERVER', 'RECORD_SERVE'].includes(e.t))
    expect(after).toEqual(before)
  })

  it('renames nothing and removes nothing -- order is preserved after the prepend', () => {
    expect(carried.slice(1).map((event) => event.t)).toEqual(legacy.map((event) => event.t))
  })

  it("preserves each player's jersey number, to become that season's number", () => {
    const added = carried.filter((event) => event.t === 'ADD_PLAYER')
    expect(added.map((event) => event.number)).toEqual(['7', '3'])
  })

  it('does not mutate the log it was given', () => {
    const original = JSON.parse(JSON.stringify(legacy))
    migrate(legacy, 2)
    expect(legacy).toEqual(original)
  })

  it('carries a release-1 log all the way through both steps', () => {
    const result = migrate(legacy, 1)
    expect(result.ok).toBe(true)
    expect(result.events[0].t).toBe('CREATE_SEASON')
    expect(result.events.filter((event) => event.t === 'ADD_PLAYER')[0].seasonId).toBe(MIGRATED_SEASON_ID)
  })
})
