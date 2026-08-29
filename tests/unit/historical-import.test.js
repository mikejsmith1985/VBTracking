// A batch import that half-lands is worse than one that refuses: the operator cannot tell
// what took. Every rejection path is checked, and every one must leave nothing behind.
import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { parseHistoricalGames, IMPORT_MARKER, IMPORT_KIND } from '../../src/state/historical-import.js'
import { replay, gamesInSeason, seasonMembers } from '../../src/domain/reducer.js'
import { aggregate, gameSummary } from '../../src/domain/aggregate.js'
import * as E from '../../src/domain/events.js'

const season = {
  id: 's1',
  name: '2026',
  members: [
    { id: 'p1', name: 'Layna Blankenship', number: '1' },
    { id: 'p2', name: 'Tegan Jodrey', number: '4' },
  ],
}

let counter = 0
const makeId = () => `imported-${counter += 1}`

function batch(games) {
  return JSON.stringify({ app: IMPORT_MARKER, kind: IMPORT_KIND, formatVersion: 1, games })
}

const oneGame = [{
  date: '2026-08-08',
  opponent: 'Georgetown A',
  location: 'Fayetteville',
  court: '1',
  result: 'lost',
  notes: 'Got tired.',
  serves: [{ name: 'Layna Blankenship', in: 5, out: 2 }, { name: 'Tegan Jodrey', in: 10, out: 1 }],
}]

describe('a well-formed batch', () => {
  it('becomes one event per game', () => {
    const result = parseHistoricalGames(batch(oneGame), season, makeId)
    expect(result.ok).toBe(true)
    expect(result.events).toHaveLength(1)
    expect(result.events[0].t).toBe('ADD_HISTORICAL_GAME')
  })

  it('carries the context, the result, and the notes', () => {
    const [event] = parseHistoricalGames(batch(oneGame), season, makeId).events
    expect(event).toMatchObject({
      seasonId: 's1', date: '2026-08-08', opponent: 'Georgetown A',
      location: 'Fayetteville', court: '1', result: 'lost', notes: 'Got tired.',
    })
  })

  it('resolves each player by name to their id', () => {
    const [event] = parseHistoricalGames(batch(oneGame), season, makeId).events
    expect(event.entries).toEqual([
      { playerId: 'p1', in: 5, out: 2 },
      { playerId: 'p2', in: 10, out: 1 },
    ])
  })

  it('matches names case- and whitespace-insensitively, because handwriting is transcribed', () => {
    const messy = [{ ...oneGame[0], serves: [{ name: '  layna BLANKENSHIP ', in: 1, out: 0 }] }]
    expect(parseHistoricalGames(batch(messy), season, makeId).ok).toBe(true)
  })

  it('defaults an unstated result to undecided rather than a loss', () => {
    const noResult = [{ ...oneGame[0], result: undefined }]
    expect(parseHistoricalGames(batch(noResult), season, makeId).events[0].result).toBe('undecided')
  })

  it('dispatches nothing itself -- it only returns events', () => {
    const result = parseHistoricalGames(batch(oneGame), season, makeId)
    expect(Array.isArray(result.events)).toBe(true)
  })
})

describe('refusals leave nothing behind', () => {
  const rejects = (label, text, pattern) => {
    it(`refuses ${label}`, () => {
      const result = parseHistoricalGames(text, season, makeId)
      expect(result.ok).toBe(false)
      expect(result.events).toEqual([])
      if (pattern) expect(result.reason).toMatch(pattern)
    })
  }

  rejects('malformed JSON', '{ not json')
  rejects('an unrelated JSON object', JSON.stringify({ hello: 'world' }))
  rejects('a backup file, which is a different thing', JSON.stringify({ app: IMPORT_MARKER, events: [] }))
  rejects('a batch with no games', batch([]))
  rejects('a game with no serve figures', batch([{ opponent: 'CNE', serves: [] }]))
  rejects('an unrecognised result', batch([{ ...oneGame[0], result: 'drew' }]))

  it('refuses an unknown player, names them, and imports nothing (FR-041)', () => {
    const stranger = [{ ...oneGame[0], serves: [{ name: 'Someone Else', in: 1, out: 0 }] }]
    const result = parseHistoricalGames(batch(stranger), season, makeId)
    expect(result.ok).toBe(false)
    expect(result.reason).toMatch(/Someone Else/)
    expect(result.reason).toMatch(/Nothing was imported/)
  })

  it('refuses the whole batch when only the last game is bad -- all or nothing', () => {
    const mixed = [oneGame[0], { ...oneGame[0], serves: [{ name: 'Ghost', in: 1, out: 0 }] }]
    expect(parseHistoricalGames(batch(mixed), season, makeId).events).toEqual([])
  })

  it('refuses a negative count (FR-039)', () => {
    const negative = [{ ...oneGame[0], serves: [{ name: 'Layna Blankenship', in: -1, out: 0 }] }]
    expect(parseHistoricalGames(batch(negative), season, makeId).ok).toBe(false)
  })

  it('refuses a fractional count', () => {
    const fractional = [{ ...oneGame[0], serves: [{ name: 'Layna Blankenship', in: 1.5, out: 0 }] }]
    expect(parseHistoricalGames(batch(fractional), season, makeId).ok).toBe(false)
  })

  it('refuses when there is no season to import into', () => {
    expect(parseHistoricalGames(batch(oneGame), null, makeId).ok).toBe(false)
  })

  it('never throws, whatever it is handed', () => {
    for (const junk of ['', '[]', '{}', 'null', ' ']) {
      expect(() => parseHistoricalGames(junk, season, makeId)).not.toThrow()
    }
  })
})

