// @vitest-environment jsdom
//
// Integration test for the storage adapter. Runs against a REAL Storage implementation
// provided by jsdom -- never a mocked driver, which is the substitution Article V forbids.
// The service worker's offline behaviour cannot be proven here; that is verified on the
// device in airplane mode (quickstart.md V-7).
import { describe, it, expect, beforeEach } from 'vitest'
import * as E from '../../src/domain/events.js'
import { createLocalStoragePersistence, STORAGE_KEY, SCHEMA_VERSION } from '../../src/state/persistence.js'

const sampleEvents = [
  E.addPlayer('p1', 'Rivera', '7'),
  E.startGame('g1'),
  E.selectServer('p1'),
  E.recordServe(E.OUTCOME.IN_POINT),
]

describe('localStorage persistence', () => {
  beforeEach(() => {
    window.localStorage.clear()
  })

  it('round-trips an event log through real storage (FR-056, FR-057)', () => {
    const persistence = createLocalStoragePersistence(window.localStorage)
    expect(persistence.save(sampleEvents)).toEqual({ ok: true })

    const reloaded = createLocalStoragePersistence(window.localStorage).load()
    expect(reloaded.status).toBe('ok')
    expect(reloaded.events).toEqual(sampleEvents)
  })

  it('returns an empty log for a first run', () => {
    expect(createLocalStoragePersistence(window.localStorage).load())
      .toMatchObject({ events: [], status: 'ok' })
  })

  it('reports corrupt data rather than partially applying it', () => {
    window.localStorage.setItem(STORAGE_KEY, '{ not json')
    const result = createLocalStoragePersistence(window.localStorage).load()
    expect(result.status).toBe('corrupt')
    expect(result.events).toEqual([])
  })

  it('refuses a payload written by a newer schema version', () => {
    window.localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ schemaVersion: SCHEMA_VERSION + 1, events: sampleEvents }),
    )
    const result = createLocalStoragePersistence(window.localStorage).load()
    expect(result.status).toBe('unsupported-version')
    expect(result.events).toEqual([])
  })

  it('treats a payload with no event array as corrupt', () => {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify({ schemaVersion: SCHEMA_VERSION }))
    expect(createLocalStoragePersistence(window.localStorage).load().status).toBe('corrupt')
  })

  it('reports a write failure instead of throwing (FR-058)', () => {
    const fullStorage = {
      getItem: () => null,
      setItem: () => { throw new DOMException('quota exceeded', 'QuotaExceededError') },
      removeItem: () => {},
    }
    expect(createLocalStoragePersistence(fullStorage).save(sampleEvents)).toEqual({ ok: false })
  })

  it('reports unavailable storage instead of throwing', () => {
    const blockedStorage = {
      getItem: () => { throw new DOMException('denied', 'SecurityError') },
      setItem: () => { throw new DOMException('denied', 'SecurityError') },
      removeItem: () => {},
    }
    expect(createLocalStoragePersistence(blockedStorage).load().status).toBe('unavailable')
  })

  it('writes a versioned envelope so a future migration can recognise it', () => {
    createLocalStoragePersistence(window.localStorage).save(sampleEvents)
    const raw = JSON.parse(window.localStorage.getItem(STORAGE_KEY))
    expect(raw.schemaVersion).toBe(SCHEMA_VERSION)
    expect(Array.isArray(raw.events)).toBe(true)
  })
})
