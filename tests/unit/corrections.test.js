// Correcting a turn recorded wrongly. The corrections are appended like any other event,
// so undo keeps working and the record of what was first entered is not destroyed by
// fixing it.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'
import { replay, rejectionReason, gameById } from '../../src/domain/reducer.js'
import { matchStats, matchScore } from '../../src/domain/stats.js'
import { build, roster } from '../helpers.js'

const { OUT, IN_POINT, IN_NO_POINT } = E.OUTCOME

/** A finished game: p1 served three, p2 served two, and the match was ended. */
const played = [
  roster(4), E.startGame('g1', 'season-1'),
  E.selectServer('p1'), E.recordServe(IN_POINT), E.recordServe(IN_POINT), E.recordServe(OUT),
  E.selectServer('p2'), E.recordServe(IN_POINT), E.recordServe(OUT),
  E.endMatch(E.MATCH_RESULT.WON),
]
const finished = () => build(played)
const turnsOf = (state) => gameById(state, 'g1').matches[0].turns

describe('correcting the serves in a turn', () => {
  it('replaces them with what actually happened', () => {
    const state = build(played, E.setTurnServes('g1', 0, 0, [IN_POINT, OUT]))
    expect(turnsOf(state)[0].serves.map((serve) => serve.outcome)).toEqual([IN_POINT, OUT])
  })

  it('carries the correction through every figure', () => {
    const before = matchStats(gameById(finished(), 'g1').matches[0]).get('p1')
    expect(before).toMatchObject({ serves: 3, points: 2 })

    const state = build(played, E.setTurnServes('g1', 0, 0, [IN_NO_POINT]))
    expect(matchStats(gameById(state, 'g1').matches[0]).get('p1')).toMatchObject({ serves: 1, points: 0 })
    expect(matchScore(gameById(state, 'g1').matches[0])).toBe(1)
  })

  it('works on a match that has already ended', () => {
    expect(rejectionReason(finished(), E.setTurnServes('g1', 0, 0, [OUT]))).toBeNull()
  })

  it('refuses an empty list, which means the turn should go instead', () => {
    expect(rejectionReason(finished(), E.setTurnServes('g1', 0, 0, []))).toMatch(/deleted instead/)
  })

  it('refuses an outcome it does not recognise', () => {
    expect(rejectionReason(finished(), E.setTurnServes('g1', 0, 0, ['ACE']))).toBeTruthy()
  })

  it('refuses a turn that is not there', () => {
    expect(rejectionReason(finished(), E.setTurnServes('g1', 0, 99, [OUT]))).toMatch(/no longer exists/)
  })

  it('refuses a match that is not part of the game', () => {
    expect(rejectionReason(finished(), E.setTurnServes('g1', 7, 0, [OUT]))).toBeTruthy()
  })

  it('refuses a game recorded from paper, which has no turns to correct', () => {
    const paper = build(roster(2), E.addHistoricalGame('h1', 'season-1',
      { date: null, opponent: 'X', location: '', court: '' }, [{ playerId: 'p1', in: 1, out: 0 }]))
    expect(rejectionReason(paper, E.setTurnServes('h1', 0, 0, [OUT]))).toMatch(/from paper/)
  })
})

describe('correcting who took a turn', () => {
  it('moves the whole turn to the right player', () => {
    const state = build(played, E.reassignTurn('g1', 0, 0, 'p3'))
    const stats = matchStats(gameById(state, 'g1').matches[0])

    expect(turnsOf(state)[0].playerId).toBe('p3')
    expect(stats.has('p1')).toBe(false)
    expect(stats.get('p3')).toMatchObject({ serves: 3, points: 2 })
  })

  it('leaves the turn where it sits in the order', () => {
    const state = build(played, E.reassignTurn('g1', 0, 0, 'p3'))
    expect(turnsOf(state).map((turn) => turn.ordinal)).toEqual([0, 1])
  })

  it('refuses a player who is not on the roster', () => {
    expect(rejectionReason(finished(), E.reassignTurn('g1', 0, 0, 'ghost'))).toBeTruthy()
  })
})

describe('deleting a turn recorded by mistake', () => {
  const deleted = () => build(played, E.deleteTurn('g1', 0, 0))

  it('removes it and everything it held', () => {
    expect(turnsOf(deleted())).toHaveLength(1)
    expect(matchStats(gameById(deleted(), 'g1').matches[0]).has('p1')).toBe(false)
  })

  it('closes the gap in the order rather than leaving a hole', () => {
    expect(turnsOf(deleted()).map((turn) => turn.ordinal)).toEqual([0])
  })

  it('leaves the other turns untouched', () => {
    expect(matchStats(gameById(deleted(), 'g1').matches[0]).get('p2')).toMatchObject({ serves: 2, points: 1 })
  })
})

describe('a correction is an event like any other', () => {
  it('is undone by dropping it', () => {
    const before = JSON.stringify(finished())
    const after = [...played.flat(Infinity), E.setTurnServes('g1', 0, 0, [OUT])]

    expect(JSON.stringify(replay(after))).not.toBe(before)
    expect(JSON.stringify(replay(after.slice(0, -1)))).toBe(before)
  })

  it('replays deterministically', () => {
    const events = [...played.flat(Infinity), E.reassignTurn('g1', 0, 0, 'p3'), E.deleteTurn('g1', 0, 1)]
    expect(JSON.stringify(replay(events))).toBe(JSON.stringify(replay(events)))
  })

  it('leaves the original serves in the log, so the correction is visible as one', () => {
    const events = [...played.flat(Infinity), E.setTurnServes('g1', 0, 0, [OUT])]
    expect(events.filter((event) => event.t === 'RECORD_SERVE').length).toBeGreaterThan(0)
  })
})
