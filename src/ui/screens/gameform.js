// Editing a game's record outside a rally: who was played, where, the notes, and — for a
// game copied from paper — the serve figures themselves.
//
// Context, notes and historical entry live together because they are the same activity,
// done at the same time, with the same care. None of it is touched mid-match.
import { GAME_KIND } from '../../domain/events.js'
import { gameById, seasonMembers, activeSeason } from '../../domain/reducer.js'
import { gameResult, gameSummary } from '../../domain/aggregate.js'
import { esc } from '../html.js'

/** The form for an existing game, or a blank one for a game being entered from paper. */
export function gameFormView(state, ui) {
  const game = ui.editingGameId ? gameById(state, ui.editingGameId) : null
  const isNew = ui.editingGameId === 'new-historical'
  if (!game && !isNew) return '<div class="empty">That game no longer exists.</div>'

  const season = activeSeason(state)
  const isHistorical = isNew || game.kind === GAME_KIND.HISTORICAL

  return `
    <button class="btn" data-action="close-game" type="button">Back</button>
    <div class="season-head">
      <div class="season-name">${isNew ? 'A game from paper' : esc(game.opponent || 'Unnamed opponent')}</div>
      <div class="season-team">
        ${isHistorical ? 'Serves in and out only — that is all the paper had.' : `Tracked · ${resultText(game)}`}
      </div>
    </div>

    ${isHistorical ? '' : recordLink(game)}

    <form id="game-form" autocomplete="off">
      <div class="section-title">Who, where, when</div>
      <div class="context-grid">
        <label>Date<input name="date" type="date" value="${esc(game?.date ?? '')}"></label>
        <label>Court<input name="court" value="${esc(game?.court ?? '')}" maxlength="8"></label>
        <label class="wide">Opposing team<input name="opponent" value="${esc(game?.opponent ?? '')}" maxlength="60"></label>
        <label class="wide">Location<input name="location" value="${esc(game?.location ?? '')}" maxlength="60"></label>
      </div>

      ${isHistorical ? resultChoice(game) : matchResults(game)}
      ${isHistorical ? serveEntry(state, season, game) : ''}

      ${notesFields(game)}

      <div class="lineup-actions">
        <button class="btn btn-primary" type="submit">${isNew ? 'Add this game' : 'Save'}</button>
      </div>
    </form>
    ${isNew ? '' : discardControl(game, ui)}`
}

/**
 * The way in to a past game's serve record: every turn, and every serve in it.
 *
 * It sits above the form rather than inside it because opening it leaves this screen, and
 * anything typed here and not yet saved would go with it.
 */
function recordLink(game) {
  const summary = gameSummary(game)
  return `
    <button class="btn record-link" data-action="open-record" data-id="${game.id}" type="button">
      Serve record — ${summary.servesIn}/${summary.serves} in
      <small>See every turn, and correct anything mis-entered</small>
    </button>`
}

/**
 * Any game can be thrown away from here, not only the one in progress. A game entered
 * twice -- the same match imported from paper and also tracked live -- would otherwise
 * count twice in the season with no way to undo it.
 */
function discardControl(game, ui) {
  const isConfirming = ui.confirmingDiscardGame === game.id
  return `
    <div class="danger-zone">
      <button class="btn btn-danger" data-action="discard-game" data-id="${game.id}" type="button">
        ${isConfirming ? 'Discard this game?' : 'Discard this game'}
      </button>
      <div class="roster-count">
        ${isConfirming
          ? 'Tap again to discard. Everything recorded in this game is thrown away. The roster and the rest of the season are untouched.'
          : 'Removes this game and its figures from the season. Use it if the same game was entered twice.'}
      </div>
    </div>`
}

/** A game copied from paper has one result, because the paper recorded one. */
/**
 * Three boxes rather than one. Every paper sheet keeps "what went well" and "what to work
 * on" as separate lists, which says more about how the record is used than any free-text
 * box could -- and typing those headings by hand every game is work the app should do.
 */
