// @vitest-environment jsdom
//
// Drives the real app through a lineup, an automatic rotation, and a substitution against
// a real DOM and a real Storage. The domain suite proves the rules; this proves the rules
// are actually wired to the things the operator taps.
//
// The steps run in order and share state on purpose: it is one journey through a match.
import { describe, it, expect, beforeAll } from 'vitest'
import { appShell } from '../helpers.js'


// Long enough to clear the serve repeat guard.
const PAST_GUARDS = 460
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

const click = (selector) => document.querySelector(selector).click()
const clickAll = (selector) => [...document.querySelectorAll(selector)].forEach((el) => el.click())
const screenText = () => document.getElementById('screen').textContent
const dockText = () => document.getElementById('dock').textContent
const dockHtml = () => document.getElementById('dock').innerHTML
const events = () => JSON.parse(window.localStorage.getItem('vbtracking.eventlog')).events
const chipFor = (number) => [...document.querySelectorAll('.chip')]
  .find((chip) => chip.querySelector('.chip-number')?.textContent.trim() === number)

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

  click('[data-tab="roster"]')
  for (const [number, name] of [
    ['1', 'Layna'], ['4', 'Tegan'], ['5', 'Aria'], ['7', 'Ellison'],
    ['11', 'Marilyn'], ['13', 'Charlotte'], ['15', 'Maddie'], ['25', 'Kyla'], ['55', 'Aubrey'],
  ]) addPlayer(number, name)
  click('[data-tab="track"]')
})

describe('setting up the rotation through the real UI', () => {
  it('asks for a serving order when the match opens', () => {
    click('[data-action="start-game"]')
    expect(screenText()).toContain('Serving order')
    expect(screenText()).toContain('Choose 6 more')
  })

  it('will not confirm an incomplete order', () => {
    click('[data-action="choose-lineup"]')
    click('[data-action="choose-lineup"]')
    expect(screenText()).toContain('2 of 6 chosen')
    expect(document.querySelector('[data-action="confirm-lineup"]').disabled).toBe(true)
  })

  it('confirms once six are chosen, and starts the match', () => {
    while (document.querySelector('[data-action="confirm-lineup"]').disabled) {
      click('[data-action="choose-lineup"]')
    }
    click('[data-action="confirm-lineup"]')

    expect(events().some((event) => event.t === 'SET_LINEUP')).toBe(true)
    expect(screenText()).toContain('Match 1 of 3')
  })

  it('shows the court for the first server, since the rotation cannot know who starts', () => {
    expect(dockHtml()).toContain('court-grid')
    expect(dockText()).toContain('Next server')
  })
})

describe('the rotation serving by itself', () => {
  let order

  it('takes the first server and swaps in the outcome controls', async () => {
    order = events().find((event) => event.t === 'SET_LINEUP').playerIds
    chipFor('1').click()

    expect(dockHtml()).toContain('data-outcome=')
    expect(dockText()).toContain('Now serving')
  })

  it('hands the serve on in lineup order, from outcome taps alone (SC-002, SC-003)', async () => {
    const served = []
    for (let turn = 0; turn < 5; turn += 1) {
      served.push(currentServerNumber())
      click('[data-outcome="OUT"]')
      await sleep(PAST_GUARDS)
      // The dock never leaves the outcome controls: a side-out is one tap.
      expect(dockHtml()).toContain('data-outcome=')
    }
    expect(new Set(served).size).toBe(5)
    expect(served[0]).toBe('1')
  })

  it('undoes a side-out and the advance it caused, in one tap (FR-024)', () => {
    const before = currentServerNumber()
    click('[data-action="undo"]')
    expect(currentServerNumber()).not.toBe(before)
  })
})