describe('the real file transcribed from the paper sheets', () => {
  const file = readFileSync('specs/003-seasons-and-career/historical-games.json', 'utf8')
  const parsed = JSON.parse(file)

  /** The season as the app would hold it after the roster in the file was entered. */
  const realSeason = {
    id: 's1',
    name: parsed.season.name,
    members: parsed.season.roster.map((player, index) => ({
      id: `real-${index}`, name: player.name, number: player.number,
    })),
  }

  it('parses into five games', () => {
    const result = parseHistoricalGames(file, realSeason, makeId)
    expect(result.ok).toBe(true)
    expect(result.events).toHaveLength(5)
  })

  it('reconciles with the totals written on each sheet', () => {
    const expected = [[37, 15], [42, 15], [42, 17], [42, 19], [32, 10]]
    const events = parseHistoricalGames(file, realSeason, makeId).events

    events.forEach((event, index) => {
      const totalIn = event.entries.reduce((sum, entry) => sum + entry.in, 0)
      const totalOut = event.entries.reduce((sum, entry) => sum + entry.out, 0)
      expect([totalIn, totalOut], event.opponent).toEqual(expected[index])
    })
  })

  it('replays into a season whose figures match the sheets', () => {
    const events = parseHistoricalGames(file, realSeason, makeId).events
    const setup = [
      E.createSeason('s1', parsed.season.name, parsed.season.team),
      ...realSeason.members.map((member) => E.addPlayer(member.id, member.name, member.number, 's1')),
    ]
    const state = replay([...setup, ...events])

    expect(seasonMembers(state, 's1')).toHaveLength(9)
    expect(gamesInSeason(state, 's1')).toHaveLength(5)

    const { byPlayer, coverage } = aggregate(gamesInSeason(state, 's1'))
    const seasonIn = [...byPlayer.values()].reduce((sum, figures) => sum + figures.servesIn, 0)
    const seasonServes = [...byPlayer.values()].reduce((sum, figures) => sum + figures.serves, 0)

    expect(seasonIn).toBe(195)
    expect(seasonServes).toBe(271)
    expect(coverage).toEqual({ totalGames: 5, trackedGames: 0 })
  })

  it('reports no points for them, because the paper never had any (FR-045)', () => {
    const events = parseHistoricalGames(file, realSeason, makeId).events
    const setup = [
      E.createSeason('s1', parsed.season.name, parsed.season.team),
      ...realSeason.members.map((member) => E.addPlayer(member.id, member.name, member.number, 's1')),
    ]
    const state = replay([...setup, ...events])

    for (const figures of aggregate(gamesInSeason(state, 's1')).byPlayer.values()) {
      expect(figures.points).toBeNull()
      expect(figures.turnsTaken).toBeNull()
    }
  })

  it('names the top scorer of the last game as the sheet does', () => {
    const events = parseHistoricalGames(file, realSeason, makeId).events
    const setup = [
      E.createSeason('s1', parsed.season.name, parsed.season.team),
      ...realSeason.members.map((member) => E.addPlayer(member.id, member.name, member.number, 's1')),
    ]
    const state = replay([...setup, ...events])

    // 29 August: the sheet's "top scorer" is Tegan with 8 serves in.
    const lastGame = gamesInSeason(state, 's1').at(-1)
    const top = gameSummary(lastGame).topScorer
    const tegan = realSeason.members.find((member) => member.name === 'Tegan Jodrey')
    expect(top).toEqual({ playerId: tegan.id, servesIn: 8 })
  })
})

