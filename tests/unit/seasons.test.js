// Proves the release's load-bearing rule: a jersey number belongs to a season, and a
// player is a person who outlives every roster.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'
import {
  replay, rejectionReason, activeSeason, seasonById, seasonMembers, numberFor,
  playerById, gamesInSeason, seasonsForPlayer, currentMatch, findPlayer,
} from '../../src/domain/reducer.js'
import { build, roster } from '../helpers.js'

const twoSeasons = [
  E.createSeason('s1', '2026', 'Bethel Tigers'),
  E.addPlayer('daughter', 'Aria Smith', '5', 's1'),
  E.addPlayer('p2', 'Layna Blankenship', '1', 's1'),
  E.createSeason('s2', '2027', 'School Team'),
  E.addPlayer('daughter', 'Aria Smith', '12', 's2'),
]

describe('a season always exists', () => {
  it('is created implicitly for an operator who never made one', () => {
    const state = build(E.addPlayer('p1', 'Rivera', '7'))
    expect(state.seasons).toHaveLength(1)
    expect(activeSeason(state)).toBeTruthy()
    expect(state.roster).toHaveLength(1)
  })

  it('can be renamed afterwards', () => {
    const state = build(E.addPlayer('p1', 'Rivera', '7'), E.renameSeason('season-1', '2026', 'Bethel Tigers'))
    expect(activeSeason(state)).toMatchObject({ name: '2026', team: 'Bethel Tigers' })
  })

  it('records the format it was played under, without offering it for editing', () => {
    const state = build(E.createSeason('s1', '2026', 'Tigers'))
    expect(seasonById(state, 's1').format).toEqual({ matchesPerGame: 3, targetScore: 21, playersOnCourt: 6 })
  })

  it('refuses a season with no name', () => {
    expect(rejectionReason(build(), E.createSeason('s1', '   ', 'Tigers'))).toBeTruthy()
  })

  it('refuses a duplicate season id', () => {
    const state = build(E.createSeason('s1', '2026', 'Tigers'))
    expect(rejectionReason(state, E.createSeason('s1', 'Again', 'Tigers'))).toBeTruthy()
  })
})

describe('a number belongs to the season, not the person', () => {
  const state = build(twoSeasons)

  it('is the whole reason career identity exists', () => {
    expect(numberFor(state, 's1', 'daughter')).toBe('5')
    expect(numberFor(state, 's2', 'daughter')).toBe('12')
  })

  it('leaves one person, not two', () => {
    expect(state.players.filter((player) => player.id === 'daughter')).toHaveLength(1)
    expect(playerById(state, 'daughter').name).toBe('Aria Smith')
  })

  it('is not stored on the player at all', () => {
    expect(playerById(state, 'daughter').number).toBeUndefined()
  })

  it('lists both seasons for that player', () => {
    expect(seasonsForPlayer(state, 'daughter').map((season) => season.id)).toEqual(['s1', 's2'])
  })

  it('gives each season its own roster', () => {
    expect(seasonMembers(state, 's1').map((member) => member.name)).toEqual(['Aria Smith', 'Layna Blankenship'])
    expect(seasonMembers(state, 's2').map((member) => member.name)).toEqual(['Aria Smith'])
  })

  it('returns null for a season the player was never in', () => {
    expect(numberFor(state, 's2', 'p2')).toBeNull()
  })
})

