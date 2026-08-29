// Lineup setup and review. Proves the setup step appears only when it is useful, blocks an
// incomplete order, and turns read-only once the match has started.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'
import { currentMatch } from '../../src/domain/reducer.js'
import { needsSetup, setupView, reviewView } from '../../src/ui/screens/lineup.js'
import { build, roster } from '../helpers.js'

const SIX = ['p1', 'p2', 'p3', 'p4', 'p5', 'p6']

function context(state, ui = {}) {
  return { state, store: { canUndo: () => false }, ui: { lineupDraft: null, ...ui } }
}

describe('needsSetup', () => {
  it('is true for a fresh match with a full enough roster', () => {
    const state = build(roster(9), E.startGame('g1'))
    expect(needsSetup(currentMatch(state), state.roster)).toBe(true)
  })

  it('is false once a lineup is set', () => {
    const state = build(roster(9), E.startGame('g1'), E.setLineup(SIX))
    expect(needsSetup(currentMatch(state), state.roster)).toBe(false)
  })

  it('is false with fewer than six players -- the app must still work at practice', () => {
    const state = build(roster(4), E.startGame('g1'))
    expect(needsSetup(currentMatch(state), state.roster)).toBe(false)
  })

  it('is false once the match has recorded a serve', () => {
    const state = build(roster(9), E.startGame('g1'), E.selectServer('p1'), E.recordServe(E.OUTCOME.OUT))
    expect(needsSetup(currentMatch(state), state.roster)).toBe(false)
  })

  it('is false when there is no match', () => {
    expect(needsSetup(null, roster(9))).toBe(false)
  })
})

describe('setupView', () => {
  const state = build(roster(9), E.startGame('g1'))
  const match = currentMatch(state)

  it('asks for six and says how many are left', () => {
    const html = setupView(context(state), match)
    expect(html).toContain('Serving order')
    expect(html).toContain('Choose 6 more')
  })

  it('blocks confirmation until six are chosen', () => {
    const partial = setupView(context(state, { lineupDraft: ['p1', 'p2'] }), match)
    expect(partial).toMatch(/data-action="confirm-lineup"[^>]*disabled/)
    expect(partial).toContain('2 of 6 chosen')
  })

  it('enables confirmation at six', () => {
    const full = setupView(context(state, { lineupDraft: SIX }), match)
    expect(full).not.toMatch(/data-action="confirm-lineup"[^>]*disabled/)
    expect(full).toContain('Use this order')
  })

  it('numbers the slots in serving order', () => {
    const html = setupView(context(state, { lineupDraft: SIX }), match)
    for (const slot of ['1', '2', '3', '4', '5', '6']) expect(html).toContain(`chip-slot">${slot}<`)
  })

  it('offers only players not already chosen', () => {
    const html = setupView(context(state, { lineupDraft: SIX }), match)
    expect(html).toContain('data-action="choose-lineup"')
    expect(html.split('data-action="choose-lineup"').length - 1).toBe(3) // nine less six
  })

  it('lets a chosen player be taken back out', () => {
    expect(setupView(context(state, { lineupDraft: SIX }), match)).toContain('data-action="unchoose-lineup"')
  })

  it('always offers a way to skip', () => {
    expect(setupView(context(state), match)).toContain('data-action="skip-lineup"')
  })
})

describe('reviewView', () => {
  const state = build(roster(9), E.startGame('g1'), E.setLineup(SIX), E.selectServer('p1'), E.recordServe(E.OUTCOME.OUT))
  const match = currentMatch(state)

  it('marks who serves next', () => {
    const html = reviewView(context(state), match)
    expect(html).toContain('is-next')
    expect(html).toContain('serves next')
  })

  it('explains that a mid-match change is a substitution (FR-016)', () => {
    expect(reviewView(context(state), match)).toContain('substitute')
  })

  it('offers no way to reorder', () => {
    const html = reviewView(context(state), match)
    expect(html).not.toContain('data-action="choose-lineup"')
    expect(html).not.toContain('data-action="unchoose-lineup"')
  })

  it('shows an emptied slot rather than silently refilling it', () => {
    const removed = build(
      roster(9), E.startGame('g1'), E.setLineup(SIX), E.removePlayer('p3'),
    )
    expect(reviewView(context(removed), currentMatch(removed))).toContain('Empty')
  })

  it('offers a way back and a way to stop using the rotation', () => {
    const html = reviewView(context(state), match)
    expect(html).toContain('data-action="close-lineup"')
    expect(html).toContain('data-action="skip-lineup"')
  })
})
