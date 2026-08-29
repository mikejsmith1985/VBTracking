// Proves a substitution takes the outgoing player's exact slot, the rotation follows it,
// and -- the one that would be easy to get wrong -- serves already taken stay with the
// player who actually took them.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'
import { replay, rejectionReason, currentMatch, currentLineup, openTurn } from '../../src/domain/reducer.js'
import { activeServerId, matchStats, turnsOnCourt, substitutionsFor } from '../../src/domain/stats.js'
import { build, roster } from '../helpers.js'

const { OUT, IN_POINT } = E.OUTCOME
const SIX = ['p1', 'p2', 'p3', 'p4', 'p5', 'p6']

function logInPlay(...extra) {
  return [...roster(9), E.startGame('g1'), E.setLineup(SIX), E.selectServer('p1'), ...extra.flat(Infinity)]
}
const inPlay = (extra = []) => replay(logInPlay(extra))

describe('making a substitution', () => {
  it('puts the incoming player in the outgoing player\'s exact slot (FR-027)', () => {
    const state = inPlay([E.recordServe(OUT), E.substitute('p4', 'p8')])
    expect(currentLineup(state)).toEqual(['p1', 'p2', 'p3', 'p8', 'p5', 'p6'])
  })

  it('leaves every other position alone', () => {
    const before = currentLineup(inPlay([E.recordServe(OUT)]))
    const after = currentLineup(inPlay([E.recordServe(OUT), E.substitute('p4', 'p8')]))
    expect(after.filter((_, index) => index !== 3)).toEqual(before.filter((_, index) => index !== 3))
  })

  it('is used by the rotation when it next reaches that slot (FR-028)', () => {
    const log = logInPlay(E.recordServe(OUT), E.substitute('p4', 'p8'))
    // p2 is serving; run the rotation round to position 3.
    log.push(E.recordServe(OUT), E.recordServe(OUT))
    expect(activeServerId(replay(log))).toBe('p8')
  })

  it('records who came off, who came on, where, and when (FR-036)', () => {
    const state = inPlay([E.recordServe(IN_POINT), E.recordServe(OUT), E.substitute('p4', 'p8')])
    expect(substitutionsFor(currentMatch(state))).toEqual([
      { outPlayerId: 'p4', inPlayerId: 'p8', position: 3, afterTurnOrdinal: 0 },
    ])
  })

  it('allows a player who came off to come back on later (FR-037)', () => {
    const state = inPlay([E.recordServe(OUT), E.substitute('p4', 'p8'), E.substitute('p8', 'p4')])
    expect(currentLineup(state)).toEqual(SIX)
    expect(substitutionsFor(currentMatch(state))).toHaveLength(2)
  })
})

describe('substituting the player who is serving', () => {
  const midTurn = [E.recordServe(IN_POINT), E.recordServe(IN_POINT), E.substitute('p1', 'p8')]

  it('makes the incoming player the server (FR-034)', () => {
    expect(activeServerId(inPlay(midTurn))).toBe('p8')
  })

  it('leaves the serves already taken with the player who took them (FR-029)', () => {
    const state = inPlay(midTurn)
    const stats = matchStats(currentMatch(state))
    expect(stats.get('p1')).toMatchObject({ serves: 2, points: 2 })
    expect(stats.has('p8')).toBe(false) // p8 has not served yet
  })

  it('opens the incoming player\'s turn at the same position', () => {
    const open = openTurn(currentMatch(inPlay(midTurn)))
    expect(open.playerId).toBe('p8')
    expect(open.lineupPosition).toBe(0)
  })

  it('keeps the rotation on track afterwards', () => {
    expect(activeServerId(inPlay([...midTurn, E.recordServe(OUT)]))).toBe('p2')
  })

  it('does not leave an empty turn when the outgoing player had not yet served', () => {
    const state = inPlay([E.substitute('p1', 'p8')])
    const turns = currentMatch(state).turns
    expect(turns).toHaveLength(1)
    expect(turns[0].playerId).toBe('p8')
  })
})

describe('refusing a substitution', () => {
  const playing = inPlay([E.recordServe(OUT)])

  it('when the incoming player is already on court (FR-030)', () => {
    expect(rejectionReason(playing, E.substitute('p4', 'p2'))).toMatch(/already on court/)
  })

  it('when the incoming player is not on the roster (FR-031)', () => {
    expect(rejectionReason(playing, E.substitute('p4', 'ghost'))).toBeTruthy()
  })

  it('when the outgoing player is not on court', () => {
    expect(rejectionReason(playing, E.substitute('p9', 'p8'))).toMatch(/not on court/)
  })

  it('when both are the same player', () => {
    expect(rejectionReason(playing, E.substitute('p4', 'p4'))).toBeTruthy()
  })

  it('when the match has no lineup', () => {
    const noLineup = build(roster(9), E.startGame('g1'))
    expect(rejectionReason(noLineup, E.substitute('p1', 'p8'))).toBeTruthy()
  })

  it('when no match is in progress', () => {
    expect(rejectionReason(build(roster(9)), E.substitute('p1', 'p8'))).toBeTruthy()
  })

  it('by leaving the lineup untouched', () => {
    expect(currentLineup(replay([...logInPlay(E.recordServe(OUT)), E.substitute('p4', 'p2')]))).toEqual(SIX)
  })
})

describe('undoing a substitution', () => {
  it('restores the outgoing player to their position (FR-035)', () => {
    const log = logInPlay(E.recordServe(OUT))
    const before = JSON.stringify(replay(log))

    const after = [...log, E.substitute('p4', 'p8')]
    expect(currentLineup(replay(after))).toContain('p8')

    expect(JSON.stringify(replay(after.slice(0, -1)))).toBe(before)
  })

  it('restores the server when the substitution replaced them', () => {
    const log = logInPlay(E.recordServe(IN_POINT))
    const after = [...log, E.substitute('p1', 'p8')]

    expect(activeServerId(replay(after))).toBe('p8')
    expect(activeServerId(replay(after.slice(0, -1)))).toBe('p1')
  })
})

describe('turns on court', () => {
  it('counts turns a player was in the lineup for, served or not (FR-054)', () => {
    const state = inPlay([E.recordServe(OUT), E.recordServe(OUT), E.recordServe(OUT)])
    const turns = currentMatch(state).turns
    const played = turns.filter((turn) => turn.serves.length > 0).length

    // p6 never served, but was on court for every turn that happened.
    expect(turnsOnCourt(turns, 'p6')).toBe(played)
    expect(played).toBe(3)
  })

  it('does not count a player who sat the match out', () => {
    const state = inPlay([E.recordServe(OUT)])
    expect(turnsOnCourt(currentMatch(state).turns, 'p9')).toBe(0)
  })

  it('stops counting a player once they are substituted off', () => {
    const log = logInPlay(E.recordServe(OUT), E.substitute('p4', 'p8'), E.recordServe(OUT), E.recordServe(OUT))
    const turns = currentMatch(replay(log)).turns

    const played = turns.filter((turn) => turn.serves.length > 0).length
    expect(turnsOnCourt(turns, 'p4')).toBeLessThan(played)
    expect(turnsOnCourt(turns, 'p4') + turnsOnCourt(turns, 'p8')).toBe(played)
  })

  it('counts nothing when the match has no lineup', () => {
    const state = build(roster(9), E.startGame('g1'), E.selectServer('p1'), E.recordServe(OUT))
    expect(turnsOnCourt(currentMatch(state).turns, 'p1')).toBe(0)
  })
})
