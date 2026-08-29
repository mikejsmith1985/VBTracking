// Proves the roster shows exactly as many rows as there are players -- the placeholder-row
// rule the operator asked for -- and that a destructive removal states its consequence.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'
import { view } from '../../src/ui/screens/roster.js'
import { build, roster } from '../helpers.js'

const baseUi = { tab: 'roster', scope: 'match', pickerOpen: false, confirmingEndMatch: false, confirmingRemoveId: null }

function render(state, overrides = {}) {
  const store = { canUndo: () => false, pendingSubstitution: () => null, clearSubstitution: () => {} }
  return view({ state, store, ui: { ...baseUi, ...overrides } })
}

/** Counts non-overlapping occurrences of a substring. */
function count(haystack, needle) {
  return haystack.split(needle).length - 1
}

describe('an empty roster', () => {
  it('shows a call to action rather than an empty table', () => {
    const { screen } = render(build())
    expect(screen).toContain('Roster is empty')
    expect(count(screen, 'class="player-row"')).toBe(0)
  })

  it('reports zero of twenty', () => {
    expect(render(build()).screen).toContain('0 of 20 players')
  })
})

describe('a partial roster', () => {
  it('renders exactly one row per player and no placeholders (FR-003)', () => {
    const { screen } = render(build(roster(9)))
    expect(count(screen, 'class="player-row"')).toBe(9)
    expect(screen).toContain('9 of 20 players')
  })

  it('keeps the add form available', () => {
    const { screen } = render(build(roster(9)))
    expect(screen).toContain('id="add-player-form"')
    expect(screen).not.toContain('roster is full')
  })

  it('makes both fields editable in place (FR-005)', () => {
    const { screen } = render(build(roster(1)))
    expect(screen).toContain('data-field="name"')
    expect(screen).toContain('data-field="number"')
  })
})

describe('a full roster', () => {
  const full = render(build(roster(20)))

  it('renders twenty rows', () => {
    expect(count(full.screen, 'class="player-row"')).toBe(20)
  })

  it('disables the add form and says why (FR-002)', () => {
    expect(full.screen).toContain('roster is full')
    expect(full.screen).toMatch(/<button type="submit" disabled/)
  })
})

describe('removing a player', () => {
  it('takes two taps and states what will be lost (FR-006)', () => {
    const state = build(roster(2))
    const playerId = state.roster[0].id

    const first = render(state).screen
    expect(first).toContain('data-action="remove-player"')
    expect(first).not.toContain('Delete?')

    const armed = render(state, { confirmingRemoveId: playerId }).screen
    expect(armed).toContain('Delete?')
    expect(armed).toContain('recorded serves will be discarded')
  })

  it('arms only the row that was tapped', () => {
    const state = build(roster(3))
    const armed = render(state, { confirmingRemoveId: state.roster[1].id }).screen
    expect(count(armed, 'Delete?')).toBe(1)
  })
})

describe('escaping', () => {
  it('renders a hostile name as a value, not as markup', () => {
    const state = build([E.addPlayer('p1', '"><img src=x>', '7')])
    const { screen } = render(state)
    expect(screen).not.toContain('<img')
    expect(screen).toContain('&quot;&gt;&lt;img')
  })
})

describe('the roster screen has no dock', () => {
  it('because nothing on it is used mid-rally', () => {
    expect(render(build(roster(3))).dock).toBe('')
  })
})
