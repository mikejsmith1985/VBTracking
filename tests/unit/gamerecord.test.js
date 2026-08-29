// The record screen renders whatever the log actually holds, including a game nobody is
// tracking any more. These are pure string checks: no DOM, no store.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'
import { gameRecordView, nextOutcome, turnKey } from '../../src/ui/screens/gamerecord.js'
import { build, roster } from '../helpers.js'

const { OUT, IN_POINT, IN_NO_POINT } = E.OUTCOME

const played = build(
  roster(3), E.startGame('g1', 'season-1'),
  E.setGameContext('g1', { date: '2026-03-14', opponent: 'Northside', location: '', court: '' }),
  E.selectServer('p1'), E.recordServe(IN_POINT), E.recordServe(IN_POINT), E.recordServe(OUT),
  E.selectServer('p2'), E.recordServe(IN_NO_POINT),
  E.endMatch(E.MATCH_RESULT.WON),
)

const at = (matchIndex, ordinal) => ({ recordGameId: 'g1', openTurn: { matchIndex, ordinal } })

describe('the record of a game', () => {
  const html = gameRecordView(played, { recordGameId: 'g1' })

  it('names the game it is showing', () => {
    expect(html).toContain('Northside')
    expect(html).toContain('2026-03-14')
  })

  it('shows a row for every turn that recorded a serve', () => {
    expect([...html.matchAll(/data-action="open-turn"/g)]).toHaveLength(2)
  })

  it('gives each match its own figures', () => {
    expect(html).toContain('Match 1 · 3/4 in · 2 pts')
  })

  it('carries the match and the ordinal on every turn, so a tap can name it', () => {
    expect(html).toContain('data-match="0" data-ordinal="0"')
    expect(html).toContain('data-match="0" data-ordinal="1"')
  })

  it('leads back out', () => {
    expect(html).toContain('data-action="close-record"')
  })

  it('says so plainly when the game has gone', () => {
    expect(gameRecordView(played, { recordGameId: 'nope' })).toContain('no longer exists')
  })

  it('refuses a game from paper, which has no turns to show', () => {
    const paper = build(roster(2), E.addHistoricalGame('h1', 'season-1',
      { date: null, opponent: 'X', location: '', court: '' }, [{ playerId: 'p1', in: 3, out: 1 }]))
    expect(gameRecordView(paper, { recordGameId: 'h1' })).toContain('came from paper')
  })
})

describe('a turn opened for correction', () => {
  const html = gameRecordView(played, at(0, 0))

  it('turns every serve into its own target', () => {
    expect([...html.matchAll(/data-action="cycle-serve"/g)]).toHaveLength(3)
    expect(html).toContain('data-index="0"')
    expect(html).toContain('data-index="2"')
  })

  it('labels each serve with what it currently says', () => {
    expect(html).toMatch(/data-index="0"[\s\S]*?>\s*Pt\s*<\/button>/)
    expect(html).toMatch(/data-index="2"[\s\S]*?>\s*Out\s*<\/button>/)
  })

  it('offers a serve to be added and the last one taken back', () => {
    expect(html).toContain('data-action="add-serve"')
    expect(html).toContain('data-action="drop-serve"')
  })

  it('never offers to remove the only serve, which would empty the turn', () => {
    const single = build(
      roster(2), E.startGame('g1', 'season-1'),
      E.selectServer('p1'), E.recordServe(OUT),
    )
    expect(gameRecordView(single, at(0, 0))).toMatch(/data-action="drop-serve"[^>]*disabled/s)
  })

  it('opens only the turn that was tapped', () => {
    expect([...html.matchAll(/data-action="cycle-serve"/g)]).toHaveLength(3)
    expect(html).toContain('data-action="open-turn"') // the other turn is still a row
  })

  it('asks before deleting, and says what deleting costs', () => {
    expect(html).toContain('Delete this turn')
    expect(html).not.toContain('Tap again to delete')

    const armed = gameRecordView(played, { ...at(0, 0), confirmingDeleteTurn: turnKey(0, 0) })
    expect(armed).toContain('Delete this whole turn?')
    expect(armed).toContain('Tap again to delete')
  })

  it('lists the other players only when the reassignment is asked for', () => {
    expect(html).not.toContain('data-action="reassign-to"')

    const choosing = gameRecordView(played, { ...at(0, 0), reassigningTurn: turnKey(0, 0) })
    expect([...choosing.matchAll(/data-action="reassign-to"/g)]).toHaveLength(2)
    expect(choosing).not.toMatch(/data-action="reassign-to"[^>]*data-id="p1"/)
  })
})

describe('cycling a serve', () => {
  it('moves a point to in, in to out, and out back to a point', () => {
    expect(nextOutcome(IN_POINT)).toBe(IN_NO_POINT)
    expect(nextOutcome(IN_NO_POINT)).toBe(OUT)
    expect(nextOutcome(OUT)).toBe(IN_POINT)
  })

  it('returns a serve to where it started in three taps', () => {
    expect(nextOutcome(nextOutcome(nextOutcome(IN_POINT)))).toBe(IN_POINT)
  })

  it('falls back to out rather than an undefined outcome', () => {
    expect(nextOutcome('nonsense')).toBe(OUT)
  })
})

describe('naming a turn', () => {
  it('distinguishes the same ordinal in different matches', () => {
    expect(turnKey(0, 3)).not.toBe(turnKey(1, 3))
  })
})
