// Proves the store's contract: rejected events never reach the log, every accepted change
// is persisted, subscribers are notified once, and a storage failure never costs a serve.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'
import { createStore } from '../../src/state/store.js'
import { memoryPersistence, roster, turn } from '../helpers.js'

const { IN_POINT } = E.OUTCOME

describe('loading', () => {
  it('replays a stored log into state on creation', () => {
    const persistence = memoryPersistence()
    persistence.save([...roster(2), E.startGame('g1'), ...turn('p1', 2)])

    const store = createStore(persistence)
    expect(store.getState().roster).toHaveLength(2)
    expect(store.getState().games[0].matches[0].turns[0].serves).toHaveLength(3)
  })

  it('starts empty when storage holds nothing', () => {
    const store = createStore(memoryPersistence())
    expect(store.getEvents()).toEqual([])
    expect(store.getState()).toEqual({ roster: [], games: [], currentGameId: null })
  })

  it('carries the load status through', () => {
    const corrupt = { load: () => ({ events: [], status: 'corrupt' }), save: () => ({ ok: true }) }
    expect(createStore(corrupt).storageStatus()).toBe('corrupt')
  })
})

describe('event log', () => {
  it('hands out a copy, so a caller cannot append behind the store\'s back', () => {
    const store = createStore(memoryPersistence())
    store.dispatch(E.addPlayer('p1', 'Rivera', '7'))

    store.getEvents().push(E.endMatch())
    expect(store.getEvents()).toHaveLength(1)
  })

  it('persists after every accepted event', () => {
    const persistence = memoryPersistence()
    const store = createStore(persistence)

    store.dispatch(E.addPlayer('p1', 'Rivera', '7'))
    store.dispatch(E.addPlayer('p2', 'Okafor', '3'))

    expect(persistence.load().events).toHaveLength(2)
  })

  it('does not persist a rejected event', () => {
    const persistence = memoryPersistence()
    const store = createStore(persistence)

    store.dispatch(E.addPlayer('p1', 'Rivera', '7'))
    store.dispatch(E.addPlayer('p1', 'Duplicate', '9'))

    expect(persistence.load().events).toHaveLength(1)
  })
})

describe('subscribers', () => {
  it('are notified once per accepted change, with the new state', () => {
    const store = createStore(memoryPersistence())
    const seen = []
    store.subscribe((state) => seen.push(state.roster.length))

    store.dispatch(E.addPlayer('p1', 'Rivera', '7'))
    store.dispatch(E.addPlayer('p2', 'Okafor', '3'))

    expect(seen).toEqual([1, 2])
  })

  it('are not notified for a rejected event', () => {
    const store = createStore(memoryPersistence())
    let calls = 0
    store.subscribe(() => { calls += 1 })

    store.dispatch(E.recordServe(IN_POINT)) // no game, no server
    expect(calls).toBe(0)
  })

  it('stop being notified once unsubscribed', () => {
    const store = createStore(memoryPersistence())
    let calls = 0
    const unsubscribe = store.subscribe(() => { calls += 1 })

    store.dispatch(E.addPlayer('p1', 'Rivera', '7'))
    unsubscribe()
    store.dispatch(E.addPlayer('p2', 'Okafor', '3'))

    expect(calls).toBe(1)
  })
})

describe('storage failure', () => {
  const failing = () => ({
    load: () => ({ events: [], status: 'ok' }),
    save: () => ({ ok: false }),
    requestPersistent: async () => false,
  })

  it('keeps the event in memory and flags storage as unavailable (FR-058)', () => {
    const store = createStore(failing())
    expect(store.dispatch(E.addPlayer('p1', 'Rivera', '7')).accepted).toBe(true)
    expect(store.getState().roster).toHaveLength(1)
    expect(store.storageStatus()).toBe('unavailable')
  })

  it('keeps recording after the failure rather than refusing further serves', () => {
    const store = createStore(failing())
    store.dispatch(E.addPlayer('p1', 'Rivera', '7'))
    store.dispatch(E.startGame('g1'))
    store.dispatch(E.selectServer('p1'))

    expect(store.dispatch(E.recordServe(IN_POINT)).accepted).toBe(true)
    expect(store.getState().games[0].matches[0].turns[0].serves).toHaveLength(1)
  })
})

describe('requestPersistent', () => {
  it('resolves false when the adapter offers no such capability', async () => {
    const bare = { load: () => ({ events: [], status: 'ok' }), save: () => ({ ok: true }) }
    await expect(createStore(bare).requestPersistent()).resolves.toBe(false)
  })
})