describe('matching a name typed one way against a roster typed another', () => {
  /** The roster as it was actually built on the phone: first names only. */
  const firstNamesOnly = {
    id: 's1',
    name: '2026',
    members: [
      { id: 'p1', name: 'Layna', number: '1' },
      { id: 'p2', name: 'Tegan', number: '4' },
      { id: 'p3', name: 'Aria', number: '5' },
    ],
  }

  const fileWithFullNames = (serves) => JSON.stringify({
    app: IMPORT_MARKER,
    kind: IMPORT_KIND,
    formatVersion: 1,
    season: {
      name: '2026',
      team: 'Bethel Tigers',
      roster: [
        { number: '1', name: 'Layna Blankenship' },
        { number: '4', name: 'Tegan Jodrey' },
        { number: '5', name: 'Aria Smith' },
      ],
    },
    games: [{ date: '2026-08-08', opponent: 'Georgetown A', serves }],
  })

  it('matches a full name in the file to a first name on the roster', () => {
    const result = parseHistoricalGames(fileWithFullNames([
      { name: 'Layna Blankenship', in: 5, out: 2 },
      { name: 'Tegan Jodrey', in: 10, out: 1 },
    ]), firstNamesOnly, makeId)

    expect(result.ok, result.reason).toBe(true)
    expect(result.events[0].entries).toEqual([
      { playerId: 'p1', in: 5, out: 2 },
      { playerId: 'p2', in: 10, out: 1 },
    ])
  })

  it('still matches when the roster has full names and the file has first names', () => {
    const fullNames = {
      id: 's1', name: '2026',
      members: [{ id: 'p1', name: 'Layna Blankenship', number: '1' }],
    }
    const file = JSON.stringify({
      app: IMPORT_MARKER, kind: IMPORT_KIND, formatVersion: 1,
      games: [{ opponent: 'X', serves: [{ name: 'Layna', in: 1, out: 0 }] }],
    })
    expect(parseHistoricalGames(file, fullNames, makeId).ok).toBe(true)
  })

  it('bridges through the jersey number when the names share nothing', () => {
    const nicknames = {
      id: 's1', name: '2026',
      members: [{ id: 'p1', name: 'Lay', number: '1' }],
    }
    const result = parseHistoricalGames(
      fileWithFullNames([{ name: 'Layna Blankenship', in: 3, out: 1 }]),
      nicknames,
      makeId,
    )
    expect(result.ok, result.reason).toBe(true)
    expect(result.events[0].entries[0].playerId).toBe('p1')
  })

  it('ignores case and stray spacing', () => {
    const result = parseHistoricalGames(
      fileWithFullNames([{ name: '  LAYNA   BLANKENSHIP ', in: 1, out: 0 }]),
      firstNamesOnly,
      makeId,
    )
    expect(result.ok, result.reason).toBe(true)
  })

  it('refuses rather than guesses when two players share a first name', () => {
    const twoLaynas = {
      id: 's1', name: '2026',
      members: [
        { id: 'p1', name: 'Layna B', number: '1' },
        { id: 'p2', name: 'Layna C', number: '2' },
      ],
    }
    const file = JSON.stringify({
      app: IMPORT_MARKER, kind: IMPORT_KIND, formatVersion: 1,
      games: [{ opponent: 'X', serves: [{ name: 'Layna', in: 1, out: 0 }] }],
    })
    const result = parseHistoricalGames(file, twoLaynas, makeId)

    expect(result.ok).toBe(false)
    expect(result.reason).toMatch(/More than one player/)
    expect(result.reason).toMatch(/full names/)
    expect(result.events).toEqual([])
  })

  it('names the roster when nothing matches, so the mismatch can be seen', () => {
    const result = parseHistoricalGames(
      fileWithFullNames([{ name: 'Somebody Else', in: 1, out: 0 }]),
      firstNamesOnly,
      makeId,
    )
    expect(result.ok).toBe(false)
    expect(result.reason).toMatch(/Somebody Else/)
    expect(result.reason).toMatch(/Layna, Tegan, Aria/)
    expect(result.reason).toMatch(/Nothing was imported/)
  })

  it('imports the real four-game file against a first-name roster', () => {
    const file = readFileSync('import/paper-games-1-4.json', 'utf8')
    const parsed = JSON.parse(file)

    // Exactly the roster the operator built: first names, real numbers.
    const asBuilt = {
      id: 's1',
      name: '2026',
      members: parsed.season.roster.map((player, index) => ({
        id: `p${index}`,
        name: player.name.split(' ')[0],
        number: player.number,
      })),
    }

    const result = parseHistoricalGames(file, asBuilt, makeId)
    expect(result.ok, result.reason).toBe(true)
    expect(result.events).toHaveLength(4)

    const totals = result.events.map((event) => [
      event.entries.reduce((sum, entry) => sum + entry.in, 0),
      event.entries.reduce((sum, entry) => sum + entry.out, 0),
    ])
    expect(totals).toEqual([[37, 15], [42, 15], [42, 17], [42, 19]])
  })
})
