// Getting rid of a season, and getting rid of everything.
//
// Both exist because the app had no way out of its own data. A season entered to try the
// app out, or a backup restored to see what it looked like, could be emptied game by game
// and player by player and STILL leave a season sitting at the top of the screen with no
// control anywhere that would remove it.
import { describe, it, expect } from 'vitest'
import {
  createSeason,
  activateSeason,
  addPlayer,
  startGame,
  discardSeason,
} from '../../src/domain/events.js'
import { replay, gamesInSeason, seasonById, activeSeason } from '../../src/domain/reducer.js'

/** A season with a squad and a game in it, plus a second season left alone. */
function twoSeasons() {
  return [
    createSeason('s1', '2026 Fall', 'Riverside'),
    activateSeason('s1'),
    addPlayer('p1', 'Avery', '4', 's1'),
    addPlayer('p2', 'Riley', '5', 's1'),
    startGame('g1', 's1'),
    createSeason('s2', '2025 Fall', 'Riverside'),
    addPlayer('p1', 'Avery', '9', 's2'),
  ]
}

describe('discarding a season', () => {
  it('removes the season itself', () => {
    const state = replay([...twoSeasons(), discardSeason('s1')])
    expect(seasonById(state, 's1')).toBeFalsy()
  })

  it('takes its games with it', () => {
    const state = replay([...twoSeasons(), discardSeason('s1')])
    expect(gamesInSeason(state, 's1')).toEqual([])
    expect(state.games).toEqual([])
  })

  it('leaves the players, because a person outlives a roster', () => {
    const state = replay([...twoSeasons(), discardSeason('s1')])
    expect(state.players.map((player) => player.id)).toEqual(['p1', 'p2'])
  })

  it('keeps what they wore in a season that was not discarded', () => {
    const state = replay([...twoSeasons(), discardSeason('s1')])
    expect(seasonById(state, 's2').members).toEqual([{ playerId: 'p1', number: '9' }])
  })

  it('leaves no season active when the active one goes', () => {
    const state = replay([...twoSeasons(), discardSeason('s1')])
    expect(activeSeason(state)).toBeFalsy()
    expect(state.activeSeasonId).toBeNull()
  })

  it('closes the game in progress if it belonged to that season', () => {
    const state = replay([...twoSeasons(), discardSeason('s1')])
    expect(state.currentGameId).toBeNull()
  })

  it('leaves another season completely alone', () => {
    const state = replay([...twoSeasons(), discardSeason('s1')])
    expect(seasonById(state, 's2')).toBeDefined()
  })

  it('refuses a season that is not there, rather than doing nothing quietly', () => {
    const events = twoSeasons()
    const before = replay(events)
    const after = replay([...events, discardSeason('s9')])
    expect(after).toEqual(before)
  })
})
