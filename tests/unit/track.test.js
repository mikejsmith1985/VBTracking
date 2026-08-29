// Proves the track screen renders the right state for each phase of a game, and above all
// that the outcome controls are genuinely disabled during a side-out rather than merely
// ignoring taps.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'
import { view } from '../../src/ui/screens/track.js'
import { build, roster, turn } from '../helpers.js'

const { OUT, IN_POINT } = E.OUTCOME

const baseUi = {
  tab: 'track', scope: 'match', pickerOpen: false,
  confirmingEndMatch: false, confirmingRemoveId: null,
  showLineup: false, lineupDraft: null, lineupDismissedFor: 'g1:0',
}

function render(state, overrides = {}) {
  const store = {
    canUndo: () => overrides.canUndo ?? true,
    pendingSubstitution: () => overrides.armed ?? null,
    clearSubstitution: () => {},
  }
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
    expect(dock).toContain('data-outcome=') // recording continues
  })

  it('asks how the match went before ending it (FR-028)', () => {
    const idle = render(started).screen
    expect(idle).toContain('data-action="end-match"')
    expect(idle).not.toContain('How did that match go?')

    const asking = render(started, { confirmingEndMatch: true }).screen
    expect(asking).toContain('How did that match go?')
    expect(asking).toContain('data-result="won"')
    expect(asking).toContain('data-result="lost"')
  })

  it('offers to end without recording a result, rather than forcing a guess', () => {
    const asking = render(started, { confirmingEndMatch: true }).screen
    expect(asking).toContain('data-result="undecided"')
    expect(asking).toContain('End without recording')
  })

  it('offers a way back to playing', () => {
    expect(render(started, { confirmingEndMatch: true }).screen).toContain('data-action="cancel-end-match"')
  })
})

describe('between servers', () => {
  const awaiting = build(roster(3), E.startGame('g1'), E.selectServer('p1'), E.recordServe(OUT))

  it('removes the outcome controls entirely rather than dimming them (FR-022)', () => {
    const { dock } = render(awaiting)
    expect(dock).not.toContain('data-outcome=')
    expect(dock).not.toContain('data-action="serve"')
  })

  it('puts the picker where the outcome controls normally are -- that is the signal', () => {
    const { dock } = render(awaiting)
    expect(dock).toContain('chip-grid')
    expect(dock).toContain('data-action="select-server"')
  })

  it('marks the status row so the label carries a colour cue', () => {
    const { dock } = render(awaiting)
    expect(dock).toContain('awaiting')
    expect(dock).toContain('Next server')
  })

  it('does not offer a change-server control, since no one is serving', () => {
    expect(render(awaiting).dock).not.toContain('data-action="toggle-picker"')
  })

  it('still offers undo', () => {
    expect(render(awaiting).dock).toContain('data-action="undo"')
  })
})

describe('while a player is serving', () => {
  const serving = build(roster(3), E.startGame('g1'), E.selectServer('p1'), E.recordServe(IN_POINT))

  it('shows the outcome controls', () => {
    expect(render(serving).dock).toContain('data-outcome=')
  })

  it('names the server', () => {
    const { dock } = render(serving)
    expect(dock).toContain('Now serving')
    expect(dock).toContain('Player 1')
  })

  it('collapses the picker to a change control to keep the thumb zone clear', () => {
    const { dock } = render(serving)
    expect(dock).toContain('data-action="toggle-picker"')
    expect(dock).not.toContain('chip-grid')
  })

  it('swaps the outcome controls for the picker when changing server, never both', () => {
    const { dock } = render(serving, { pickerOpen: true })
    expect(dock).toContain('chip-grid')
    expect(dock).not.toContain('data-outcome=')
    expect(dock).toContain('Cancel')
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

describe('getting out of a game part-way through', () => {
  const midGame = build(roster(3), E.startGame('g1'), E.selectServer('p1'), E.recordServe(IN_POINT))
  const asking = () => render(midGame, { confirmingEndMatch: true }).screen

  it('offers ending the game where it stands, not only ending the match', () => {
    expect(asking()).toContain('data-action="end-game"')
    expect(asking()).toContain('keep what is recorded')
  })

  it('says what ending keeps', () => {
    expect(asking()).toContain('closes the game where it stands, however many matches were played')
  })

  it('offers throwing the game away, without leaving the tracking screen', () => {
    expect(asking()).toContain('data-action="discard-game"')
  })

  it('takes two taps to throw it away, and states the cost before the second', () => {
    expect(asking()).not.toContain('Throw this game away?')

    const armed = render(midGame, { confirmingEndMatch: true, confirmingDiscardGame: 'g1' }).screen
    expect(armed).toContain('Throw this game away?')
    expect(armed).toContain('Every serve in this game goes with it')
  })

  it('arms the discard against this game, so another cannot be caught by it', () => {
    const other = render(midGame, { confirmingEndMatch: true, confirmingDiscardGame: 'somewhere-else' }).screen
    expect(other).not.toContain('Throw this game away?')
  })

  it('still offers the way back to playing', () => {
    expect(asking()).toContain('data-action="cancel-end-match"')
  })
})
