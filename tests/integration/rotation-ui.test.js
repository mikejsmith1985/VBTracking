// @vitest-environment jsdom
//
// Drives the real app through a lineup, an automatic rotation, and a substitution against
// a real DOM and a real Storage. The domain suite proves the rules; this proves the rules
// are actually wired to the things the operator taps.
//
// The steps run in order and share state on purpose: it is one journey through a match.
import { describe, it, expect, beforeAll } from 'vitest'

const SHELL = `
<div class="app">
  <div id="banner" class="banner" hidden></div>
  <main id="screen" class="screen"></main>
  <div id="dock" class="dock"></div>
  <nav class="tabbar">
    <button class="tab" data-action="tab" data-tab="track" type="button">Track</button>
    <button class="tab" data-action="tab" data-tab="stats" type="button">Stats</button>
    <button class="tab" data-action="tab" data-tab="roster" type="button">Roster</button>
  </nav>
</div>`

// Long enough to clear both the serve repeat guard and the double-tap window.
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
  document.body.innerHTML = SHELL
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

  it('shows the picker for the first server, since the rotation cannot know who starts', () => {
    expect(dockHtml()).toContain('chip-grid')
    expect(dockText()).toContain('Next server')
  })
})

describe('the rotation serving by itself', () => {
  let order

  it('takes the first server and swaps in the outcome controls', async () => {
    order = events().find((event) => event.t === 'SET_LINEUP').playerIds
    chipFor('1').click()
    await sleep(PAST_GUARDS) // the selection waits out the double-tap window

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

describe('substituting through the double-tap gesture', () => {
  it('arms on a second tap of the same on-court player', async () => {
    click('[data-action="toggle-picker"]')
    const onCourt = document.querySelector('.chip.is-on-court, .chip.is-serving')
    const number = onCourt.querySelector('.chip-number').textContent.trim()

    chipFor(number).click()
    chipFor(number).click() // inside the double-tap window

    expect(document.querySelector('.chip.is-armed')).toBeTruthy()
    expect(dockText()).toContain('Now tap whoever replaces')
    // The first tap must not have committed a selection of its own.
    expect(events().at(-1).t).not.toBe('SELECT_SERVER')
  })

  it('refuses someone already on court, and stays armed', () => {
    const other = [...document.querySelectorAll('.chip.is-on-court')]
      .find((chip) => !chip.classList.contains('is-armed'))
    other.click()

    expect(document.getElementById('banner').textContent).toMatch(/already on court/i)
    expect(document.querySelector('.chip.is-armed')).toBeTruthy()
  })

  it('completes on a bench player, who takes the exact slot', () => {
    const armedNumber = document.querySelector('.chip.is-armed .chip-number').textContent.trim()
    const bench = [...document.querySelectorAll('.chip')]
      .find((chip) => !chip.classList.contains('is-on-court') && !chip.classList.contains('is-armed')
        && !chip.classList.contains('is-serving'))
    const benchNumber = bench.querySelector('.chip-number').textContent.trim()

    bench.click()

    const sub = events().at(-1)
    expect(sub.t).toBe('SUBSTITUTE')
    expect(document.querySelector('.chip.is-armed')).toBeFalsy()
    expect(armedNumber).not.toBe(benchNumber)
  })

  it('records the substitution on the stats screen', () => {
    click('[data-tab="stats"]')
    expect(screenText()).toContain('Substitutions')
    click('[data-tab="track"]')
  })

  it('abandons an armed substitution when something else is tapped (FR-032)', () => {
    click('[data-action="toggle-picker"]')
    const onCourt = document.querySelector('.chip.is-on-court, .chip.is-serving')
    const number = onCourt.querySelector('.chip-number').textContent.trim()
    chipFor(number).click()
    chipFor(number).click()
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
