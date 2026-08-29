// The serve record of a game already played: every turn, in the order it happened, and
// every serve in it open to correction.
//
// It is a screen of its own rather than a section of the game form, for two reasons. The
// corrections here save the moment they are tapped -- there is nothing to submit, and
// nothing half-typed to lose. And it is read at least as often as it is written: this is
// the only place a game that is no longer the current one can be looked at serve by serve.
import { OUTCOME, GAME_KIND } from '../../domain/events.js'
import { gameById } from '../../domain/reducer.js'
import { colorForTurn } from '../../domain/palette.js'
import { turnStats, matchScore, matchStats, isOverServeLimit } from '../../domain/stats.js'
import { esc, playerById } from '../html.js'

// Tapping a serve moves it round this ring, so any mark can be corrected to any other
// without a menu. Three taps returns it to where it started.
const NEXT_OUTCOME = {
  [OUTCOME.IN_POINT]: OUTCOME.IN_NO_POINT,
  [OUTCOME.IN_NO_POINT]: OUTCOME.OUT,
  [OUTCOME.OUT]: OUTCOME.IN_POINT,
}

const SERVE_LABEL = {
  [OUTCOME.IN_POINT]: 'Pt',
  [OUTCOME.IN_NO_POINT]: 'In',
  [OUTCOME.OUT]: 'Out',
}

const SERVE_CLASS = {
  [OUTCOME.IN_POINT]: 'serve-point',
  [OUTCOME.IN_NO_POINT]: 'serve-in',
  [OUTCOME.OUT]: 'serve-out',
}

/** The outcome a serve becomes when its mark is tapped. */
export function nextOutcome(outcome) {
  return NEXT_OUTCOME[outcome] ?? OUTCOME.OUT
}

/** Identifies a turn within a game, for the confirmations held in UI state. */
export function turnKey(matchIndex, ordinal) {
  return `${matchIndex}:${ordinal}`
}

/** The whole record: every match of the game, every turn within it. */
export function gameRecordView(state, ui) {
  const game = gameById(state, ui.recordGameId)
  if (!game) return '<div class="empty">That game no longer exists.</div>'
  if (game.kind !== GAME_KIND.TRACKED) {
    return `${backButton()}<div class="empty">This game came from paper, so it has no serve-by-serve
      record. Its figures are on the game itself.</div>`
  }

  return `
    ${backButton()}
    <div class="season-head">
      <div class="season-name">${esc(game.opponent || 'Unnamed opponent')}</div>
      <div class="season-team">${esc(game.date ?? 'No date')} · serve record</div>
    </div>
    <div class="roster-count">Tap a turn to correct it. Every change saves as you make it, and Undo still works.</div>
    ${game.matches.map((match) => matchSection(state, ui, match)).join('')}`
}

function backButton() {
  return '<button class="btn" data-action="close-record" type="button">Back</button>'
}

function matchSection(state, ui, match) {
  const played = match.turns.filter((turn) => turn.serves.length > 0)
  const totals = [...matchStats(match).values()]
  const serves = totals.reduce((sum, each) => sum + each.serves, 0)
  const servesIn = totals.reduce((sum, each) => sum + each.servesIn, 0)

  return `
    <div class="section-title">
      Match ${match.index + 1} · ${servesIn}/${serves} in · ${matchScore(match)} pts
    </div>
    ${played.length === 0
      ? '<div class="empty">No serves were recorded in this match.</div>'
      : played.map((turn) => turnBlock(state, ui, match, turn)).join('')}`
}

function turnBlock(state, ui, match, turn) {
  const isOpen = ui.openTurn?.matchIndex === match.index && ui.openTurn?.ordinal === turn.ordinal
  return isOpen ? turnEditor(state, ui, match, turn) : turnRow(state, match, turn)
}