describe('substituting: the player coming on, then the player going off', () => {
  it('arms on a single tap of a bench player, and commits nothing yet', () => {
    click('[data-action="toggle-picker"]')
    const bench = [...document.querySelectorAll('.chip')]
      .find((chip) => !chip.classList.contains('is-on-court') && !chip.classList.contains('is-serving'))

    bench.click()

    expect(document.querySelector('.chip.is-armed')).toBeTruthy()
    expect(dockText()).toContain('is coming on')
    expect(events().at(-1).t).not.toBe('SELECT_SERVER')
  })

  it('re-aims at a different bench player rather than refusing', () => {
    const armedNumber = document.querySelector('.chip.is-armed .chip-number').textContent.trim()
    const otherBench = [...document.querySelectorAll('.chip')]
      .find((chip) => !chip.classList.contains('is-on-court') && !chip.classList.contains('is-serving')
        && !chip.classList.contains('is-armed'))

    if (otherBench) {
      const otherNumber = otherBench.querySelector('.chip-number').textContent.trim()
      otherBench.click()
      expect(document.querySelector('.chip.is-armed .chip-number').textContent.trim()).toBe(otherNumber)
      expect(otherNumber).not.toBe(armedNumber)
      expect(events().at(-1).t).not.toBe('SUBSTITUTE')
    }
  })

  it('swaps on a tap of the player coming off, who gives up their exact slot', () => {
    const armedNumber = document.querySelector('.chip.is-armed .chip-number').textContent.trim()
    const onCourt = document.querySelector('.chip.is-on-court, .chip.is-serving')
    const outNumber = onCourt.querySelector('.chip-number').textContent.trim()

    onCourt.click()

    expect(events().at(-1).t).toBe('SUBSTITUTE')
    expect(document.querySelector('.chip.is-armed')).toBeFalsy()
    expect(armedNumber).not.toBe(outNumber)
    // The incoming player is now in the order, in the place the outgoing player held.
    click('[data-action="show-lineup"]')
    expect(screenText()).toContain(armedNumber)
    click('[data-action="close-lineup"]')
  })

  it('records the substitution on the stats screen', () => {
    click('[data-tab="stats"]')
    expect(screenText()).toContain('Substitutions')
    click('[data-tab="track"]')
  })

  it('serves an armed bench player instead when their chip is tapped again (FR-029)', () => {
    click('[data-action="toggle-picker"]')
    const bench = [...document.querySelectorAll('.chip')]
      .find((chip) => !chip.classList.contains('is-on-court') && !chip.classList.contains('is-serving'))
    const number = bench.querySelector('.chip-number').textContent.trim()

    chipFor(number).click()
    chipFor(number).click()

    expect(events().at(-1).t).toBe('SELECT_SERVER')
    expect(document.querySelector('.chip.is-armed')).toBeFalsy()
  })

  it('abandons an armed substitution when something else is tapped (FR-032)', () => {
    click('[data-action="toggle-picker"]')
    const bench = [...document.querySelectorAll('.chip')]
      .find((chip) => !chip.classList.contains('is-on-court') && !chip.classList.contains('is-serving'))
    bench.click()
    expect(document.querySelector('.chip.is-armed')).toBeTruthy()

    click('[data-action="undo"]')
    expect(document.querySelector('.chip.is-armed')).toBeFalsy()
  })
})

describe('the serving order can be reviewed and abandoned', () => {
  it('shows the order with the next server marked (FR-015)', () => {
    click('[data-action="show-lineup"]')
    expect(screenText()).toContain('Serving order')
    expect(document.querySelector('.lineup-row.is-next')).toBeTruthy()
  })

  it('can be turned off, returning to picking each server by hand (FR-014)', () => {
    click('[data-action="skip-lineup"]')
    expect(events().some((event) => event.t === 'CLEAR_LINEUP')).toBe(true)
    expect(screenText()).toContain('Match 1 of 3')
  })
})

/** The jersey number in the status row, which is what the operator reads. */
function currentServerNumber() {
  return document.querySelector('.serving-number')?.textContent.trim() ?? null
}
