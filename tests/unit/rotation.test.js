// Proves the rotation picks the right server without being asked, and -- the part that
// matters most -- that the advance is part of the serve transition rather than an event,
// so one undo reverses one operator action.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'
import {
  replay, rejectionReason, currentMatch, openTurn,
  nextRotationPosition, nextRotationPlayerId, lineupPositionOf, currentLineup,
} from '../../src/domain/reducer.js'
import { activeServerId, matchStats } from '../../src/domain/stats.js'
import { build, roster } from '../helpers.js'

const { OUT, IN_POINT, IN_NO_POINT } = E.OUTCOME
const SIX = ['p1', 'p2', 'p3', 'p4', 'p5', 'p6']

/** The event log for: nine on the roster, a game underway, six on court, p1 serving. */
function logInPlay(...extra) {
  return [...roster(9), E.startGame('g1'), E.setLineup(SIX), E.selectServer('p1'), ...extra.flat(Infinity)]
}

/** Nine on the roster, a game underway, six on court, and p1 serving first. */
function inPlay(extra = []) {
  return replay(logInPlay(extra))
}

/** Ends the current turn with a non-point serve. */
const sideOut = (outcome = OUT) => E.recordServe(outcome)

describe('setting a lineup', () => {
  it('records six players in serving order', () => {
    const state = build(roster(9), E.startGame('g1'), E.setLineup(SIX))
    expect(currentLineup(state)).toEqual(SIX)
  })

  it('refuses a lineup that is not exactly six', () => {
    const started = build(roster(9), E.startGame('g1'))
    expect(rejectionReason(started, E.setLineup(['p1', 'p2']))).toMatch(/exactly 6/)
    expect(rejectionReason(started, E.setLineup([...SIX, 'p7']))).toMatch(/exactly 6/)
  })

  it('refuses a player holding two positions', () => {
    const started = build(roster(9), E.startGame('g1'))
    expect(rejectionReason(started, E.setLineup(['p1', 'p1', 'p2', 'p3', 'p4', 'p5']))).toBeTruthy()
  })

  it('refuses a player who is not on the roster', () => {
    const started = build(roster(9), E.startGame('g1'))
    expect(rejectionReason(started, E.setLineup(['p1', 'p2', 'p3', 'p4', 'p5', 'ghost']))).toBeTruthy()
  })

  it('refuses a change once the match has recorded a serve (FR-016)', () => {
    const playing = inPlay([E.recordServe(IN_POINT)])
    expect(rejectionReason(playing, E.setLineup(['p4', 'p5', 'p6', 'p7', 'p8', 'p9']))).toMatch(/Substitute/)
  })

  it('refuses a lineup with no match in progress', () => {
    expect(rejectionReason(build(roster(9)), E.setLineup(SIX))).toBeTruthy()
  })

  it('carries the lineup into the next match, editable before the first serve (FR-012)', () => {
    const state = build(roster(9), E.startGame('g1'), E.setLineup(SIX), E.selectServer('p1'), sideOut(), E.endMatch())
    expect(currentMatch(state).index).toBe(1)
    expect(currentLineup(state)).toEqual(SIX)
    expect(rejectionReason(state, E.setLineup(['p4', 'p5', 'p6', 'p7', 'p8', 'p9']))).toBeNull()
  })
})

describe('advancing the rotation', () => {
  it('hands the serve to the next player when a turn ends (FR-018)', () => {
    const state = inPlay([sideOut()])
    expect(activeServerId(state)).toBe('p2')
  })

  it('does not advance while the server keeps winning points (FR-020 of release 001)', () => {
    const state = inPlay([E.recordServe(IN_POINT), E.recordServe(IN_POINT)])
    expect(activeServerId(state)).toBe('p1')
  })

  it('advances on a serve that lands in but wins no point', () => {
    expect(activeServerId(inPlay([sideOut(IN_NO_POINT)]))).toBe('p2')
  })

  it('serves all six in lineup order from outcome taps alone (SC-003)', () => {
    const served = []
    const log = logInPlay()
    for (let turn = 0; turn < 6; turn += 1) {
      served.push(activeServerId(replay(log)))
      log.push(sideOut())
    }
    expect(served).toEqual(SIX)
  })

  it('wraps from the last position back to the first (FR-019)', () => {
    const log = logInPlay()
    for (let turn = 0; turn < 6; turn += 1) log.push(sideOut())
    expect(activeServerId(replay(log))).toBe('p1')
  })

  it('does nothing when the match has no lineup (FR-025)', () => {
    const state = build(roster(9), E.startGame('g1'), E.selectServer('p1'), sideOut())
    expect(activeServerId(state)).toBeNull()
    expect(openTurn(currentMatch(state))).toBeNull()
  })

  it('stops advancing once the lineup is cleared', () => {
    const state = inPlay([sideOut(), E.clearLineup(), sideOut()])
    expect(activeServerId(state)).toBeNull()
  })

  it('leaves the newly opened turn empty until a serve is recorded', () => {
    const open = openTurn(currentMatch(inPlay([sideOut()])))
    expect(open.serves).toEqual([])
    expect(open.playerId).toBe('p2')
  })
})

