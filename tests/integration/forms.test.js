// @vitest-environment jsdom
//
// Every form is driven by CLICKING its submit button, not by dispatching a submit event.
//
// That distinction is the whole point of this file. The existing journey tests dispatched
// submit directly, which sails straight past the click handler -- and a bug in that handler
// silently broke every submit button in the app while 508 tests stayed green. A form is not
// proven to work until the button a thumb lands on has been pressed.
import { describe, it, expect, beforeAll } from 'vitest'

const SHELL = `
<div class="app">
  <div id="banner" class="banner" hidden></div>
  <main id="screen" class="screen"></main>
  <div id="dock" class="dock"></div>
  <nav class="tabbar">
    <button class="tab" data-action="tab" data-tab="track" type="button">Track</button>
    <button class="tab" data-action="tab" data-tab="stats" type="button">Game</button>
    <button class="tab" data-action="tab" data-tab="season" type="button">Season</button>
    <button class="tab" data-action="tab" data-tab="roster" type="button">Roster</button>
  </nav>
</div>`

const click = (selector) => document.querySelector(selector).click()
const screenText = () => document.getElementById('screen').textContent
const events = () => JSON.parse(window.localStorage.getItem('vbtracking.eventlog')).events
const countOf = (type) => events().filter((event) => event.t === type).length

/** Fills a form's fields and presses its submit BUTTON, as a thumb would. */
function fillAndPress(formId, values) {
  const form = document.getElementById(formId)
  for (const [name, value] of Object.entries(values)) {
    form.querySelector(`[name="${name}"]`).value = value
  }
  form.querySelector('button[type="submit"]').click()
}

beforeAll(async () => {
  window.localStorage.clear()
  document.body.innerHTML = SHELL
  await import('../../src/ui/app.js')
})

describe('the add-player button', () => {
  it('adds a player when pressed', () => {
    click('[data-tab="roster"]')
    fillAndPress('add-player-form', { number: '5', name: 'Aria Smith' })

    expect(countOf('ADD_PLAYER')).toBe(1)
    expect(screenText()).toContain('1 of 20 players')
  })

  it('adds a second, so the form still works after a redraw', () => {
    fillAndPress('add-player-form', { number: '4', name: 'Tegan Jodrey' })
    expect(countOf('ADD_PLAYER')).toBe(2)
  })

  it('refuses a blank name and says why, rather than doing nothing', () => {
    fillAndPress('add-player-form', { number: '9', name: '   ' })
    expect(countOf('ADD_PLAYER')).toBe(2)
    expect(document.getElementById('banner').textContent).toMatch(/name is required/i)
  })
})

describe('the season Save button', () => {
  it('renames the season and its team when pressed', () => {
    click('[data-tab="season"]')
    fillAndPress('rename-season-form', { name: '2026', team: 'Bethel Tigers' })

    expect(countOf('RENAME_SEASON')).toBe(1)
    expect(screenText()).toContain('2026')
    expect(screenText()).toContain('Bethel Tigers')
  })

  it('records it, so the change survives a reload rather than only a redraw', () => {
    expect(events().at(-1)).toMatchObject({ t: 'RENAME_SEASON', name: '2026', team: 'Bethel Tigers' })
  })

  it('carries the new name onto the roster screen', () => {
    click('[data-tab="roster"]')
    expect(screenText()).toContain('2026')
    expect(screenText()).toContain('Bethel Tigers')
    click('[data-tab="season"]')
  })

  it('refuses a blank season name', () => {
    fillAndPress('rename-season-form', { name: '  ', team: 'Anything' })
    expect(countOf('RENAME_SEASON')).toBe(1)
    expect(document.getElementById('banner').textContent).toMatch(/name is required/i)
  })
})

describe('the Create season button', () => {
  it('creates a season and makes it active when pressed', () => {
    fillAndPress('create-season-form', { name: '2027', team: 'School Team' })

    expect(countOf('CREATE_SEASON')).toBe(1)
    expect(countOf('ACTIVATE_SEASON')).toBe(1)
    expect(screenText()).toContain('2027')
    expect(screenText()).toContain('School Team')
  })

  it('leaves the new season with an empty roster, and the old one intact', () => {
    click('[data-tab="roster"]')
    expect(screenText()).toContain('0 of 20 players')

    click('[data-tab="season"]')
    click('[data-action="activate-season"]')
    click('[data-tab="roster"]')
    expect(screenText()).toContain('2 of 20 players')
  })
})

describe('the game form button', () => {
  beforeAll(() => {
    click('[data-tab="season"]')
    click('[data-action="add-historical"]')
  })

  it('adds a game from paper when pressed', () => {
    const form = document.getElementById('game-form')
    form.querySelector('[name="date"]').value = '2026-08-08'
    form.querySelector('[name="opponent"]').value = 'Georgetown A'
    form.querySelector('[name="location"]').value = 'Fayetteville'
    form.querySelector('[name="court"]').value = '1'
    form.querySelector('[name="notes"]').value = 'Good talking on the lines.'

    const inputs = [...form.querySelectorAll('.serve-entry-row input')]
    inputs[0].value = '5'
    inputs[1].value = '2'

    form.querySelector('button[type="submit"]').click()

    expect(countOf('ADD_HISTORICAL_GAME')).toBe(1)
  })

  it('records the context, the figures and the notes it was given', () => {
    const game = events().at(-1)
    expect(game).toMatchObject({
      date: '2026-08-08', opponent: 'Georgetown A', location: 'Fayetteville', court: '1',
      notes: 'Good talking on the lines.',
    })
    expect(game.entries[0]).toMatchObject({ in: 5, out: 2 })
  })

  it('returns to the season, where the game now appears', () => {
    expect(screenText()).toContain('Georgetown A')
    expect(document.querySelectorAll('.game-row').length).toBeGreaterThan(0)
  })
})

