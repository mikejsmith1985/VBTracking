// Proves undo restores state exactly, leaves no empty turn behind, and can never
// reach backwards into a match that has already been ended.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'
import { currentMatch } from '../../src/domain/reducer.js'
import { matchStats, activeServerId, undoableCount } from '../../src/domain/stats.js'
import { createStore } from '../../src/state/store.js'
import { memoryPersistence, roster, turn } from '../helpers.js'

const { OUT, IN_POINT } = E.OUTCOME

/** A store with three players and a game underway. */
function startedStore() {
  const store = createStore(memoryPersistence())
  for (const event of [...roster(3), E.startGame('g1')]) store.dispatch(event)
  return store
}

describe('dispatch', () => {
  it('appends an accepted event', () => {
    const store = startedStore()
    const before = store.getEvents().length
    expect(store.dispatch(E.selectServer('p1')).accepted).toBe(true)
    expect(store.getEvents()).toHaveLength(before + 1)
  })

  it('does not append a rejected event, and explains why', () => {
    const store = startedStore()
    const before = store.getEvents().length
    const result = store.dispatch(E.recordServe(IN_POINT)) // no server selected
    expect(result.accepted).toBe(false)
    expect(result.reason).toBeTruthy()
    expect(store.getEvents()).toHaveLength(before)
  })

  it('notifies subscribers', () => {
    const store = startedStore()
    let calls = 0
    const unsubscribe = store.subscribe(() => { calls += 1 })
    store.dispatch(E.selectServer('p1'))
    expect(calls).toBe(1)
    unsubscribe()
    store.dispatch(E.recordServe(IN_POINT))
    expect(calls).toBe(1)
  })
})

describe('undo', () => {
  it('restores every statistic exactly (FR-041)', () => {
    const store = startedStore()
    for (const event of turn('p1', 2)) store.dispatch(event)
    const snapshot = JSON.stringify(store.getState())

    for (const event of [E.selectServer('p2'), E.recordServe(IN_POINT), E.recordServe(OUT)]) {
      store.dispatch(event)
    }
    expect(JSON.stringify(store.getState())).not.toBe(snapshot)

    store.undo()
    store.undo()
    store.undo()
    expect(JSON.stringify(store.getState())).toBe(snapshot)
  })

  it('restores turn boundaries and colours, not just counts (FR-041)', () => {
    const store = startedStore()
    for (const event of [...turn('p1', 1), ...turn('p2', 1)]) store.dispatch(event)
    const turnsBefore = JSON.stringify(currentMatch(store.getState()).turns)

    store.dispatch(E.selectServer('p3'))
    store.dispatch(E.recordServe(IN_POINT))
    store.undo()
    store.undo()

    expect(JSON.stringify(currentMatch(store.getState()).turns)).toBe(turnsBefore)
  })

  it('leaves no empty turn after undoing a server selection (FR-042)', () => {
    const store = startedStore()
    for (const event of turn('p1', 1)) store.dispatch(event)
    store.dispatch(E.selectServer('p2'))
    store.undo()

    const turns = currentMatch(store.getState()).turns
    expect(turns).toHaveLength(1)
    expect(turns.every((each) => each.serves.length > 0)).toBe(true)
    expect(activeServerId(store.getState())).toBeNull()
  })

  it('returns the active server to the previous player when a serve is undone', () => {
    const store = startedStore()
    store.dispatch(E.selectServer('p1'))
    store.dispatch(E.recordServe(IN_POINT))
    store.dispatch(E.recordServe(OUT))
    expect(activeServerId(store.getState())).toBeNull()

    store.undo()
    expect(activeServerId(store.getState())).toBe('p1')
    expect(matchStats(currentMatch(store.getState())).get('p1')).toMatchObject({ serves: 1, points: 1 })
  })

  it('cannot reach into an ended match (FR-043)', () => {
    const store = startedStore()
    for (const event of turn('p1', 2)) store.dispatch(event)
    store.dispatch(E.endMatch())

    expect(store.canUndo()).toBe(false)
    expect(store.undo()).toEqual({ undone: false })

    const first = store.getState().games[0].matches[0]
    expect(first.status).toBe('ended')
    expect(first.turns[0].serves).toHaveLength(3)
  })

  it('is a no-op with nothing to undo', () => {
    const store = createStore(memoryPersistence())
    expect(store.canUndo()).toBe(false)
    expect(store.undo()).toEqual({ undone: false })
    expect(store.getEvents()).toHaveLength(0)
  })

  it('persists the shortened log', () => {
    const persistence = memoryPersistence()
    const store = createStore(persistence)
    store.dispatch(E.addPlayer('p1', 'Rivera', '7'))
    store.dispatch(E.addPlayer('p2', 'Okafor', '3'))
    store.undo()
    expect(persistence.load().events).toHaveLength(1)
  })
})

describe('undoable depth', () => {
  it('counts only events after the last ended match (FR-043)', () => {
    const events = [
      ...roster(2),
      E.startGame('g1'),
      ...turn('p1', 1),
      E.endMatch(),
      E.selectServer('p2'),
      E.recordServe(IN_POINT),
    ]
    expect(undoableCount(events)).toBe(2)
  })

  it('counts every event when no match has ended yet', () => {
    const events = [...roster(2), E.startGame('g1')]
    expect(undoableCount(events)).toBe(events.length)
  })
})

describe('storage failure', () => {
  it('keeps the event in memory when a save fails (FR-058)', () => {
    const failing = {
      load: () => ({ events: [], status: 'ok' }),
      save: () => ({ ok: false }),
      requestPersistent: async () => false,
    }
    const store = createStore(failing)
    expect(store.dispatch(E.addPlayer('p1', 'Rivera', '7')).accepted).toBe(true)
    expect(store.getState().roster).toHaveLength(1)
    expect(store.storageStatus()).toBe('unavailable')
  })
})
