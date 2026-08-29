// Bootstraps the app: builds the store, renders the active screen, and routes every tap.
// All interaction handling lives here so the screen modules stay render-only.
import { createStore } from '../state/store.js'
import { createLocalStoragePersistence } from '../state/persistence.js'
import { buildExport, exportFilename, parseImport } from '../state/backup.js'
import * as E from '../domain/events.js'
import { currentGame, currentMatch, currentLineup, lineupPositionOf } from '../domain/reducer.js'
import { activeServerId } from '../domain/stats.js'
import * as track from './screens/track.js'
import * as stats from './screens/stats.js'
import * as roster from './screens/roster.js'

const SCREENS = { track, stats, roster }

// Two serves cannot physically occur this close together, so a tap inside this window is
// a stray repeat -- a double-tap on the same control -- and is ignored (FR-023 of v1).
const REPEAT_TAP_GUARD_MS = 300

// Two taps on the same player chip inside this window are a substitution gesture rather
// than two separate selections. `dblclick` is unreliable on touch and fights the
// double-tap-zoom suppression, so taps are counted here instead.
const DOUBLE_TAP_MS = 400

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
  showLineup: false,
  lineupDraft: null,
  lineupDismissedFor: null,
  confirmingRemoveId: null,
  confirmingEndMatch: false,
  confirmingDiscardGame: false,
  confirmingImport: false,
  message: null,
}

// Destructive or replacing actions arm on the first tap and commit on the second. A tap on
// anything else disarms them, so a confirmation is never left hanging.
const CONFIRMATIONS = {
  'remove-player': 'confirmingRemoveId',
  'end-match': 'confirmingEndMatch',
  'discard-game': 'confirmingDiscardGame',
  'import-data': 'confirmingImport',
}

const screenElement = document.getElementById('screen')
const dockElement = document.getElementById('dock')
const bannerElement = document.getElementById('banner')

let lastServeAt = 0
let pendingSelect = null

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
  tab: (element) => { ui.tab = element.dataset.tab; ui.pickerOpen = false; ui.showLineup = false },
  scope: (element) => { ui.scope = element.dataset.scope },
  'toggle-picker': () => { ui.pickerOpen = !ui.pickerOpen; store.clearSubstitution() },
  'start-game': () => dispatch(E.startGame(newId())),
  'select-server': (element) => selectOrSubstitute(element.dataset.id),
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

  'choose-lineup': (element) => { ui.lineupDraft = [...draft(), element.dataset.id] },
  'unchoose-lineup': (element) => { ui.lineupDraft = draft().filter((id) => id !== element.dataset.id) },
  'confirm-lineup': () => {
    const result = store.dispatch(E.setLineup(draft()))
    ui.message = result.accepted ? null : result.reason
    if (result.accepted) { ui.lineupDraft = null; ui.pickerOpen = false }
  },
  'skip-lineup': () => {
    const state = store.getState()
    const match = currentMatch(state)
    if (match?.lineup) dispatch(E.clearLineup())
    ui.lineupDraft = null
    ui.showLineup = false
    ui.lineupDismissedFor = match ? track.matchKey(state, match) : null
  },
  'show-lineup': () => { ui.showLineup = true; ui.pickerOpen = false },
  'close-lineup': () => { ui.showLineup = false },

  'export-data': () => { void exportData() },
  'import-data': () => confirmThen('confirmingImport', true, () => chooseImportFile()),
}

function draft() {
  return ui.lineupDraft ?? currentLineup(store.getState()) ?? []
}

function recordServe(outcome) {
  const now = Date.now()
  if (now - lastServeAt < REPEAT_TAP_GUARD_MS) return
  lastServeAt = now
  dispatch(E.recordServe(outcome))
}