function turnRow(state, match, turn) {
  const stats = turnStats(turn)
  const player = playerById(state.roster, turn.playerId)

  return `
    <button class="record-turn" style="--turn-color:${colorForTurn(turn.ordinal)}" type="button"
            data-action="open-turn" data-match="${match.index}" data-ordinal="${turn.ordinal}">
      <span class="record-turn-no">${turn.ordinal + 1}</span>
      <span class="record-turn-who">
        <b>${esc(player?.number) || '–'}</b> ${esc(player?.name ?? 'Removed player')}
      </span>
      <span class="record-turn-marks">${turn.serves.map(serveDot).join('')}</span>
      <span class="record-turn-figures">
        ${isOverServeLimit(turn) ? '⚠ ' : ''}${stats.serves} · ${stats.servesIn} in · ${stats.points} pt
      </span>
    </button>`
}

function serveDot(serve) {
  return `<i class="mark ${MARK_CLASS[serve.outcome]}"></i>`
}

const MARK_CLASS = {
  [OUTCOME.IN_POINT]: 'mark-point',
  [OUTCOME.IN_NO_POINT]: 'mark-in',
  [OUTCOME.OUT]: 'mark-out',
}

/**
 * One turn, opened for correction. The serves are the buttons themselves: tapping one
 * cycles it, which is the correction actually wanted almost every time -- a serve recorded
 * as a point that was not, or an out that landed in.
 */
function turnEditor(state, ui, match, turn) {
  const player = playerById(state.roster, turn.playerId)
  const at = `data-match="${match.index}" data-ordinal="${turn.ordinal}"`
  const key = turnKey(match.index, turn.ordinal)

  return `
    <div class="turn-editor" style="--turn-color:${colorForTurn(turn.ordinal)}">
      <div class="turn-editor-head">
        <span class="record-turn-no">${turn.ordinal + 1}</span>
        <span class="record-turn-who"><b>${esc(player?.number) || '–'}</b> ${esc(player?.name ?? 'Removed player')}</span>
        <button class="btn-undo" data-action="close-turn" type="button">Done</button>
      </div>

      <div class="serve-row">
        ${turn.serves.map((serve, index) => `
          <button class="serve-pill ${SERVE_CLASS[serve.outcome]}" type="button"
                  data-action="cycle-serve" ${at} data-index="${index}"
                  aria-label="Serve ${index + 1}: ${SERVE_LABEL[serve.outcome]}">
            ${SERVE_LABEL[serve.outcome]}
          </button>`).join('')}
        <button class="serve-pill serve-add" data-action="add-serve" ${at} type="button"
                aria-label="Add a serve">+</button>
      </div>
      <div class="roster-count">Tap a serve to change it: point, then in, then out. "+" adds one to the end.</div>

      <div class="turn-editor-actions">
        <button class="btn" data-action="drop-serve" ${at} type="button"
                ${turn.serves.length > 1 ? '' : 'disabled'}>Remove last serve</button>
        <button class="btn" data-action="reassign-turn" ${at} type="button">
          ${ui.reassigningTurn === key ? 'Cancel' : 'Wrong player?'}
        </button>
      </div>

      ${ui.reassigningTurn === key ? reassignChoices(state, at, turn) : ''}

      <button class="btn btn-danger" data-action="delete-turn" ${at} type="button">
        ${ui.confirmingDeleteTurn === key ? 'Delete this whole turn?' : 'Delete this turn'}
      </button>
      ${ui.confirmingDeleteTurn === key
        ? '<div class="roster-count">Tap again to delete. Every serve in it goes too, and the turns after it renumber.</div>'
        : ''}
    </div>`
}

/** Every player on the roster, because a turn can be credited to anyone who was there. */
function reassignChoices(state, at, turn) {
  const buttons = state.roster
    .filter((player) => player.id !== turn.playerId)
    .map((player) => `
      <button class="btn reassign-choice" data-action="reassign-to" ${at} data-id="${player.id}" type="button">
        <b>${esc(player.number) || '–'}</b> ${esc(player.name)}
      </button>`)
    .join('')

  return `<div class="reassign-list">${buttons || '<div class="empty">No one else on the roster.</div>'}</div>`
}
