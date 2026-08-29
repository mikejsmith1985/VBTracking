// The transcribed files are data the operator relies on, so they are checked like code:
// every game must parse, and every total must still reconcile with the handwritten sheet.
import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { parseHistoricalGames } from '../../src/state/historical-import.js'

/** The totals written at the bottom of each paper sheet. */
const SHEETS = {
  'Georgetown A': [37, 15],
  Blanchester: [42, 15],
  'Eastern A': [42, 17],
  CNE: [42, 19],
  'Fayetteville Smith': [32, 10],
}

const FILES = [
  ['the complete record', 'specs/003-seasons-and-career/historical-games.json', 5],
  ['the file for importing alongside the tracked game', 'import/paper-games-1-4.json', 4],
]

describe.each(FILES)('%s', (label, path, expectedGames) => {
  const text = readFileSync(path, 'utf8')
  const parsed = JSON.parse(text)

  const season = {
    id: 's1',
    name: parsed.season.name,
    members: parsed.season.roster.map((player, index) => ({
      id: `p${index}`, name: player.name, number: player.number,
    })),
  }

  let counter = 0
  const result = parseHistoricalGames(text, season, () => `g${counter += 1}`)

  it('parses', () => {
    expect(result.ok, result.reason).toBe(true)
    expect(result.events).toHaveLength(expectedGames)
  })

  it('names only players on the roster', () => {
    const ids = new Set(season.members.map((member) => member.id))
    for (const event of result.events) {
      for (const entry of event.entries) expect(ids.has(entry.playerId)).toBe(true)
    }
  })

  it('reconciles with the totals written on each sheet', () => {
    for (const event of result.events) {
      const totalIn = event.entries.reduce((sum, entry) => sum + entry.in, 0)
      const totalOut = event.entries.reduce((sum, entry) => sum + entry.out, 0)
      expect([totalIn, totalOut], event.opponent).toEqual(SHEETS[event.opponent])
    }
  })

  it('carries the context and the notes from the sheet', () => {
    for (const event of result.events) {
      expect(event.date, event.opponent).toMatch(/^\d{4}-\d{2}-\d{2}$/)
      expect(event.opponent).toBeTruthy()
      expect(event.location).toBeTruthy()
      expect(event.notes.length).toBeGreaterThan(10)
    }
  })
})

describe('the 1-4 file specifically', () => {
  const text = readFileSync('import/paper-games-1-4.json', 'utf8')

  it('leaves out the 29 August game, which is tracked in the app', () => {
    expect(text).not.toContain('Fayetteville Smith')
  })

  it('says why, so the file explains itself', () => {
    expect(JSON.parse(text).transcribedFrom).toMatch(/count it twice/)
  })

  it('keeps the whole roster, so every name still resolves', () => {
    expect(JSON.parse(text).season.roster).toHaveLength(9)
  })
})
