// Roster setup. Shows exactly as many rows as there are players -- never a placeholder
// row (FR-003) -- and confirms before a deletion that would discard recorded serves.
import { MAX_ROSTER } from '../../domain/events.js'
import { esc } from '../html.js'

/** The roster screen. It has no dock: nothing here is used mid-rally. */
export function view(context) {
  const { state, ui } = context
  const isFull = state.roster.length >= MAX_ROSTER

  return { screen: addForm(isFull) + list(state, ui) + count(state, isFull), dock: '' }
}

function addForm(isFull) {
  const disabled = isFull ? 'disabled' : ''
  return `
    <div class="section-title">Add a player</div>
    <form class="roster-add" id="add-player-form" autocomplete="off">
      <input name="number" data-focus="add-number" inputmode="numeric" maxlength="4"
             placeholder="#" aria-label="Jersey number" ${disabled}>
      <input name="name" data-focus="add-name" maxlength="24"
             placeholder="Player name" aria-label="Player name" ${disabled}>
      <button type="submit" ${disabled}>Add</button>
    </form>`
}

function list(state, ui) {
  if (state.roster.length === 0) {
    return `<div class="empty"><strong>Roster is empty</strong>Add your first player above.</div>`
  }
  return `<div class="section-title">Roster</div>` + state.roster.map((player) => row(player, ui)).join('')
}

function row(player, ui) {
  const isConfirming = ui.confirmingRemoveId === player.id

  return `
    <div class="player-row">
      <input data-edit="${player.id}" data-field="number" data-focus="num-${player.id}"
             inputmode="numeric" maxlength="4" value="${esc(player.number)}" aria-label="Jersey number">
      <input data-edit="${player.id}" data-field="name" data-focus="name-${player.id}"
             maxlength="24" value="${esc(player.name)}" aria-label="Player name">
      <button class="btn-remove" data-action="remove-player" data-id="${player.id}" type="button"
              aria-label="Remove ${esc(player.name)}">${isConfirming ? 'Delete?' : '×'}</button>
    </div>
    ${isConfirming ? confirmNote() : ''}`
}

function confirmNote() {
  return `<div class="roster-count">Tap again to remove. Their recorded serves will be discarded.</div>`
}

function count(state, isFull) {
  const limitNote = isFull ? ` — the roster is full` : ''
  return `<div class="roster-count">${state.roster.length} of ${MAX_ROSTER} players${limitNote}.</div>`
}