describe('the active season', () => {
  it('is the first one created', () => {
    expect(activeSeason(build(twoSeasons)).id).toBe('s1')
  })

  it('decides what the roster screen shows', () => {
    const state = build(twoSeasons, E.activateSeason('s2'))
    expect(state.roster.map((player) => player.number)).toEqual(['12'])
  })

  it('decides which season a new game belongs to', () => {
    const state = build(twoSeasons, E.activateSeason('s2'), E.startGame('g1'))
    expect(gamesInSeason(state, 's2')).toHaveLength(1)
    expect(gamesInSeason(state, 's1')).toHaveLength(0)
  })

  it('cannot be switched while a game is under way (FR-015)', () => {
    const playing = build(twoSeasons, E.startGame('g1'), E.selectServer('daughter'))
    expect(rejectionReason(playing, E.activateSeason('s2'))).toMatch(/Finish or discard/)
    expect(currentMatch(playing)).toBeTruthy()
  })

  it('is still refused after one match of three, because the game continues', () => {
    const midGame = build(twoSeasons, E.startGame('g1'), E.selectServer('daughter'),
      E.recordServe(E.OUTCOME.OUT), E.endMatch(E.MATCH_RESULT.WON))
    expect(rejectionReason(midGame, E.activateSeason('s2'))).toBeTruthy()
  })

  it('can be switched once the whole game is finished', () => {
    const done = build(
      twoSeasons, E.startGame('g1'), E.selectServer('daughter'), E.recordServe(E.OUTCOME.OUT),
      E.endMatch(E.MATCH_RESULT.WON), E.endMatch(E.MATCH_RESULT.LOST), E.endMatch(E.MATCH_RESULT.WON),
      E.activateSeason('s2'),
    )
    expect(activeSeason(done).id).toBe('s2')
  })

  it('refuses a season that does not exist', () => {
    expect(rejectionReason(build(twoSeasons), E.activateSeason('nope'))).toBeTruthy()
  })
})

describe('season rosters', () => {
  it('refuse the same person twice in one season (FR-020)', () => {
    const state = build(twoSeasons)
    expect(rejectionReason(state, E.addPlayer('daughter', 'Aria Smith', '9', 's1'))).toMatch(/already/)
  })

  it('allow the same number twice, because rosters sometimes do (FR-021)', () => {
    const state = build(twoSeasons, E.addPlayer('p3', 'Someone Else', '5', 's1'))
    expect(seasonMembers(state, 's1').filter((member) => member.number === '5')).toHaveLength(2)
  })

  it('cap a season at twenty players', () => {
    const state = build(roster(20))
    expect(rejectionReason(state, E.addPlayer('p21', 'Extra', '21'))).toMatch(/20/)
  })
})

describe('editing a player', () => {
  const edited = build(twoSeasons, E.editPlayer('daughter', 'Aria Smith-Jones', '9', 's1'))

  it('changes the name everywhere, in every season (FR-011)', () => {
    expect(playerById(edited, 'daughter').name).toBe('Aria Smith-Jones')
    expect(seasonMembers(edited, 's2')[0].name).toBe('Aria Smith-Jones')
  })

  it('changes the number in that season only', () => {
    expect(numberFor(edited, 's1', 'daughter')).toBe('9')
    expect(numberFor(edited, 's2', 'daughter')).toBe('12')
  })

  it('refuses a blank name', () => {
    expect(rejectionReason(build(twoSeasons), E.editPlayer('daughter', '  ', '9', 's1'))).toBeTruthy()
  })

  it('refuses a player who does not exist', () => {
    expect(rejectionReason(build(twoSeasons), E.editPlayer('ghost', 'X', '9', 's1'))).toBeTruthy()
  })
})

describe('the active roster is derived, never stored', () => {
  it('resolves names and this season’s numbers', () => {
    const state = build(twoSeasons)
    expect(state.roster).toEqual([
      { id: 'daughter', name: 'Aria Smith', number: '5' },
      { id: 'p2', name: 'Layna Blankenship', number: '1' },
    ])
  })

  it('is what findPlayer looks in', () => {
    const state = build(twoSeasons, E.activateSeason('s2'))
    expect(findPlayer(state, 'daughter')).toBeTruthy()
    expect(findPlayer(state, 'p2')).toBeNull()
  })

  it('follows a rename immediately', () => {
    const state = build(twoSeasons, E.editPlayer('p2', 'Layna B', '1', 's1'))
    expect(state.roster.find((player) => player.id === 'p2').name).toBe('Layna B')
  })
})
