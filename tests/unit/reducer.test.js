// Proves the reducer owns every rule in the spec: roster limits, match lifecycle,
// and serve-turn boundaries. Pure — no DOM, no storage, no clock.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'
import {
  applyEvent,
  replay,
  rejectionReason,
  currentGame,
  currentMatch,
  openTurn,
} from '../../src/domain/reducer.js'
import { build, roster, turn } from '../helpers.js'

const { OUT, IN_POINT, IN_NO_POINT } = E.OUTCOME

describe('roster rules', () => {
  it('adds a player with a name and jersey number (FR-001)', () => {
    const state = build(E.addPlayer('p1', 'Rivera', '7'))
    expect(state.roster).toEqual([{ id: 'p1', name: 'Rivera', number: '7' }])
  })

  it('caps the roster at 20 players (FR-002)', () => {
    const state = build(roster(20), E.addPlayer('p21', 'Extra', '21'))
    expect(state.roster).toHaveLength(20)
    expect(rejectionReason(state, E.addPlayer('p21', 'Extra', '21'))).toMatch(/20/)
  })

  it('rejects a blank name (FR-001)', () => {
    expect(build(E.addPlayer('p1', '   ', '7')).roster).toHaveLength(0)
  })

  it('keeps a jersey number as text so a leading zero survives', () => {
    expect(build(E.addPlayer('p1', 'Bell', '07')).roster[0].number).toBe('07')
  })

  it('keeps recorded serves attached when a player is edited (FR-007)', () => {
    const state = build(
      roster(1),
      E.startGame('g1'),
      turn('p1', 2),
      E.editPlayer('p1', 'Rivera-Smith', '17'),
    )
    expect(state.roster[0]).toEqual({ id: 'p1', name: 'Rivera-Smith', number: '17' })
    expect(currentMatch(state).turns[0].serves).toHaveLength(3)
  })

  it('discards a removed player\'s turns and renumbers what remains (FR-006)', () => {
    const state = build(
      roster(2),
      E.startGame('g1'),
      turn('p1', 1),
      turn('p2', 1),
      E.removePlayer('p1'),
    )
    expect(state.roster).toHaveLength(1)
    const turns = currentMatch(state).turns
    expect(turns).toHaveLength(1)
    expect(turns[0].playerId).toBe('p2')
    expect(turns[0].ordinal).toBe(0)
  })
})

describe('game and match lifecycle', () => {
  it('opens match 1 when a game starts (FR-008)', () => {
    const state = build(roster(1), E.startGame('g1'))
    expect(currentGame(state).matches).toHaveLength(1)
    expect(currentMatch(state)).toMatchObject({ index: 0, status: 'in_progress' })
  })

  it('ends a match and opens the next (FR-012)', () => {
    const state = build(roster(1), E.startGame('g1'), turn('p1', 1), E.endMatch())
    const matches = currentGame(state).matches
    expect(matches[0].status).toBe('ended')
    expect(matches[1]).toMatchObject({ index: 1, status: 'in_progress' })
  })

  it('never opens a fourth match (FR-013)', () => {
    const state = build(
      roster(1),
      E.startGame('g1'),
      turn('p1', 1), E.endMatch(),
      turn('p1', 1), E.endMatch(),
      turn('p1', 1), E.endMatch(),
    )
    const matches = currentGame(state).matches
    expect(matches).toHaveLength(3)
    expect(matches.every((match) => match.status === 'ended')).toBe(true)
    expect(currentMatch(state)).toBeNull()
  })

  it('leaves an ended match untouched by later events (FR-043)', () => {
    const afterFirst = build(roster(2), E.startGame('g1'), turn('p1', 3), E.endMatch())
    const frozen = JSON.stringify(currentGame(afterFirst).matches[0])

    const afterSecond = build(
      roster(2),
      E.startGame('g1'),
      turn('p1', 3), E.endMatch(),
      turn('p2', 2),
    )
    expect(JSON.stringify(currentGame(afterSecond).matches[0])).toBe(frozen)
  })

  it('refuses a serve when no match is in progress (FR-015)', () => {
    const state = build(roster(1))
    expect(rejectionReason(state, E.selectServer('p1'))).toBeTruthy()
  })
})

