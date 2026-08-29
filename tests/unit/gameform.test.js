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
  E.setGameNotes('g1', { wentWell: 'Communication.', needsWork: 'Body position.', notes: 'Tough loss.' }),
  E.selectServer('p1'), E.recordServe(IN_POINT), E.recordServe(OUT),
  E.endMatch(E.MATCH_RESULT.WON),
)

const paper = build(
  roster(3),
  E.addHistoricalGame('h1', 'season-1', context, [
    { playerId: 'p1', in: 9, out: 2 },
    { playerId: 'p2', in: 4, out: 1 },
  ], { wentWell: 'Lots of serves in.', needsWork: 'Talking.', notes: '' }),
)

describe('a game that was tracked', () => {
  const html = gameFormView(tracked, { editingGameId: 'g1' })

  it('offers its context for correction, filled in', () => {
    expect(html).toContain('value="2026-08-08"')
    expect(html).toContain('value="Georgetown A"')
    expect(html).toContain('value="Fayetteville"')
  })

  it('offers the two lists the sheets keep, filled in, plus anywhere else', () => {
    expect(html).toContain('What went well')
    expect(html).toContain('Communication.')
    expect(html).toContain('What to work on')
    expect(html).toContain('Body position.')
    expect(html).toContain('Anything else')
    expect(html).toContain('Tough loss.')
  })

  it('offers no serve entry, because those serves were recorded properly', () => {
    expect(html).not.toContain('serve-entry-row')
  })

  it('offers a result per match, correctable long after the match ended', () => {
    expect(html).toContain('Match 1')
    expect(html).toContain('name="match-result-0"')
    // Match 2 opened when match 1 ended; match 3 does not exist yet, so it is not offered.
    expect(html).toContain('name="match-result-1"')
    expect(html).not.toContain('name="match-result-2"')
  })

  it('checks the result each match already carries', () => {
    expect(html).toMatch(/name="match-result-0" value="won" checked/)
    expect(html).toMatch(/name="match-result-1" value="undecided" checked/)
  })

  it('offers no single game result, because it follows from the matches', () => {
    expect(html).not.toContain('name="result"')
    expect(html).toContain('won when more matches were won than lost')
  })

  it('says how the game turned out so far', () => {
    expect(html).toContain('Won')
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

  it('offers its notes in the same three parts', () => {
    expect(html).toContain('Lots of serves in.')
    expect(html).toContain('Talking.')
  })

  it('offers one result for the whole game, since the paper recorded one', () => {
    expect(html).toContain('name="result"')
    expect(html).not.toContain('name="match-result-')
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
  function fakeForm(values, checkedResult = 'won', matchResults = []) {
    return {
      querySelector(selector) {
        if (selector === '[name="result"]:checked') return checkedResult ? { value: checkedResult } : null
        const name = selector.match(/\[name="(.+)"\]/)?.[1]
        return name in values ? { value: values[name] } : null
      },
      querySelectorAll() {
        return matchResults.map(({ index, result }) => ({ name: `match-result-${index}`, value: result }))
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
    expect(read.notes).toEqual({ wentWell: '', needsWork: '', notes: 'Some notes' })
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

  it('reads one result per match, in match order', () => {
    const read = readGameForm(fakeForm({}, null, [
      { index: 0, result: 'won' }, { index: 1, result: 'lost' }, { index: 2, result: 'undecided' },
    ]), [])

    expect(read.matchResults).toEqual([
      { index: 0, result: 'won' },
      { index: 1, result: 'lost' },
      { index: 2, result: 'undecided' },
    ])
  })

  it('reads no match results when there are none to read', () => {
    expect(readGameForm(fakeForm({}, null), []).matchResults).toEqual([])
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

describe('reading the three notes boxes back', () => {
  /** A stand-in that answers by field name, as the real form does. */
  const formOf = (values) => ({
    querySelector: (selector) => {
      const name = selector.match(/\[name="([^"]+)"\]/)?.[1]
      return name && name in values ? { value: values[name] } : null
    },
    querySelectorAll: () => [],
  })

  it('returns the two lists separately, not as one blob', () => {
    const read = readGameForm(formOf({
      wentWell: 'Communication', needsWork: 'Body position', notes: 'Tough loss',
    }), [])

    expect(read.notes).toEqual({
      wentWell: 'Communication',
      needsWork: 'Body position',
      notes: 'Tough loss',
    })
  })

  it('returns empty strings rather than undefined for boxes left blank', () => {
    expect(readGameForm(formOf({}), []).notes).toEqual({ wentWell: '', needsWork: '', notes: '' })
  })
})
