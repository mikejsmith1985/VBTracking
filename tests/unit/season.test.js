// The season screen. Proves it reports the record honestly, marks games that came from
// paper, and never presents a season's figures as though they all came from tracked play.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'
import { view } from '../../src/ui/screens/season.js'
import { build, roster } from '../helpers.js'

const { OUT, IN_POINT } = E.OUTCOME
const { WON, LOST } = E.MATCH_RESULT

const baseUi = { tab: 'season', careerPlayerId: null, editingGameId: null, confirmingHistoricalImport: false }
const render = (state, overrides = {}) => view({ state, store: {}, ui: { ...baseUi, ...overrides } })

const context = (opponent, date = '2026-08-08') => ({ date, opponent, location: 'Fayetteville', court: '1' })

/** A season with one tracked game and one copied from paper. */
function season() {
  return build(
    roster(3),
    E.renameSeason('season-1', '2026', 'Bethel Tigers'),
    E.startGame('g1'),
    E.setGameContext('g1', context('Georgetown A')),
    E.selectServer('p1'), E.recordServe(IN_POINT), E.recordServe(OUT),
    E.endMatch(WON), E.endMatch(WON), E.endMatch(LOST),
    E.addHistoricalGame('h1', 'season-1', context('Blanchester'), [
      { playerId: 'p1', in: 9, out: 2 },
      { playerId: 'p2', in: 4, out: 1 },
    ]),
  )
}

describe('the season header', () => {
  it('names the season and the team it was played for', () => {
    const { screen } = render(season())
    expect(screen).toContain('2026')
    expect(screen).toContain('Bethel Tigers')
    expect(screen).toContain('2 games')
  })

  it('says so plainly when there is no season yet', () => {
    expect(render(build()).screen).toContain('No season yet')
  })

  it('says so plainly when a season has no games', () => {
    expect(render(build(roster(3))).screen).toContain('No games yet this season')
  })
})

describe('the record', () => {
  it('reports wins and losses', () => {
    expect(render(season()).screen).toContain('<b>1–0</b>')
  })

  it('counts an unrecorded result separately, never as a loss', () => {
    const { screen } = render(season())
    expect(screen).toContain('not recorded')
    expect(screen).not.toContain('1–1')
  })

  it('breaks the record down by opponent', () => {
    const { screen } = render(season())
    expect(screen).toContain('By opponent')
    expect(screen).toContain('Georgetown A')
    expect(screen).toContain('Blanchester')
  })
})

describe('the game list', () => {
  const { screen } = render(season())

  it('shows each game with its date and opponent', () => {
    expect(screen).toContain('2026-08-08')
    expect(screen).toContain('Georgetown A')
  })

  it('marks the games that came from paper', () => {
    expect(screen.split('kind-pill').length - 1).toBe(1)
    expect(screen).toContain('from paper')
  })

  it('names each game’s top scorer without anyone tallying it', () => {
    expect(screen).toContain('top:')
  })

  it('opens a game when tapped', () => {
    expect(screen).toContain('data-action="open-game"')
  })

  it('shows a result pill for every game', () => {
    expect(screen).toContain('result-won')
    expect(screen).toContain('result-undecided')
  })
})

describe('the season statistics', () => {
  it('label which columns cover which games (FR-044)', () => {
    expect(render(season()).screen).toContain('came from paper')
  })

  it('link each player to their career', () => {
    expect(render(season()).screen).toContain('data-action="open-career"')
  })
})

describe('season administration', () => {
  const { screen } = render(season())

  it('offers renaming this season and its team', () => {
    expect(screen).toContain('id="rename-season-form"')
  })

  it('offers creating another', () => {
    expect(screen).toContain('id="create-season-form"')
    expect(screen).toContain('history follows them')
  })

  it('lists other seasons to switch to, and only when there are some', () => {
    expect(screen).not.toContain('Other seasons')

    const two = build(season().games ? [] : [], roster(1), E.createSeason('s2', '2027', 'School Team'))
    expect(render(two).screen).toContain('Other seasons')
  })

  it('offers both ways to add a game from paper', () => {
    expect(screen).toContain('data-action="add-historical"')
    expect(screen).toContain('data-action="import-historical"')
  })

  it('says what importing does before the second tap', () => {
    const armed = render(season(), { confirmingHistoricalImport: true }).screen
    expect(armed).toContain('nothing already recorded is replaced')
  })
})

describe('the career view', () => {
  it('takes over the screen when a player is opened', () => {
    const { screen } = render(season(), { careerPlayerId: 'p1' })
    expect(screen).toContain('data-action="close-career"')
    expect(screen).not.toContain('id="rename-season-form"')
  })
})

describe('escaping', () => {
  it('does not render an opponent name as markup', () => {
    const hostile = build(roster(1), E.addHistoricalGame('h1', 'season-1',
      context('<img src=x>'), [{ playerId: 'p1', in: 1, out: 0 }]))
    const { screen } = render(hostile)
    expect(screen).not.toContain('<img')
    expect(screen).toContain('&lt;img')
  })
})

describe('saving and restoring the whole record', () => {
  it('offers a copy of everything from the season screen', () => {
    const html = render(season()).screen
    expect(html).toContain('data-action="export-data"')
    expect(html).toContain('Save a copy of everything')
  })

  it('offers a restore, and says what restoring costs before it is armed', () => {
    const html = render(season()).screen
    expect(html).toContain('data-action="import-data"')
    expect(html).toContain('Nothing is sent anywhere')
  })

  it('states plainly what a restore replaces once it is armed', () => {
    const html = render(season(), { confirmingImport: true }).screen
    expect(html).toContain('Replace everything from a file?')
    expect(html).toContain('including any match in progress')
  })

  it('is reachable with no game recorded at all', () => {
    // The bug this replaces: backup lived on the game screen, which shows nothing until a
    // game exists -- so an operator between games could not save their season at all.
    const html = render(build(roster(3))).screen
    expect(html).toContain('data-action="export-data"')
  })

  it('is reachable with nothing recorded at all', () => {
    const html = render(build()).screen
    expect(html).toContain('data-action="export-data"')
  })
})

describe('the running build', () => {
  it('is shown, so a stale cache can be told from a broken fix', () => {
    expect(render(season()).screen).toMatch(/Version v\d+/)
  })
})
