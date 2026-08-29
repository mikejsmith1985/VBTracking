// The career view exists to answer one question: is this the same child, doing better?
// So it must show each season's own team and number, and must never present a figure that
// was never recorded as a zero.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'
import { careerView } from '../../src/ui/screens/career.js'
import { build } from '../helpers.js'

const context = (opponent, date) => ({ date, opponent, location: 'Gym', court: '1' })

/** One child, two teams, two numbers -- the case the whole release is built for. */
const twoSeasons = build(
  E.createSeason('s1', '2026', 'Bethel Tigers'),
  E.addPlayer('kid', 'Aria Smith', '5', 's1'),
  E.addHistoricalGame('h1', 's1', context('CNE', '2026-08-22'), [{ playerId: 'kid', in: 8, out: 2 }]),
  E.createSeason('s2', '2027', 'School Team'),
  E.activateSeason('s2'),
  E.addPlayer('kid', 'Aria Smith', '12', 's2'),
  E.addHistoricalGame('h2', 's2', context('Felicity', '2027-08-08'), [{ playerId: 'kid', in: 12, out: 1 }]),
)

describe('a player across seasons', () => {
  const html = careerView(twoSeasons, 'kid')

  it('names the player once, at the top', () => {
    expect(html).toContain('Aria Smith')
    expect(html).toContain('2 seasons')
  })

  it('lists each season with its own team and its own number (FR-048)', () => {
    expect(html).toContain('Bethel Tigers · number 5')
    expect(html).toContain('School Team · number 12')
  })

  it('shows each season’s own figures', () => {
    expect(html).toContain('>10<')  // 2026: 8 in + 2 out
    expect(html).toContain('>13<')  // 2027: 12 in + 1 out
  })

  it('combines them into a career total', () => {
    expect(html).toContain('Career')
    expect(html).toContain('>23<')  // 10 + 13
  })

  it('offers a way back to the season', () => {
    expect(html).toContain('data-action="close-career"')
  })
})

describe('figures that were never recorded', () => {
  const html = careerView(twoSeasons, 'kid')

  it('render as a dash, never as a zero (FR-045)', () => {
    expect(html).toContain('figure-absent')
    expect(html).toContain('Not recorded')
  })

  it('explain why, rather than leaving the reader to guess', () => {
    expect(html).toContain('recorded serves only')
  })

  it('still show the serve figures the paper did record', () => {
    expect(html).toContain('Serves')
    expect(html).toContain('In %')
  })
})

describe('a player with one season', () => {
  const oneSeason = build(
    E.createSeason('s1', '2026', 'Bethel Tigers'),
    E.addPlayer('kid', 'Aria Smith', '5', 's1'),
    E.addHistoricalGame('h1', 's1', context('CNE', '2026-08-22'), [{ playerId: 'kid', in: 8, out: 2 }]),
  )

  it('shows it without implying others are missing', () => {
    const html = careerView(oneSeason, 'kid')
    expect(html).toContain('1 season')
    expect(html).toContain('One season')
  })
})

describe('a player with no games', () => {
  it('says so rather than showing zeroes', () => {
    const benched = build(
      E.createSeason('s1', '2026', 'Tigers'),
      E.addPlayer('kid', 'Aria Smith', '5', 's1'),
    )
    expect(careerView(benched, 'kid')).toContain('No games played')
  })
})

describe('a player who no longer exists', () => {
  it('says so rather than rendering an empty shell', () => {
    expect(careerView(twoSeasons, 'ghost')).toContain('no longer exists')
  })
})

describe('escaping', () => {
  it('does not render a name or a team as markup', () => {
    const hostile = build(
      E.createSeason('s1', '<b>2026</b>', '<img src=x>'),
      E.addPlayer('kid', '"><script>', '5', 's1'),
      E.addHistoricalGame('h1', 's1', context('X', '2026-01-01'), [{ playerId: 'kid', in: 1, out: 0 }]),
    )
    const html = careerView(hostile, 'kid')
    expect(html).not.toContain('<img')
    expect(html).not.toContain('<script>')
    expect(html).toContain('&lt;')
  })
})
