// @vitest-environment jsdom
//
// Wiring test for the UI layer. The real app module is loaded against a real DOM and a
// real Storage, and driven the way an operator drives it. This is what proves the screens,
// the store, and the domain are actually connected -- a green domain suite says nothing
// about whether a button is attached to anything.
//
// The steps run in order and share state on purpose: it is one journey through a match.
import { describe, it, expect, beforeAll } from 'vitest'
import { appShell } from '../helpers.js'


// Two serves cannot occur inside the app's repeat-tap guard, so the test waits it out
// rather than defeating it -- the guard is part of what is being verified.
const PAST_TAP_GUARD = 320
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

const click = (selector) => document.querySelector(selector).click()
const screenText = () => document.getElementById('screen').textContent
const dockHtml = () => document.getElementById('dock').innerHTML
const storedEvents = () => JSON.parse(window.localStorage.getItem('vbtracking.eventlog')).events

function addPlayer(number, name) {
  const form = document.getElementById('add-player-form')
  form.querySelector('[name="number"]').value = number
  form.querySelector('[name="name"]').value = name
  form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))
}

beforeAll(async () => {
  window.localStorage.clear()
  document.body.innerHTML = appShell()
  await import('../../src/ui/app.js')
})

describe('a match, driven through the real UI', () => {
  it('opens on the track screen and asks for a roster first', () => {
    expect(screenText()).toContain('No players yet')
    expect(dockHtml()).toBe('')
  })

  it('adds players through the roster form and persists them', () => {
    click('[data-tab="roster"]')
    addPlayer('7', 'Rivera')
    addPlayer('3', 'Okafor')

    expect(screenText()).toContain('2 of 20 players')
    expect(storedEvents().filter((event) => event.t === 'ADD_PLAYER')).toHaveLength(2)
  })

  it('refuses a blank name and says why', () => {
    addPlayer('9', '   ')
    expect(document.getElementById('banner').hidden).toBe(false)
    expect(document.getElementById('banner').textContent).toMatch(/name is required/i)
    expect(screenText()).toContain('2 of 20 players')
  })

  it('starts a game from the track screen', () => {
    click('[data-tab="track"]')
    click('[data-action="start-game"]')
    expect(screenText()).toContain('Match 1 of 3')
  })

  it('begins with the picker in place of the outcome controls', () => {
    expect(dockHtml()).not.toContain('data-outcome=')
    expect(dockHtml()).toContain('chip-grid')
    expect(dockHtml()).toContain('Next server')
  })

  it('swaps in the outcome controls once a server is chosen', () => {
    click('.chip')
    expect(dockHtml()).toContain('data-outcome=')
    expect(dockHtml()).not.toContain('chip-grid')
    expect(dockHtml()).toContain('Now serving')
  })

  it('keeps the same server after a point', async () => {
    click('[data-outcome="IN_POINT"]')
    await sleep(PAST_TAP_GUARD)

    expect(dockHtml()).toContain('Now serving')
    expect(screenText()).toContain('Rivera')
  })

  it('ignores a stray repeat tap on the same control (FR-023)', () => {
    const before = storedEvents().length
    click('[data-outcome="IN_POINT"]')
    click('[data-outcome="IN_POINT"]') // immediate repeat, inside the guard
    expect(storedEvents().length - before).toBe(1)
  })

  it('closes the turn and brings the picker back on a serve that wins no point', async () => {
    await sleep(PAST_TAP_GUARD)
    click('[data-outcome="OUT"]')

    expect(dockHtml()).not.toContain('data-outcome=')
    expect(dockHtml()).toContain('chip-grid')
    expect(dockHtml()).toContain('Next server')
  })

  it('shows the tally with one mark per serve', () => {
    expect(document.querySelectorAll('.turn .mark')).toHaveLength(3)
    expect(screenText()).toContain('3 served · 2 in · 2 pts')
  })

  it('undoes the last serve and puts the server back', () => {
    click('[data-action="undo"]')
    expect(dockHtml()).toContain('Now serving')
    expect(document.querySelectorAll('.turn .mark')).toHaveLength(2)
  })

  it('leaves no empty turn after undoing a bare server selection (FR-042)', () => {
    click('[data-action="toggle-picker"]')
    click('.chip:nth-of-type(2)')
    click('[data-action="undo"]')

    const emptyTurns = [...document.querySelectorAll('.turn')]
      .filter((turn) => turn.querySelectorAll('.mark').length === 0)
    expect(emptyTurns).toHaveLength(0)
  })

  it('reports the same figures on the stats screen', () => {
    click('[data-tab="stats"]')
    expect(screenText()).toContain('Match 1')
    expect(screenText()).toContain('Rivera')
  })

  it('has written every accepted action to storage', () => {
    const kinds = storedEvents().map((event) => event.t)
    expect(kinds).toContain('ADD_PLAYER')
    expect(kinds).toContain('START_GAME')
    expect(kinds).toContain('SELECT_SERVER')
    expect(kinds).toContain('RECORD_SERVE')
  })

  it('offers to discard the game, and says what that costs', () => {
    expect(screenText()).toContain('Discard this game')
    expect(screenText()).toContain('roster is not affected')
  })

  it('does not discard on the first tap', () => {
    click('[data-action="discard-game"]')
    expect(screenText()).toContain('Discard this game?')
    expect(screenText()).toContain('Every serve in all three matches is thrown away')
    expect(storedEvents().some((event) => event.t === 'DISCARD_GAME')).toBe(false)
  })

  it('disarms the confirmation when something else is tapped', () => {
    click('[data-scope="game"]')
    expect(screenText()).not.toContain('Discard this game?')
  })

  it('discards on a deliberate second tap, keeping the roster', () => {
    click('[data-action="discard-game"]')
    click('[data-action="discard-game"]')

    expect(storedEvents().some((event) => event.t === 'DISCARD_GAME')).toBe(true)
    expect(screenText()).toContain('Nothing to show yet')

    click('[data-tab="roster"]')
    expect(screenText()).toContain('2 of 20 players')
  })

  it('lets a fresh game start straight afterwards', () => {
    click('[data-tab="track"]')
    expect(screenText()).toContain('Start game')

    click('[data-action="start-game"]')
    expect(screenText()).toContain('Match 1 of 3')
  })
})