describe('overriding the rotation', () => {
  it('makes the chosen player the server (FR-021)', () => {
    const state = inPlay([sideOut(), E.selectServer('p5')])
    expect(activeServerId(state)).toBe('p5')
  })

  it('continues the rotation from that player\'s position (FR-022)', () => {
    const state = inPlay([sideOut(), E.selectServer('p5'), sideOut()])
    expect(activeServerId(state)).toBe('p6')
  })

  it('discards the empty turn the advance had opened', () => {
    const state = inPlay([sideOut(), E.selectServer('p5')])
    const turns = currentMatch(state).turns
    expect(turns.filter((turn) => turn.serves.length === 0 && !turn.isOpen)).toHaveLength(0)
    expect(turns.map((turn) => turn.playerId)).toEqual(['p1', 'p5'])
  })
})

describe('a server from outside the lineup', () => {
  it('is recorded, not refused (FR-023)', () => {
    const state = inPlay([sideOut(), E.selectServer('p9'), E.recordServe(IN_POINT)])
    const turn = currentMatch(state).turns.at(-1)
    expect(turn.playerId).toBe('p9')
    expect(turn.serves).toHaveLength(1)
  })

  it('is marked, so the operator can reconcile it', () => {
    const turn = currentMatch(inPlay([sideOut(), E.selectServer('p9')])).turns.at(-1)
    expect(turn.isOffLineup).toBe(true)
  })

  it('takes over the position that was due, rather than leaving it pending', () => {
    const turn = currentMatch(inPlay([sideOut(), E.selectServer('p9')])).turns.at(-1)
    expect(turn.lineupPosition).toBe(1)
  })

  it('lets the order carry on without lagging by one (FR-023)', () => {
    const state = inPlay([sideOut(), E.selectServer('p9'), sideOut()])
    expect(activeServerId(state)).toBe('p3')
  })

  it('is not marked when the server is in the lineup', () => {
    expect(currentMatch(inPlay()).turns[0].isOffLineup).toBe(false)
  })
})

describe('undo across an automatic advance', () => {
  it('reverses the serve and the advance together (FR-024, SC-011)', () => {
    const log = logInPlay()
    const beforeJson = JSON.stringify(replay(log))

    const after = [...log, sideOut()]
    expect(activeServerId(replay(after))).toBe('p2')

    // One operator action was taken, so popping one event must undo all of it --
    // the serve and the advance it caused.
    const undone = replay(after.slice(0, -1))
    expect(JSON.stringify(undone)).toBe(beforeJson)
    expect(activeServerId(undone)).toBe('p1')
  })

  it('reverses a whole side-out sequence one action at a time', () => {
    const log = logInPlay(E.recordServe(IN_POINT), sideOut())
    expect(activeServerId(replay(log))).toBe('p2')
    expect(activeServerId(replay(log.slice(0, -1)))).toBe('p1')
    expect(activeServerId(replay(log.slice(0, -2)))).toBe('p1')
  })
})

describe('rotation readers', () => {
  it('reports the next position and player', () => {
    const match = currentMatch(inPlay([sideOut()]))
    expect(nextRotationPosition(match)).toBe(2)
    expect(nextRotationPlayerId(match)).toBe('p3')
  })

  it('reports a player\'s position, or null when they are not on court', () => {
    const match = currentMatch(inPlay())
    expect(lineupPositionOf(match, 'p4')).toBe(3)
    expect(lineupPositionOf(match, 'p9')).toBeNull()
  })

  it('reports nothing for a match with no lineup', () => {
    const match = currentMatch(build(roster(9), E.startGame('g1')))
    expect(nextRotationPosition(match)).toBeNull()
    expect(nextRotationPlayerId(match)).toBeNull()
  })
})

