// Proves the track screen renders the right state for each phase of a game, and above all
// that the outcome controls are genuinely disabled during a side-out rather than merely
// ignoring taps.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'
import { view } from '../../src/ui/screens/track.js'
import { build, roster, turn } from '../helpers.js'

const { OUT, IN_POINT } = E.OUTCOME

const baseUi = { tab: 'track', scope: 'match', pickerOpen: false, confirmingEndMatch: false, confirmingRemoveId: null }

function render(state, overrides = {}) {
  const store = { canUndo: () => overrides.canUndo ?? true }
  return view({ state, store, ui: { ...baseUi, ...overrides } })
}

describe('before there is anything to track', () => {
  it('sends the operator to the roster when no players exist', () => {
    const { screen, dock } = render(build())
    expect(screen).toContain('No players yet')
    expect(screen).toContain('data-tab="roster"')
    expect(dock).toBe('')
  })

  it('offers to start a game once a roster exists', () => {
    const { screen, dock } = render(build(roster(3)))
    expect(screen).toContain('Start game')
    expect(screen).toContain('data-action="start-game"')
    expect(dock).toBe('')
  })
})

describe('during a match', () => {
  const started = build(roster(3), E.startGame('g1'))

  it('names the match and its points on serve', () => {
    const { screen } = render(build(roster(3), E.startGame('g1'), turn('p1', 2)))
    expect(screen).toContain('Match 1 of 3')
    expect(screen).toContain('points on serve')
    expect(screen).toContain('<b>2</b>')
  })

  it('shows no target badge below the target', () => {
    expect(render(started).screen).not.toContain('target-badge')
  })

  it('shows an advisory badge once the target is reached, without ending the match', () => {
    const events = [roster(3), E.startGame('g1'), E.selectServer('p1')]
    for (let i = 0; i < 21; i += 1) events.push(E.recordServe(IN_POINT))
    const { screen, dock } = render(build(events))

    expect(screen).toContain('21 reached — win by 2')
    expect(screen).toContain('data-action="end-match"')
    expect(dock).toContain('data-enabled="true"') // recording continues
  })

  it('asks for confirmation before ending a match', () => {
    expect(render(started).screen).not.toContain('End match?')
    expect(render(started).screen).toContain('End match')
    expect(render(started, { confirmingEndMatch: true }).screen).toContain('End match?')
  })
})

describe('side-out state', () => {
  const sideOut = build(roster(3), E.startGame('g1'), E.selectServer('p1'), E.recordServe(OUT))

  it('disables the outcome controls rather than ignoring taps (FR-022)', () => {
    expect(render(sideOut).dock).toContain('data-enabled="false"')
  })

  it('says plainly that a server must be chosen', () => {
    const { dock } = render(sideOut)
    expect(dock).toContain('side-out')
    expect(dock).toContain('Side out')
    expect(dock).toContain('Select the next server')
  })

  it('shows the picker without the operator having to open it', () => {
    expect(render(sideOut).dock).toContain('data-action="select-server"')
  })
})

describe('while a player is serving', () => {
  const serving = build(roster(3), E.startGame('g1'), E.selectServer('p1'), E.recordServe(IN_POINT))

  it('enables the outcome controls', () => {
    expect(render(serving).dock).toContain('data-enabled="true"')
  })

  it('names the server', () => {
    const { dock } = render(serving)
    expect(dock).toContain('Now serving')
    expect(dock).toContain('Player 1')
  })

  it('collapses the picker to a change control to keep the thumb zone clear', () => {
    const { dock } = render(serving)
    expect(dock).toContain('data-action="toggle-picker"')
    expect(dock).not.toContain('picker-grid')
  })

  it('reopens the picker on request', () => {
    expect(render(serving, { pickerOpen: true }).dock).toContain('picker-grid')
  })

  it('offers all three outcomes', () => {
    const { dock } = render(serving)
    for (const outcome of [OUT, E.OUTCOME.IN_NO_POINT, IN_POINT]) {
      expect(dock).toContain(`data-outcome="${outcome}"`)
    }
  })

  it('disables undo when there is nothing left to undo', () => {
    expect(render(serving, { canUndo: false }).dock).toMatch(/data-action="undo"[^>]*disabled/)
  })
})

describe('after the third match', () => {
  it('reports the game complete and offers a fresh one', () => {
    const state = build(
      roster(2), E.startGame('g1'),
      turn('p1', 1), E.endMatch(),
      turn('p1', 1), E.endMatch(),
      turn('p1', 1), E.endMatch(),
    )
    const { screen } = render(state)
    expect(screen).toContain('Game complete')
    expect(screen).toContain('Start a new game')
    expect(screen).toContain('Game totals')
  })
})

describe('escaping', () => {
  it('does not render a player name as markup in the picker', () => {
    const state = build([E.addPlayer('p1', '<b>x</b>', '<7>')], E.startGame('g1'))
    const { dock } = render(state)
    expect(dock).not.toContain('<b>x</b>')
    expect(dock).toContain('&lt;b&gt;')
  })
})