describe('discarding a game', () => {
  const played = [
    roster(2), E.startGame('g1'),
    turn('p1', 2), E.endMatch(),
    turn('p2', 1),
  ]

  it('removes the game and every serve recorded in it', () => {
    const state = build(played, E.discardGame('g1'))
    expect(state.games).toHaveLength(0)
    expect(currentGame(state)).toBeNull()
    expect(currentMatch(state)).toBeNull()
  })

  it('keeps the roster, which is reused across games', () => {
    const state = build(played, E.discardGame('g1'))
    expect(state.roster).toHaveLength(2)
  })

  it('frees the operator to start a fresh game immediately', () => {
    const state = build(played, E.discardGame('g1'), E.startGame('g2'))
    expect(currentGame(state).id).toBe('g2')
    expect(currentMatch(state)).toMatchObject({ index: 0, status: 'in_progress' })
  })

  it('works on a game that has already been played out in full', () => {
    const state = build(
      roster(1), E.startGame('g1'),
      turn('p1', 1), E.endMatch(),
      turn('p1', 1), E.endMatch(),
      turn('p1', 1), E.endMatch(),
      E.discardGame('g1'),
    )
    expect(state.games).toHaveLength(0)
  })

  it('leaves other games alone', () => {
    const state = build(
      roster(1),
      E.startGame('g1'), turn('p1', 1), E.endMatch(), E.endMatch(), E.endMatch(),
      E.startGame('g2'), turn('p1', 2),
      E.discardGame('g1'),
    )
    expect(state.games.map((game) => game.id)).toEqual(['g2'])
    expect(currentGame(state).id).toBe('g2')
  })

  it('refuses to discard a game that does not exist', () => {
    const state = build(played)
    expect(rejectionReason(state, E.discardGame('nope'))).toBeTruthy()
    expect(build(played, E.discardGame('nope')).games).toHaveLength(1)
  })

  it('is deterministic under replay', () => {
    const events = [...played.flat(Infinity), E.discardGame('g1'), E.startGame('g2')]
    expect(JSON.stringify(replay(events))).toBe(JSON.stringify(replay(events)))
  })
})

describe('serve turn boundaries', () => {
  const started = [roster(3), E.startGame('g1')]

  it('keeps the same server after a point (FR-020)', () => {
    const state = build(started, E.selectServer('p1'), E.recordServe(IN_POINT), E.recordServe(IN_POINT))
    const open = openTurn(currentMatch(state))
    expect(open.playerId).toBe('p1')
    expect(open.serves).toHaveLength(2)
  })

  it('closes the turn on a serve that is out (FR-021)', () => {
    const state = build(started, E.selectServer('p1'), E.recordServe(OUT))
    expect(openTurn(currentMatch(state))).toBeNull()
  })

  it('closes the turn on a serve that is in but wins no point (FR-021)', () => {
    const state = build(started, E.selectServer('p1'), E.recordServe(IN_NO_POINT))
    expect(openTurn(currentMatch(state))).toBeNull()
  })

  it('refuses a serve while no turn is open (FR-022)', () => {
    const state = build(started, E.selectServer('p1'), E.recordServe(OUT))
    expect(rejectionReason(state, E.recordServe(IN_POINT))).toBeTruthy()
    expect(build(started, E.selectServer('p1'), E.recordServe(OUT), E.recordServe(IN_POINT))
      .games[0].matches[0].turns).toHaveLength(1)
  })

  it('closes the previous turn when a different player is selected (FR-026)', () => {
    const state = build(
      started,
      E.selectServer('p1'), E.recordServe(IN_POINT),
      E.selectServer('p2'),
    )
    const turns = currentMatch(state).turns
    expect(turns).toHaveLength(2)
    expect(turns[0]).toMatchObject({ playerId: 'p1', isOpen: false })
    expect(turns[0].serves).toHaveLength(1)
    expect(turns[1]).toMatchObject({ playerId: 'p2', isOpen: true })
  })

  it('never keeps a turn that recorded no serves (FR-027)', () => {
    const state = build(started, E.selectServer('p1'), E.selectServer('p2'), E.recordServe(OUT))
    const turns = currentMatch(state).turns
    expect(turns).toHaveLength(1)
    expect(turns[0].playerId).toBe('p2')
  })

  it('discards an empty open turn when the match ends', () => {
    const state = build(started, turn('p1', 1), E.selectServer('p2'), E.endMatch())
    expect(currentGame(state).matches[0].turns).toHaveLength(1)
  })

  it('counts a player returning to serve as a separate turn (FR-028)', () => {
    const state = build(started, turn('p1', 1), turn('p2', 1), turn('p1', 1))
    const mine = currentMatch(state).turns.filter((each) => each.playerId === 'p1')
    expect(mine).toHaveLength(2)
    expect(mine[0].ordinal).toBe(0)
    expect(mine[1].ordinal).toBe(2)
  })

  it('allows a turn to end on a point when the player is switched', () => {
    const state = build(started, E.selectServer('p1'), E.recordServe(IN_POINT), E.selectServer('p2'))
    const first = currentMatch(state).turns[0]
    expect(first.serves.at(-1).outcome).toBe(IN_POINT)
    expect(first.isOpen).toBe(false)
  })
})

describe('purity', () => {
  it('does not mutate the state it is given (FR-041 depends on this)', () => {
    const before = build(roster(2), E.startGame('g1'), E.selectServer('p1'))
    const snapshot = JSON.stringify(before)
    const after = applyEvent(before, E.recordServe(IN_POINT))
    expect(JSON.stringify(before)).toBe(snapshot)
    expect(after).not.toBe(before)
  })

  it('returns the same state unchanged for a rejected event', () => {
    const before = build(roster(1), E.startGame('g1'))
    expect(applyEvent(before, E.recordServe(IN_POINT))).toBe(before)
  })

  it('replays deterministically', () => {
    const events = [...roster(2), E.startGame('g1'), ...turn('p1', 3), ...turn('p2', 1)]
    expect(JSON.stringify(replay(events))).toBe(JSON.stringify(replay(events)))
  })
})
