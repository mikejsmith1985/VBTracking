// Proves event constructors produce plain, serializable objects and that the outcome
// predicates agree with the reducer's definition of a serve that landed in.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'

describe('event constructors', () => {
  it('build plain objects that survive a JSON round trip', () => {
    const events = [
      E.addPlayer('p1', 'Rivera', '7'),
      E.editPlayer('p1', 'Rivera-Smith', '17'),
      E.removePlayer('p1'),
      E.startGame('g1'),
      E.selectServer('p1'),
      E.recordServe(E.OUTCOME.IN_POINT),
      E.endMatch(),
    ]
    expect(JSON.parse(JSON.stringify(events))).toEqual(events)
  })

  it('tag every event with its type', () => {
    expect(E.addPlayer('p1', 'A', '1').t).toBe(E.EVENT.ADD_PLAYER)
    expect(E.recordServe(E.OUTCOME.OUT).t).toBe(E.EVENT.RECORD_SERVE)
    expect(E.endMatch().t).toBe(E.EVENT.END_MATCH)
  })

  it('read nothing from ambient state -- the same call always yields the same event', () => {
    expect(E.recordServe(E.OUTCOME.OUT)).toEqual(E.recordServe(E.OUTCOME.OUT))
    expect(E.endMatch()).toEqual(E.endMatch())
  })
})

describe('constants', () => {
  it('cap the roster at 20 and a game at 3 matches', () => {
    expect(E.MAX_ROSTER).toBe(20)
    expect(E.MATCHES_PER_GAME).toBe(3)
  })

  it('are frozen, so a caller cannot redefine the rules', () => {
    expect(Object.isFrozen(E.OUTCOME)).toBe(true)
    expect(Object.isFrozen(E.EVENT)).toBe(true)
  })

  it('offer exactly three serve outcomes', () => {
    expect(Object.values(E.OUTCOME)).toEqual(['OUT', 'IN_NO_POINT', 'IN_POINT'])
  })
})

describe('isValidOutcome', () => {
  it('accepts the three real outcomes', () => {
    for (const outcome of Object.values(E.OUTCOME)) expect(E.isValidOutcome(outcome)).toBe(true)
  })

  it('rejects anything else', () => {
    for (const bogus of ['ACE', 'in', '', null, undefined, 0]) {
      expect(E.isValidOutcome(bogus)).toBe(false)
    }
  })
})

describe('isServeIn', () => {
  it('counts a point and an in-no-point serve as in', () => {
    expect(E.isServeIn({ outcome: E.OUTCOME.IN_POINT })).toBe(true)
    expect(E.isServeIn({ outcome: E.OUTCOME.IN_NO_POINT })).toBe(true)
  })

  it('does not count an out serve as in', () => {
    expect(E.isServeIn({ outcome: E.OUTCOME.OUT })).toBe(false)
  })
})