describe('every turn carries who was on court', () => {
  it('snapshots the lineup when the turn opens', () => {
    const turn = currentMatch(inPlay()).turns[0]
    expect(turn.lineupSnapshot).toEqual(SIX)
    expect(turn.lineupPosition).toBe(0)
  })

  it('records no snapshot when the match has no lineup', () => {
    const state = build(roster(9), E.startGame('g1'), E.selectServer('p1'))
    const turn = currentMatch(state).turns[0]
    expect(turn.lineupSnapshot).toBeNull()
    expect(turn.lineupPosition).toBeNull()
  })
})

describe('rotating out after five serves', () => {
  const SIX_UP = ['p1', 'p2', 'p3', 'p4', 'p5', 'p6']
  const inPlay = (...extra) => replay([
    ...roster(9), E.startGame('g1'), E.setLineup(SIX_UP), E.selectServer('p1'), ...extra.flat(Infinity),
  ])

  const point = () => E.recordServe(IN_POINT)

  it('is what a run of points used to break', () => {
    // Four points: still serving, because the league allows five.
    expect(activeServerId(inPlay(point(), point(), point(), point()))).toBe('p1')
  })

  it('hands the serve on once the fifth is taken, even when it won the point', () => {
    expect(activeServerId(inPlay(point(), point(), point(), point(), point()))).toBe('p2')
  })

  it('keeps all five serves with the player who took them', () => {
    const state = inPlay(point(), point(), point(), point(), point())
    const first = currentMatch(state).turns[0]
    expect(first.serves).toHaveLength(5)
    expect(first.playerId).toBe('p1')
    expect(first.isOpen).toBe(false)
  })

  it('still ends a turn early on a serve that wins no point', () => {
    expect(activeServerId(inPlay(point(), E.recordServe(OUT)))).toBe('p2')
  })

  it('carries on round the order', () => {
    const five = [point(), point(), point(), point(), point()]
    expect(activeServerId(inPlay(five, five))).toBe('p3')
  })

  it('records a referee miscount as a second turn, losing no serve', () => {
    // Five taken, the rotation moves on, but the referee lets p1 serve again.
    const state = inPlay(point(), point(), point(), point(), point(), E.selectServer('p1'), point())
    const mine = currentMatch(state).turns.filter((turn) => turn.playerId === 'p1')

    expect(mine).toHaveLength(2)
    expect(mine[0].serves).toHaveLength(5)
    expect(mine[1].serves).toHaveLength(1)
    expect(matchStats(currentMatch(state)).get('p1').serves).toBe(6)
  })

  it('is undone in one step, like any other serve', () => {
    const log = [...roster(9), E.startGame('g1'), E.setLineup(SIX_UP), E.selectServer('p1'),
      point(), point(), point(), point()]
    const before = JSON.stringify(replay(log))

    const after = [...log, point()]
    expect(activeServerId(replay(after))).toBe('p2')

    expect(JSON.stringify(replay(after.slice(0, -1)))).toBe(before)
    expect(activeServerId(replay(after.slice(0, -1)))).toBe('p1')
  })

  it('does nothing without a lineup, since there is no next server to move to', () => {
    const manual = replay([...roster(9), E.startGame('g1'), E.selectServer('p1'),
      point(), point(), point(), point(), point()])
    expect(activeServerId(manual)).toBe('p1')
  })

  it('leaves games recorded before the rule existed exactly as they were', () => {
    // A START_GAME without the field is how every earlier log looks.
    const legacy = replay([
      ...roster(9),
      { t: 'START_GAME', id: 'g1', seasonId: 'season-1' },
      E.setLineup(SIX_UP), E.selectServer('p1'),
      point(), point(), point(), point(), point(), point(),
    ])
    const first = currentMatch(legacy).turns[0]

    expect(first.serves).toHaveLength(6)
    expect(activeServerId(legacy)).toBe('p1')
  })
})
