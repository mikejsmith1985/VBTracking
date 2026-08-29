// The form for a game's record: who was played, the notes, and -- for a game copied from
// paper -- the serve figures. Proves it offers serve entry only where serves were never
// tracked, and that it reads back exactly what was typed.
import { describe, it, expect } from 'vitest'
import * as E from '../../src/domain/events.js'
import { gameFormView, readGameForm } from '../../src/ui/screens/gameform.js'
import { build, roster } from '../helpers.js'

const { OUT, IN_POINT } = E.OUTCOME
const context = { date: '2026-08-08', opponent: 'Georgetown A', location: 'Fayetteville', court: '1' }

const tracked = build(
  roster(3), E.startGame('g1'), E.setGameContext('g1', context),
  E.setGameNotes('g1', 'Good: won the first match.'),
  E.selectServer('p1'), E.recordServe(IN_POINT), E.recordServe(OUT),
)

const paper = build(
  roster(3),
  E.addHistoricalGame('h1', 'season-1', context, [
    { playerId: 'p1', in: 9, out: 2 },
    { playerId: 'p2', in: 4, out: 1 },
  ], 'Work on: talking.'),
)

describe('a game that was tracked', () => {
  const html = gameFormView(tracked, { editingGameId: 'g1' })

  it('offers its context for correction, filled in', () => {
    expect(html).toContain('value="2026-08-08"')
    expect(html).toContain('value="Georgetown A"')
    expect(html).toContain('value="Fayetteville"')
  })

  it('offers its notes for editing, filled in', () => {
    expect(html).toContain('Good: won the first match.')
  })

  it('offers no serve entry, because those serves were recorded properly', () => {
    expect(html).not.toContain('serve-entry-row')
  })

  it('offers no result choice, because it follows from the matches', () => {
    expect(html).not.toContain('name="result"')
  })

  it('says how the game turned out', () => {
    expect(html).toContain('Result not recorded')
  })
})

describe('a game copied from paper', () => {
  const html = gameFormView(paper, { editingGameId: 'h1' })

  it('says plainly what it holds', () => {
    expect(html).toContain('Serves in and out only')
  })

  it('offers a row per player on the season roster', () => {
    expect(html.split('serve-entry-row').length - 1).toBe(3)
  })

  it('fills in the figures already recorded', () => {
    expect(html).toContain('value="9"')
    expect(html).toContain('value="2"')
  })

  it('offers zero for a player with nothing recorded, since that is a real figure here', () => {
    expect(html).toContain('value="0"')
  })

  it('offers the result, including a way not to record one', () => {
    expect(html).toContain('value="won"')
    expect(html).toContain('value="lost"')
    expect(html).toContain('value="undecided"')
  })

  it('offers its notes', () => {
    expect(html).toContain('Work on: talking.')
  })
})

describe('a new game from paper', () => {
  const html = gameFormView(paper, { editingGameId: 'new-historical' })

  it('starts blank, with serve entry ready', () => {
    expect(html).toContain('A game from paper')
    expect(html).toContain('serve-entry-row')
    expect(html).toContain('Add this game')
  })

  it('says so when there is nobody to record figures for', () => {
    const empty = build(E.createSeason('s1', '2026', 'Tigers'))
    expect(gameFormView(empty, { editingGameId: 'new-historical' })).toContain('Add players to the season first')
  })
})

describe('a game that no longer exists', () => {
  it('says so rather than rendering an empty form', () => {
    expect(gameFormView(paper, { editingGameId: 'gone' })).toContain('no longer exists')
  })
})

describe('reading the form back', () => {
  const members = [{ id: 'p1', name: 'A', number: '1' }, { id: 'p2', name: 'B', number: '2' }]

  /** A stand-in for the DOM form, answering the queries readGameForm makes. */
  function fakeForm(values, checkedResult = 'won') {
    return {
      querySelector(selector) {
        if (selector === '[name="result"]:checked') return checkedResult ? { value: checkedResult } : null
        const name = selector.match(/\[name="(.+)"\]/)?.[1]
        return name in values ? { value: values[name] } : null
      },
    }
  }

  it('returns the context, notes, result and entries', () => {
    const read = readGameForm(fakeForm({
      date: '2026-08-08', opponent: ' Georgetown A ', location: ' Fayetteville ', court: '1',
      notes: 'Some notes', 'in-p1': '9', 'out-p1': '2', 'in-p2': '4', 'out-p2': '1',
    }), members)

    expect(read.context).toEqual({
      date: '2026-08-08', opponent: 'Georgetown A', location: 'Fayetteville', court: '1',
    })
    expect(read.notes).toBe('Some notes')
    expect(read.result).toBe('won')
    expect(read.entries).toEqual([
      { playerId: 'p1', in: 9, out: 2 },
      { playerId: 'p2', in: 4, out: 1 },
    ])
  })

  it('treats a blank date as no date rather than an empty string', () => {
    expect(readGameForm(fakeForm({ date: '' }), []).context.date).toBeNull()
  })

  it('reads a blank or non-numeric count as zero rather than failing', () => {
    const read = readGameForm(fakeForm({ 'in-p1': '', 'out-p1': 'x' }), [members[0]])
    expect(read.entries[0]).toEqual({ playerId: 'p1', in: 0, out: 0 })
  })

  it('defaults to undecided when no result is chosen', () => {
    expect(readGameForm(fakeForm({}, null), []).result).toBe('undecided')
  })
})


describe('discarding a game from its own form', () => {
  it('is offered for a game that exists', () => {
    const html = gameFormView(paper, { editingGameId: 'h1' })
    expect(html).toContain('data-action="discard-game"')
    expect(html).toContain('data-id="h1"')
  })

  it('says what it is for, since the reason is not obvious', () => {
    const html = gameFormView(paper, { editingGameId: 'h1' })
    expect(html).toContain('the same game was entered twice')
  })

  it('takes two taps, and states the consequence before the second', () => {
    const idle = gameFormView(paper, { editingGameId: 'h1' })
    expect(idle).not.toContain('Discard this game?')

    const armed = gameFormView(paper, { editingGameId: 'h1', confirmingDiscardGame: 'h1' })
    expect(armed).toContain('Discard this game?')
    expect(armed).toContain('rest of the season are untouched')
  })

  it('is armed per game, so arming one does not light up another', () => {
    const other = gameFormView(paper, { editingGameId: 'h1', confirmingDiscardGame: 'somewhere-else' })
    expect(other).not.toContain('Discard this game?')
  })

  it('is offered for a tracked game too', () => {
    expect(gameFormView(tracked, { editingGameId: 'g1' })).toContain('data-action="discard-game"')
  })

  it('is not offered for a game that has not been created yet', () => {
    expect(gameFormView(paper, { editingGameId: 'new-historical' })).not.toContain('data-action="discard-game"')
  })
})