function notesFields(game) {
  const box = (name, label, placeholder, value) => `
    <label class="notes-field">
      <span class="notes-label">${label}</span>
      <textarea name="${name}" rows="4" placeholder="${esc(placeholder)}"
                aria-label="${label}">${esc(value ?? '')}</textarea>
    </label>`

  return `
    <div class="section-title">Notes</div>
    ${box('wentWell', 'What went well', 'Communication. Following the ball.', game?.wentWell)}
    ${box('needsWork', 'What to work on', 'Body position. Being on time.', game?.needsWork)}
    ${box('notes', 'Anything else', 'Tough loss. Line situation.', game?.notes)}`
}

function resultChoice(game) {
  return `
    <div class="section-title">Result</div>
    ${choiceRow('result', game?.result ?? 'undecided')}`
}

/**
 * A tracked game has a result per match, and the game's own result follows from them.
 *
 * These stay editable after the fact. Marking a match as it ends is the fast path, but a
 * match ended in a hurry -- or before the app could ask -- would otherwise be stuck as
 * "not recorded" forever.
 */
function matchResults(game) {
  const matches = game?.matches ?? []
  if (matches.length === 0) return ''

  const rows = matches
    .map((match) => `
      <div class="match-result-row">
        <span class="match-result-label">Match ${match.index + 1}</span>
        ${choiceRow(`match-result-${match.index}`, match.result ?? 'undecided')}
      </div>`)
    .join('')

  return `
    <div class="section-title">Results</div>
    ${rows}
    <div class="roster-count">The game is won when more matches were won than lost.
      A match left unrecorded counts toward neither.</div>`
}

function choiceRow(name, current) {
  const option = (value, label) => `
    <label class="result-option">
      <input type="radio" name="${name}" value="${value}" ${current === value ? 'checked' : ''}>
      <span>${label}</span>
    </label>`

  return `<div class="result-choice">
    ${option('won', 'Won')}${option('lost', 'Lost')}${option('undecided', '—')}
  </div>`
}

/**
 * One row per player on the season's roster. Serves in and serves out, nothing else,
 * because nothing else was written down.
 */
function serveEntry(state, season, game) {
  const members = seasonMembers(state, season?.id)
  if (members.length === 0) return '<div class="empty">Add players to the season first.</div>'

  const existing = new Map((game?.entries ?? []).map((entry) => [entry.playerId, entry]))

  const rows = members
    .map((member) => {
      const entry = existing.get(member.id)
      return `
        <div class="serve-entry-row">
          <span class="jersey">${esc(member.number || '—')}</span>
          <span class="serve-entry-name">${esc(member.name)}</span>
          <input name="in-${member.id}" inputmode="numeric" value="${entry?.in ?? 0}" aria-label="${esc(member.name)} serves in">
          <input name="out-${member.id}" inputmode="numeric" value="${entry?.out ?? 0}" aria-label="${esc(member.name)} serves out">
        </div>`
    })
    .join('')

  return `
    <div class="section-title">Serves</div>
    <div class="serve-entry-head"><span></span><span></span><span>In</span><span>Out</span></div>
    ${rows}`
}

function resultText(game) {
  const result = gameResult(game)
  if (result === 'won') return 'Won'
  if (result === 'lost') return 'Lost'
  return 'Result not recorded'
}

/** Reads the form back into the shape the events want. Presentation only; no rules. */
export function readGameForm(form, members) {
  const value = (name) => form.querySelector(`[name="${name}"]`)?.value ?? ''
  const count = (name) => {
    const parsed = Number.parseInt(value(name), 10)
    return Number.isFinite(parsed) ? parsed : 0
  }

  return {
    context: {
      date: value('date') || null,
      opponent: value('opponent').trim(),
      location: value('location').trim(),
      court: value('court').trim(),
    },
    notes: {
      wentWell: value('wentWell'),
      needsWork: value('needsWork'),
      notes: value('notes'),
    },
    result: form.querySelector('[name="result"]:checked')?.value ?? 'undecided',
    matchResults: readMatchResults(form),
    entries: members.map((member) => ({
      playerId: member.id,
      in: count(`in-${member.id}`),
      out: count(`out-${member.id}`),
    })),
  }
}

/** One result per match of a tracked game, in match order. */
function readMatchResults(form) {
  return [...form.querySelectorAll('[name^="match-result-"]:checked')].map((input) => ({
    index: Number.parseInt(input.name.replace('match-result-', ''), 10),
    result: input.value,
  }))
}
