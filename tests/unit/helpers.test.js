// The test builders are load-bearing: a broken builder silently weakens every suite that
// uses one, so they are checked directly.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'
import { currentMatch } from '../../src/domain/reducer.js'
import { turnStats } from '../../src/domain/stats.js'
import { build, roster, turn, memoryPersistence } from '../helpers.js'

describe('roster builder', () => {
  it('produces the requested number of ADD_PLAYER events with distinct ids', () => {
    const events = roster(3)
    expect(events).toHaveLength(3)
    expect(events.every((event) => event.t === E.EVENT.ADD_PLAYER)).toBe(true)
    expect(new Set(events.map((event) => event.id)).size).toBe(3)
  })
})

describe('turn builder', () => {
  it('produces a selection, the requested points, and one closing serve', () => {
    const events = turn('p1', 2)
    expect(events[0]).toEqual(E.selectServer('p1'))
    expect(events).toHaveLength(4)
    expect(events.at(-1).outcome).toBe(E.OUTCOME.OUT)
  })

  it('honours a different closing outcome', () => {
    expect(turn('p1', 1, E.OUTCOME.IN_NO_POINT).at(-1).outcome).toBe(E.OUTCOME.IN_NO_POINT)
  })

  it('builds a turn whose recorded stats match what was asked for', () => {
    const state = build(roster(1), E.startGame('g1'), turn('p1', 4))
    expect(turnStats(currentMatch(state).turns[0])).toMatchObject({ serves: 5, points: 4 })
  })
})

describe('build', () => {
  it('flattens nested event arrays, so builders can be composed freely', () => {
    const state = build(roster(2), [E.startGame('g1'), [turn('p1', 1)]])
    expect(state.roster).toHaveLength(2)
    expect(currentMatch(state).turns).toHaveLength(1)
  })
})

describe('memoryPersistence', () => {
  it('round-trips events without sharing the caller\'s array', () => {
    const persistence = memoryPersistence()
    const events = [E.addPlayer('p1', 'Rivera', '7')]

    persistence.save(events)
    events.push(E.endMatch())

    expect(persistence.load().events).toHaveLength(1)
  })

  it('starts empty and reports a healthy status', () => {
    expect(memoryPersistence().load()).toEqual({ events: [], status: 'ok' })
  })
})
