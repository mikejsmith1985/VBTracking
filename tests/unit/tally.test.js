// Proves the tally board renders one mark per serve, colours by turn rather than by
// outcome, flags an over-limit turn, and escapes operator-entered names.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'
import { currentMatch } from '../../src/domain/reducer.js'
import { colorForTurn } from '../../src/domain/palette.js'
import { tallyBoard, turnGroup } from '../../src/ui/components/tally.js'
import { build, roster, turn } from '../helpers.js'

const { OUT, IN_POINT, IN_NO_POINT } = E.OUTCOME

function matchOf(...events) {
  return currentMatch(build(roster(3), E.startGame('g1'), events))
}

/** Counts non-overlapping occurrences of a substring. */
function count(haystack, needle) {
  return haystack.split(needle).length - 1
}

describe('turnGroup', () => {
  it('renders exactly one mark per serve (FR-031)', () => {
    const match = matchOf(turn('p1', 3))
    expect(count(turnGroup(match.turns[0]), 'class="mark ')).toBe(4)
  })

  it('renders nine marks for a nine-serve turn, capping nothing (FR-029)', () => {
    const match = matchOf(turn('p1', 8))
    expect(count(turnGroup(match.turns[0]), 'class="mark ')).toBe(9)
  })

  it('encodes the outcome in the mark class, not the colour (FR-034)', () => {
    const match = matchOf(
      E.selectServer('p1'), E.recordServe(IN_POINT), E.recordServe(IN_NO_POINT),
    )
    const html = turnGroup(match.turns[0])
    expect(html).toContain('mark-point')
    expect(html).toContain('mark-in')
  })

  it('marks an out serve distinctly', () => {
    const match = matchOf(E.selectServer('p1'), E.recordServe(OUT))
    expect(turnGroup(match.turns[0])).toContain('mark-out')
  })

  it('carries the turn colour as a custom property (FR-032)', () => {
    const match = matchOf(turn('p1', 1), turn('p2', 1))
    expect(turnGroup(match.turns[0])).toContain(`--turn-color:${colorForTurn(0)}`)
    expect(turnGroup(match.turns[1])).toContain(`--turn-color:${colorForTurn(1)}`)
  })

  it('shows this turn\'s own serve and serves-in counts (FR-035)', () => {
    const match = matchOf(E.selectServer('p1'), E.recordServe(IN_POINT), E.recordServe(OUT))
    expect(turnGroup(match.turns[0])).toContain('2 · 1 in')
  })

  it('does not flag a turn of exactly five serves', () => {
    const match = matchOf(turn('p1', 4))
    const html = turnGroup(match.turns[0])
    expect(html).not.toContain('over-limit')
    expect(html).not.toContain('⚠')
  })

  it('flags a turn of six or more serves (FR-030)', () => {
    const match = matchOf(turn('p1', 6))
    const html = turnGroup(match.turns[0])
    expect(html).toContain('over-limit')
    expect(html).toContain('⚠')
    expect(count(html, 'class="mark ')).toBe(7)
  })
})

describe('tallyBoard', () => {
  it('invites the operator to pick a server when nothing is recorded', () => {
    expect(tallyBoard(matchOf(), [])).toContain('No serves yet')
  })

  it('renders one row per player who has served, not per roster entry', () => {
    const state = build(roster(3), E.startGame('g1'), turn('p1', 1), turn('p2', 1))
    const html = tallyBoard(currentMatch(state), state.roster)
    expect(count(html, 'class="tally-row"')).toBe(2)
  })

  it('groups a player\'s two turns into one row, keeping both visible', () => {
    const state = build(roster(3), E.startGame('g1'), turn('p1', 1), turn('p2', 1), turn('p1', 2))
    const html = tallyBoard(currentMatch(state), state.roster)
    expect(count(html, 'class="tally-row"')).toBe(2)
    expect(count(html, 'style="--turn-color:')).toBe(3)
  })

  it('shows a player\'s running totals for the match', () => {
    const state = build(roster(2), E.startGame('g1'), turn('p1', 2))
    expect(tallyBoard(currentMatch(state), state.roster)).toContain('3 served · 2 in · 2 pts')
  })

  it('escapes a player name rather than rendering it as markup', () => {
    const state = build(
      [E.addPlayer('p1', '<img src=x onerror=alert(1)>', '7')],
      E.startGame('g1'),
      turn('p1', 1),
    )
    const html = tallyBoard(currentMatch(state), state.roster)
    expect(html).not.toContain('<img')
    expect(html).toContain('&lt;img')
  })

  it('draws nothing for a server whose turn has just opened', () => {
    const state = build(roster(3), E.startGame('g1'), E.selectServer('p1'))
    expect(tallyBoard(currentMatch(state), state.roster)).toContain('No serves yet')
  })

  it('leaves a just-opened turn off the board without hiding the rest', () => {
    const state = build(roster(3), E.startGame('g1'), turn('p1', 1), E.selectServer('p2'))
    const html = tallyBoard(currentMatch(state), state.roster)

    expect(count(html, 'class="tally-row"')).toBe(1)
    expect(count(html, 'style="--turn-color:')).toBe(1)
    expect(html).not.toContain('0 · 0 in')
    expect(html).not.toContain('0 served')
  })

  it('includes a legend so the mark shapes are readable without instruction', () => {
    const state = build(roster(1), E.startGame('g1'), turn('p1', 1))
    const html = tallyBoard(currentMatch(state), state.roster)
    expect(html).toContain('colour = serve turn')
  })
})
