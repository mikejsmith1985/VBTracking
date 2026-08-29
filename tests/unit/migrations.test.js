// The migration chain is what stands between a released schema change and a stakeholder's
// recorded season. It is pure -- it transforms an event array and knows nothing about
// storage -- so every branch is testable without a browser.
import { describe, it, expect } from 'vitest'
import { SCHEMA_VERSION, MIGRATIONS, migrate } from '../../src/domain/migrations.js'
import * as E from '../../src/domain/events.js'

const sample = [E.addPlayer('p1', 'Rivera', '7'), E.startGame('g1'), E.selectServer('p1')]

describe('the chain', () => {
  it('declares a version at or above 2', () => {
    expect(SCHEMA_VERSION).toBeGreaterThanOrEqual(2)
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

  it('carries a release-1 log forward', () => {
    const result = migrate(sample, 1)
    expect(result.ok).toBe(true)
    expect(result.events).toEqual(sample)
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