/**
 * A tap on a player chip is either "this player serves now" or the first half of a
 * substitution, and the app cannot know which until it sees whether a second tap follows.
 *
 * Committing the first tap immediately and undoing it on the second would leave a stray
 * selection in the log and close the picker before the second tap could land. So when a
 * substitution is possible, the selection waits out the double-tap window instead. That
 * delay costs nothing on the path that matters: with a lineup set the rotation chooses the
 * server, so tapping a chip is a deliberate override or a substitution, never the
 * one-tap side-out. Without a lineup there is nothing to disambiguate and a tap acts at once.
 */
function selectOrSubstitute(playerId) {
  const armed = store.pendingSubstitution()
  if (armed) {
    completeSubstitution(armed, playerId)
    return
  }

  const match = currentMatch(store.getState())
  const canSubstitute = Boolean(match?.lineup) && lineupPositionOf(match, playerId) !== null
  if (!canSubstitute) {
    commitSelect(playerId)
    return
  }

  if (pendingSelect?.playerId === playerId) {
    cancelPendingSelect()
    store.armSubstitution(playerId)
    return
  }

  cancelPendingSelect()
  pendingSelect = {
    playerId,
    timer: setTimeout(() => {
      pendingSelect = null
      commitSelect(playerId)
      render()
    }, DOUBLE_TAP_MS),
  }
}

function completeSubstitution(outPlayerId, inPlayerId) {
  if (outPlayerId === inPlayerId) {
    store.clearSubstitution()
    return
  }
  const result = store.dispatch(E.substitute(outPlayerId, inPlayerId))
  ui.message = result.accepted ? null : result.reason
  if (result.accepted) ui.pickerOpen = false
}

function commitSelect(playerId) {
  ui.pickerOpen = false
  if (playerId === activeServerId(store.getState())) return
  dispatch(E.selectServer(playerId))
}

function cancelPendingSelect() {
  if (!pendingSelect) return
  clearTimeout(pendingSelect.timer)
  pendingSelect = null
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

// --- Backup -------------------------------------------------------------------

/**
 * Offers the backup through the native share sheet when the device can share files --
 * on an installed iOS app that is the path to "Save to Files", and a plain download link
 * is unreliable there. Falls back to a download everywhere else.
 */
async function exportData() {
  const now = new Date()
  const text = buildExport(store.getEvents(), now)
  const filename = exportFilename(now)
  const file = new File([text], filename, { type: 'application/json' })

  if (navigator.canShare?.({ files: [file] })) {
    try {
      await navigator.share({ files: [file], title: 'Serve Tracker backup' })
      return
    } catch (error) {
      if (error?.name === 'AbortError') return // the operator closed the sheet
    }
  }

  downloadFallback(text, filename)
}

function downloadFallback(text, filename) {
  const url = URL.createObjectURL(new Blob([text], { type: 'application/json' }))
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  document.body.appendChild(link)
  link.click()
  link.remove()
  URL.revokeObjectURL(url)
}

function chooseImportFile() {
  const input = document.createElement('input')
  input.type = 'file'
  input.accept = 'application/json,.json'
  input.addEventListener('change', () => {
    const file = input.files?.[0]
    if (file) void readImport(file)
  })
  input.click()
}

async function readImport(file) {
  let text
  try {
    text = await file.text()
  } catch {
    ui.message = 'That file could not be read.'
    render()
    return
  }

  const parsed = parseImport(text)
  if (!parsed.ok) {
    // Nothing has been written at this point, so existing data is untouched by definition.
    ui.message = parsed.reason
    render()
    return
  }

  store.replaceAll(parsed.events)
  ui.message = null
  ui.tab = 'track'
  render()
}

// --- Wiring -------------------------------------------------------------------

document.addEventListener('click', (event) => {
  const target = event.target.closest('[data-action]')

  // A tap on anything that is not a player abandons a half-made substitution.
  if (!target || target.dataset.action !== 'select-server') {
    store.clearSubstitution()
    cancelPendingSelect()
  }

  if (!target || target.disabled) { render(); return }

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
