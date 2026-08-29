// @vitest-environment jsdom
//
// Three things the operator reported from the court, driven through the real UI: the
// five-serve alert, throwing a game away from the end-match panel, and correcting a game
// that is no longer the one being tracked.
//
// The steps run in order and share state on purpose: it is one journey.
import { describe, it, expect, beforeAll } from 'vitest'
import { appShell } from '../helpers.js'

const PAST_TAP_GUARD = 320
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

const click = (selector) => document.querySelector(selector).click()
const screenText = () => document.getElementById('screen').textContent
const overlayText = () => document.getElementById('overlay').textContent
const overlayHtml = () => document.getElementById('overlay').innerHTML
const events = () => JSON.parse(window.localStorage.getItem('vbtracking.eventlog')).events

function addPlayer(number, name) {
  const form = document.getElementById('add-player-form')
  form.querySelector('[name="number"]').value = number
  form.querySelector('[name="name"]').value = name
  form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))
}

/** One serve, waiting out the repeat-tap guard the app applies to the outcome controls. */
async function serve(outcome) {
  await sleep(PAST_TAP_GUARD)
  click(`[data-action="serve"][data-outcome="${outcome}"]`)
}

beforeAll(async () => {
  window.localStorage.clear()
  document.body.innerHTML = appShell()
  await import('../../src/ui/app.js')

  click('[data-tab="roster"]')
  addPlayer('1', 'Ana')
  addPlayer('2', 'Bea')
  click('[data-tab="track"]')
  click('[data-action="start-game"]')
})

describe('the five-serve alert', () => {
  it('says nothing for the first four serves', async () => {
    // Two players is fewer than a lineup needs, so servers are picked by hand throughout.
    click('[data-action="select-server"][data-id]')

    for (let i = 0; i < 4; i += 1) await serve('IN_POINT')
    expect(overlayHtml()).toBe('')
  })

  it('covers the screen on the fifth', async () => {
    await serve('IN_POINT')
    expect(overlayText()).toContain('Rotate')
    expect(overlayText()).toContain('Ana')
    expect(overlayText()).toContain('has served 5')
  })

  it('names no next server when there is no order to advance', () => {
    expect(overlayText()).toContain('Pick the next server')
  })

  it('clears on a tap, and does not come back on the sixth serve', async () => {
    click('.rotate-overlay')
    expect(overlayHtml()).toBe('')

    await serve('IN_POINT')
    expect(overlayHtml()).toBe('')
  })
})

describe('throwing a game away from the end-match panel', () => {
  it('keeps the panel open when the discard is armed', () => {
    click('[data-action="end-match"]')
    expect(screenText()).toContain('How did that match go?')

    click('[data-action="discard-game"]')

    // The bug: arming the discard closed the panel, taking with it the button the second
    // tap had to land on -- so the game could never be thrown away from here at all.
    expect(screenText()).toContain('Throw this game away?')
    expect(document.querySelector('[data-action="discard-game"]')).toBeTruthy()
  })

  it('discards on the second tap and leaves the roster alone', () => {
    click('[data-action="discard-game"]')

    expect(events().some((event) => event.t === 'DISCARD_GAME')).toBe(true)
    expect(screenText()).toContain('Ready to track')

    click('[data-tab="roster"]')
    const names = [...document.querySelectorAll('[data-field="name"]')].map((input) => input.value)
    expect(names).toContain('Ana')
    click('[data-tab="track"]')
  })
})

describe('correcting a game that is no longer the one being tracked', () => {
  beforeAll(async () => {
    // A game to correct: Ana serves three, one of them wrongly recorded as a point.
    click('[data-action="start-game"]')
    click('[data-action="select-server"][data-id]')
    await serve('IN_POINT')
    await serve('IN_POINT')
    await serve('OUT')
    click('[data-action="end-match"]')
    click('[data-action="end-game"]')

    // ...and a second game started on top of it, which is what hid the first one.
    click('[data-action="start-game"]')
  })

  it('reaches the finished game from the season screen', () => {
    click('[data-tab="season"]')
    const rows = document.querySelectorAll('[data-action="open-game"]')
    expect(rows.length).toBeGreaterThan(0)
    rows[0].click()

    expect(screenText()).toContain('Serve record')
  })

  it('shows every turn of it, with its serves', () => {
    click('[data-action="open-record"]')
    expect(screenText()).toContain('Match 1')
    expect(document.querySelectorAll('.record-turn').length).toBe(1)
    expect(screenText()).toContain('3 · 2 in · 2 pt')
  })

  it('corrects a serve by tapping it, and the figures follow', () => {
    click('[data-action="open-turn"]')
    expect(document.querySelectorAll('[data-action="cycle-serve"]').length).toBe(3)

    click('[data-action="cycle-serve"]') // the first serve: point, then in

    expect(events().at(-1).t).toBe('SET_TURN_SERVES')
    expect(events().at(-1).outcomes).toEqual(['IN_NO_POINT', 'IN_POINT', 'OUT'])
    expect(screenText()).toContain('Remove last serve')
  })

  it('adds a serve that was missed, and takes one back', () => {
    click('[data-action="add-serve"]')
    expect(events().at(-1).outcomes).toHaveLength(4)

    click('[data-action="drop-serve"]')
    expect(events().at(-1).outcomes).toHaveLength(3)
  })

  it('moves a turn to the player who actually served it', () => {
    click('[data-action="reassign-turn"]')
    click('[data-action="reassign-to"]')

    expect(events().at(-1).t).toBe('REASSIGN_TURN')
    expect(screenText()).toContain('Bea')
  })

  it('deletes a turn only on a second, deliberate tap', () => {
    click('[data-action="delete-turn"]')
    expect(events().at(-1).t).not.toBe('DELETE_TURN')
    expect(screenText()).toContain('Delete this whole turn?')

    click('[data-action="delete-turn"]')
    expect(events().at(-1).t).toBe('DELETE_TURN')
    expect(document.querySelectorAll('.record-turn').length).toBe(0)
  })

  it('undoes the correction like any other action', () => {
    click('[data-action="close-record"]')
    click('[data-action="close-game"]')
    click('[data-tab="track"]')
    click('[data-action="undo"]')

    expect(events().at(-1).t).not.toBe('DELETE_TURN')
  })

  it('never touched the game being tracked now', () => {
    expect(screenText()).toContain('Match 1 of 3')
  })
})
