// Editing a game's record outside a rally: who was played, where, the notes, and — for a
// game copied from paper — the serve figures themselves.
//
// Context, notes and historical entry live together because they are the same activity,
// done at the same time, with the same care. None of it is touched mid-match.
import { GAME_KIND } from '../../domain/events.js'
import { gameById, seasonMembers, activeSeason } from '../../domain/reducer.js'
import { gameResult } from '../../domain/aggregate.js'
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

    <form id="game-form" autocomplete="off">
      <div class="section-title">Who, where, when</div>
      <div class="context-grid">
        <label>Date<input name="date" type="date" value="${esc(game?.date ?? '')}"></label>
        <label>Court<input name="court" value="${esc(game?.court ?? '')}" maxlength="8"></label>
        <label class="wide">Opposing team<input name="opponent" value="${esc(game?.opponent ?? '')}" maxlength="60"></label>
        <label class="wide">Location<input name="location" value="${esc(game?.location ?? '')}" maxlength="60"></label>
      </div>

      ${isHistorical ? resultChoice(game) : ''}
      ${isHistorical ? serveEntry(state, season, game) : ''}

      <div class="section-title">Notes</div>
      <textarea name="notes" rows="8" placeholder="What went well. What to work on."
                aria-label="Notes">${esc(game?.notes ?? '')}</textarea>

      <div class="lineup-actions">
        <button class="btn btn-primary" type="submit">${isNew ? 'Add this game' : 'Save'}</button>
      </div>
    </form>`
}

function resultChoice(game) {
  const current = game?.result ?? 'undecided'
  const option = (value, label) => `
    <label class="result-option">
      <input type="radio" name="result" value="${value}" ${current === value ? 'checked' : ''}>
      <span>${label}</span>
    </label>`

  return `
    <div class="section-title">Result</div>
    <div class="result-choice">
      ${option('won', 'Won')}${option('lost', 'Lost')}${option('undecided', 'Not recorded')}
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
    notes: value('notes'),
    result: form.querySelector('[name="result"]:checked')?.value ?? 'undecided',
    entries: members.map((member) => ({
      playerId: member.id,
      in: count(`in-${member.id}`),
      out: count(`out-${member.id}`),
    })),
  }
}
