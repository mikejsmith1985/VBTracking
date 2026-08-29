// Bootstraps the app: builds the store, renders the active screen, and routes every tap.
// All interaction handling lives here so the screen modules stay render-only.
import { createStore } from '../state/store.js'
import { createLocalStoragePersistence } from '../state/persistence.js'
import * as E from '../domain/events.js'
import { currentGame } from '../domain/reducer.js'
import * as track from './screens/track.js'
import * as stats from './screens/stats.js'
import * as roster from './screens/roster.js'

const SCREENS = { track, stats, roster }

// Two serves cannot physically occur this close together, so a tap inside this window is
// a stray repeat -- a double-tap on the same control -- and is ignored (FR-023).
const REPEAT_TAP_GUARD_MS = 300

const STORAGE_PROBLEMS = {
  unavailable: 'Storage is unavailable. Serves are being kept in memory only and will be lost if the app closes.',
  corrupt: 'Saved data could not be read, so it was not loaded. Nothing has been overwritten yet.',
  'unsupported-version': 'Saved data was written by a newer version of this app and was not loaded.',
}

const store = createStore(createLocalStoragePersistence())

const ui = {
  tab: 'track',
  scope: 'match',
  pickerOpen: false,
  confirmingRemoveId: null,
  confirmingEndMatch: false,
  confirmingDiscardGame: false,
  message: null,
}

// Destructive actions each arm a flag on the first tap and commit on the second. A tap on
// anything else disarms them, so a confirmation is never left hanging.
const CONFIRMATIONS = {
  'remove-player': 'confirmingRemoveId',
  'end-match': 'confirmingEndMatch',
  'discard-game': 'confirmingDiscardGame',
}

const screenElement = document.getElementById('screen')
const dockElement = document.getElementById('dock')
const bannerElement = document.getElementById('banner')

let lastServeAt = 0

// --- Rendering ----------------------------------------------------------------

function render() {
  const focus = captureFocus()
  const view = SCREENS[ui.tab].view({ state: store.getState(), store, ui })

  screenElement.innerHTML = view.screen
  dockElement.innerHTML = view.dock ?? ''

  renderTabs()
  renderBanner()
  restoreFocus(focus)
}

function renderTabs() {
  for (const tab of document.querySelectorAll('.tab')) {
    tab.setAttribute('aria-current', String(tab.dataset.tab === ui.tab))
  }
}

function renderBanner() {
  const text = ui.message ?? STORAGE_PROBLEMS[store.storageStatus()] ?? null
  bannerElement.textContent = text ?? ''
  bannerElement.hidden = text === null
}

/** Remembers which field had focus so a re-render does not interrupt typing. */
function captureFocus() {
  const element = document.activeElement
  if (!element?.dataset?.focus) return null
  return { key: element.dataset.focus, start: element.selectionStart, end: element.selectionEnd }
}

function restoreFocus(focus) {
  if (!focus) return
  const element = document.querySelector(`[data-focus="${focus.key}"]`)
  if (!element) return

  element.focus()
  if (focus.start === null || focus.start === undefined) return
  try {
    element.setSelectionRange(focus.start, focus.end)
  } catch {
    // Not every input type supports a selection range; focus alone is enough.
  }
}

// --- Actions ------------------------------------------------------------------

const ACTIONS = {
  tab: (element) => { ui.tab = element.dataset.tab; ui.pickerOpen = false },
  scope: (element) => { ui.scope = element.dataset.scope },
  'toggle-picker': () => { ui.pickerOpen = !ui.pickerOpen },
  'start-game': () => dispatch(E.startGame(newId())),
  'select-server': (element) => { ui.pickerOpen = false; dispatch(E.selectServer(element.dataset.id)) },
  serve: (element) => recordServe(element.dataset.outcome),
  undo: () => { store.undo() },
  'end-match': () => confirmThen('confirmingEndMatch', true, () => dispatch(E.endMatch())),
  'remove-player': (element) => {
    const playerId = element.dataset.id
    confirmThen('confirmingRemoveId', playerId, () => dispatch(E.removePlayer(playerId)))
  },
  'discard-game': () => {
    const game = currentGame(store.getState())
    if (!game) return
    confirmThen('confirmingDiscardGame', true, () => dispatch(E.discardGame(game.id)))
  },
}

function recordServe(outcome) {
  const now = Date.now()
  if (now - lastServeAt < REPEAT_TAP_GUARD_MS) return
  lastServeAt = now
  dispatch(E.recordServe(outcome))
}

/** Two-step confirmation, avoiding a native dialog that would block the whole session. */
function confirmThen(flag, armedValue, commit) {
  if (ui[flag] !== armedValue) {
    ui[flag] = armedValue
    return
  }
  ui[flag] = disarmed(armedValue)
  commit()
}

function disarmed(armedValue) {
  return typeof armedValue === 'boolean' ? false : null
}

function dispatch(event) {
  const result = store.dispatch(event)
  ui.message = result.accepted ? null : result.reason
}

// --- Wiring -------------------------------------------------------------------

document.addEventListener('click', (event) => {
  const target = event.target.closest('[data-action]')
  if (!target || target.disabled) return

  const handler = ACTIONS[target.dataset.action]
  if (!handler) return

  clearPendingConfirmations(target.dataset.action)
  handler(target)
  render()
})

document.addEventListener('submit', (event) => {
  if (event.target.id !== 'add-player-form') return
  event.preventDefault()

  const form = event.target
  const name = form.querySelector('[name="name"]').value
  const number = form.querySelector('[name="number"]').value

  const result = store.dispatch(E.addPlayer(newId(), name, number))
  ui.message = result.accepted ? null : result.reason
  if (result.accepted) form.reset()

  render()
  document.querySelector('[data-focus="add-number"]')?.focus()
})

document.addEventListener('change', (event) => {
  const field = event.target.closest('[data-edit]')
  if (!field) return

  const player = store.getState().roster.find((each) => each.id === field.dataset.edit)
  if (!player) return

  const edited = { ...player, [field.dataset.field]: field.value }
  dispatch(E.editPlayer(player.id, edited.name, edited.number))
  render()
})

/** A tap on anything else cancels a confirmation the operator did not follow through on. */
function clearPendingConfirmations(action) {
  for (const [owner, flag] of Object.entries(CONFIRMATIONS)) {
    if (owner !== action) ui[flag] = disarmed(ui[flag])
  }
  ui.message = null
}

function newId() {
  if (globalThis.crypto?.randomUUID) return globalThis.crypto.randomUUID()
  return `id-${Date.now()}-${Math.random().toString(16).slice(2)}`
}

// --- Start --------------------------------------------------------------------

store.subscribe(render)
render()
store.requestPersistent()

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => {
      // Registration fails on an insecure origin. The app still runs; it just is not
      // installable or offline-capable until served over HTTPS.
    })
  })
}