describe('a stray tap on empty space', () => {
  it('does not redraw the screen out from under a form', () => {
    click('[data-action="add-historical"]')
    const form = document.getElementById('game-form')
    form.querySelector('[name="opponent"]').value = 'Half typed'

    // A tap on something with no action at all -- the thing that used to wipe the form.
    document.querySelector('.section-title').click()

    expect(document.getElementById('game-form')).toBe(form)
    expect(document.querySelector('[name="opponent"]').value).toBe('Half typed')
  })
})

describe('pasting a batch of games', () => {
  const batch = JSON.stringify({
    app: 'vbtracking',
    kind: 'historical-games',
    formatVersion: 1,
    games: [{
      date: '2026-08-15', opponent: 'Eastern A', location: 'Blanchester', court: '2',
      result: 'won', notes: 'Started matching serves.',
      serves: [{ name: 'Aria Smith', in: 9, out: 2 }, { name: 'Tegan Jodrey', in: 8, out: 3 }],
    }],
  })

  beforeAll(() => {
    click('[data-tab="season"]')
  })

  it('is offered, because saving a file on a phone is the harder path', () => {
    expect(screenText()).toContain('Paste a batch of games')
    expect(screenText()).toContain('Pasting is usually easier on a phone')
  })

  it('opens a box to paste into', () => {
    click('[data-action="paste-games"]')
    expect(document.getElementById('paste-games-form')).toBeTruthy()
  })

  it('says so rather than failing silently when nothing was pasted', () => {
    document.querySelector('#paste-games-form button[type="submit"]').click()
    expect(document.getElementById('banner').textContent).toMatch(/Paste the contents/i)
    expect(countOf('ADD_HISTORICAL_GAME')).toBe(1) // only the one added by hand earlier
  })

  it('refuses something that is not a game file, and keeps the box open to try again', () => {
    fillAndPress('paste-games-form', { games: '{ not json' })
    expect(document.getElementById('banner').textContent).toMatch(/not readable/i)
    expect(document.getElementById('paste-games-form')).toBeTruthy()
  })

  it('names a player it does not recognise, and imports nothing', () => {
    const stranger = batch.replace('Aria Smith', 'Somebody Else')
    fillAndPress('paste-games-form', { games: stranger })

    expect(document.getElementById('banner').textContent).toMatch(/Somebody Else/)
    expect(countOf('ADD_HISTORICAL_GAME')).toBe(1)
  })

  it('adds the games when the batch is good, and closes the box', () => {
    fillAndPress('paste-games-form', { games: batch })

    expect(countOf('ADD_HISTORICAL_GAME')).toBe(2)
    expect(document.getElementById('paste-games-form')).toBeFalsy()
    expect(screenText()).toContain('Eastern A')
  })

  it('records what the paste contained', () => {
    const game = events().at(-1)
    expect(game).toMatchObject({ opponent: 'Eastern A', location: 'Blanchester', court: '2' })
    expect(game.entries).toHaveLength(2)
  })
})

describe('the banner tells success from failure by colour', () => {
  const banner = () => document.getElementById('banner')

  const goodBatch = JSON.stringify({
    app: 'vbtracking', kind: 'historical-games', formatVersion: 1,
    games: [{
      date: '2026-08-22', opponent: 'CNE', location: 'Felicity', court: '1',
      serves: [{ name: 'Aria Smith', in: 20, out: 2 }],
    }],
  })

  beforeAll(() => { click('[data-tab="season"]') })

  it('reports an import that worked in the success tone, not the failure one', () => {
    click('[data-action="paste-games"]')
    fillAndPress('paste-games-form', { games: goodBatch })

    expect(banner().textContent).toMatch(/^Added 1 game\.$/)
    expect(banner().className).toContain('banner-success')
    expect(banner().className).not.toContain('banner-error')
  })

  it('reports a refusal in the failure tone', () => {
    click('[data-action="paste-games"]')
    fillAndPress('paste-games-form', { games: '{ not json' })

    expect(banner().className).toContain('banner-error')
    expect(banner().className).not.toContain('banner-success')
  })

  it('reports a rejected event in the failure tone', () => {
    click('[data-action="cancel-paste"]')
    click('[data-tab="roster"]')
    fillAndPress('add-player-form', { number: '9', name: '   ' })

    expect(banner().className).toContain('banner-error')
  })

  it('clears the banner entirely once something else is tapped', () => {
    click('[data-tab="season"]')
    expect(banner().hidden).toBe(true)
    expect(banner().className).toBe('banner')
  })

  it('keeps the paste box open on failure, so the paste can be corrected', () => {
    click('[data-action="paste-games"]')
    fillAndPress('paste-games-form', { games: '{ still not json' })
    expect(document.getElementById('paste-games-form')).toBeTruthy()
  })

  it('closes it on success', () => {
    fillAndPress('paste-games-form', { games: goodBatch })
    expect(document.getElementById('paste-games-form')).toBeFalsy()
    expect(banner().className).toContain('banner-success')
  })
})
