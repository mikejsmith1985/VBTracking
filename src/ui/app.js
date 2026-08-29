// Bootstraps the app: builds the store, renders the active screen, and routes every tap.
// All interaction handling lives here so the screen modules stay render-only.
import { createStore } from '../state/store.js'
import { createLocalStoragePersistence } from '../state/persistence.js'
import { buildExport, exportFilename, parseImport } from '../state/backup.js'
import { parseHistoricalGames } from '../state/historical-import.js'
import * as E from '../domain/events.js'
import {
  currentGame, currentMatch, currentLineup, lineupPositionOf,
  activeSeason, seasonMembers, gameById,
} from '../domain/reducer.js'
import { activeServerId } from '../domain/stats.js'
import * as track from './screens/track.js'
import * as stats from './screens/stats.js'
import * as roster from './screens/roster.js'
import * as season from './screens/season.js'
import { gameFormView, readGameForm } from './screens/gameform.js'

const SCREENS = { track, stats, roster, season }

// Two serves cannot physically occur this close together, so a tap inside this window is
// a stray repeat -- a double-tap on the same control -- and is ignored.
const REPEAT_TAP_GUARD_MS = 300

// Two taps on the same player chip inside this window are a substitution gesture rather
// than two separate selections.
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
  careerPlayerId: null,
  editingGameId: null,
  confirmingRemoveId: null,
  confirmingEndMatch: false,
  confirmingDiscardGame: null,
  confirmingImport: false,
  confirmingHistoricalImport: false,
  message: null,
}

// Destructive or replacing actions arm on the first tap and commit on the second. A tap on
// anything else disarms them, so a confirmation is never left hanging.
const CONFIRMATIONS = {
  'remove-player': 'confirmingRemoveId',
  'discard-game': 'confirmingDiscardGame',
  'import-data': 'confirmingImport',
  'import-historical': 'confirmingHistoricalImport',
}

const screenElement = document.getElementById('screen')
const dockElement = document.getElementById('dock')
const bannerElement = document.getElementById('banner')

let lastServeAt = 0
let pendingSelect = null

// --- Rendering ----------------------------------------------------------------

function render() {
  const focus = captureFocus()
  const state = store.getState()

  // Editing a game's record takes over the screen. It is done between matches, with care,
  // and none of it belongs beside the controls tapped during a rally.
  const view = ui.editingGameId
    ? { screen: gameFormView(state, ui), dock: '' }
    : SCREENS[ui.tab].view({ state, store, ui })

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
  const storageProblem = STORAGE_PROBLEMS[store.storageStatus()]
  const notice = ui.notice ?? (storageProblem ? { text: storageProblem, tone: 'error' } : null)

  bannerElement.textContent = notice?.text ?? ''
  bannerElement.className = notice ? `banner banner-${notice.tone}` : 'banner'
  bannerElement.hidden = !notice
}

/** Reports something that worked. */
function succeed(text) {
  ui.notice = { text, tone: 'success' }
}

/** Reports something that did not. */
function fail(text) {
  ui.notice = { text, tone: 'error' }
}

function clearNotice() {
  ui.notice = null
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
  tab: (element) => {
    ui.tab = element.dataset.tab
    ui.pickerOpen = false
    ui.showLineup = false
    ui.careerPlayerId = null
    ui.editingGameId = null
  },
  scope: (element) => { ui.scope = element.dataset.scope },
  'toggle-picker': () => { ui.pickerOpen = !ui.pickerOpen; store.clearSubstitution() },
  'start-game': () => dispatch(E.startGame(newId(), store.getState().activeSeasonId)),
  'select-server': (element) => selectOrSubstitute(element.dataset.id),
  serve: (element) => recordServe(element.dataset.outcome),
  undo: () => { store.undo() },

  'end-match': (element) => {
    const result = element.dataset.result
    if (!result) { ui.confirmingEndMatch = true; return }
    ui.confirmingEndMatch = false
    dispatch(E.endMatch(result))
  },
  'cancel-end-match': () => { ui.confirmingEndMatch = false },
  'end-game': () => {
    ui.confirmingEndMatch = false
    dispatch(E.endGame())
  },

  'remove-player': (element) => {
    const playerId = element.dataset.id
    // Non-destructive since release 003: they leave this season's roster, and every serve
    // they recorded stays theirs.
    confirmThen('confirmingRemoveId', playerId, () =>
      dispatch(E.removeFromSeason(playerId, store.getState().activeSeasonId)))
  },
  'discard-game': (element) => {
    const gameId = element.dataset.id ?? currentGame(store.getState())?.id
    if (!gameId) return
    confirmThen('confirmingDiscardGame', gameId, () => {
      if (dispatch(E.discardGame(gameId))) ui.editingGameId = null
    })
  },

  'choose-lineup': (element) => { ui.lineupDraft = [...draft(), element.dataset.id] },
  'unchoose-lineup': (element) => { ui.lineupDraft = draft().filter((id) => id !== element.dataset.id) },
  'confirm-lineup': () => {
    if (dispatch(E.setLineup(draft()))) { ui.lineupDraft = null; ui.pickerOpen = false }
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
  'import-data': () => confirmThen('confirmingImport', true, () => chooseFile(readBackup)),
  'import-historical': () => confirmThen('confirmingHistoricalImport', true, () => chooseFile(readHistorical)),

  'open-career': (element) => { ui.careerPlayerId = element.dataset.id },
  'close-career': () => { ui.careerPlayerId = null },
  'open-game': (element) => { ui.editingGameId = element.dataset.id },
  'close-game': () => { ui.editingGameId = null },
  'add-historical': () => { ui.editingGameId = 'new-historical' },
  'paste-games': () => { ui.pastingGames = true },
  'cancel-paste': () => { ui.pastingGames = false },
  'activate-season': (element) => dispatch(E.activateSeason(element.dataset.id)),
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
 * When a substitution is possible the selection waits out the double-tap window. That delay
 * costs nothing on the path that matters: with a lineup set the rotation chooses the server,
 * so tapping a chip is a deliberate override or a substitution, never the one-tap side-out.
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
  if (dispatch(E.substitute(outPlayerId, inPlayerId))) ui.pickerOpen = false
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

/** Dispatches and surfaces any refusal. Returns whether it was accepted. */
function dispatch(event) {
  const result = store.dispatch(event)
  if (result.accepted) clearNotice()
  else fail(result.reason)
  return result.accepted
}

// --- Files --------------------------------------------------------------------

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

function chooseFile(handler) {
  const input = document.createElement('input')
  input.type = 'file'
  // No accept filter at all -- not even an empty one. iOS saves a JSON file from Safari as
  // ".json.txt", and any filter greys it out so the file the phone just wrote cannot be
  // chosen. The parser reads the contents and refuses anything that is not ours with a
  // plain reason, so a guess at an extension must never stand between the operator and
  // their own data.
  input.removeAttribute('accept')
  input.addEventListener('change', () => {
    const file = input.files?.[0]
    if (file) void withFileText(file, handler)
  })
  input.click()
}

async function withFileText(file, handler) {
  let text
  try {
    text = await file.text()
  } catch {
    fail('That file could not be read.')
    render()
    return
  }
  handler(text)
  render()
}

/** A backup REPLACES everything. Confirmed before the picker ever opened. */
function readBackup(text) {
  const parsed = parseImport(text)
  if (!parsed.ok) {
    // Nothing has been written at this point, so existing data is untouched by definition.
    fail(parsed.reason)
    return
  }
  store.replaceAll(parsed.events)
  succeed('Backup restored.')
  ui.tab = 'track'
}

/**
 * A batch of games from paper ADDS to the season. All or nothing: a partial import would
 * leave the operator unable to tell what landed.
 */
function readHistorical(text) {
  const state = store.getState()
  const current = activeSeason(state)
  const withMembers = current && { ...current, members: seasonMembers(state, current.id) }

  const parsed = parseHistoricalGames(text, withMembers, newId)
  if (!parsed.ok) {
    fail(parsed.reason)
    return false
  }

  for (const event of parsed.events) dispatch(event)
  succeed(`Added ${parsed.events.length} game${parsed.events.length === 1 ? '' : 's'}.`)
  ui.tab = 'season'
  return true
}

// --- Forms --------------------------------------------------------------------

const FORMS = {
  'add-player-form': submitAddPlayer,
  'paste-games-form': submitPastedGames,
  'create-season-form': submitCreateSeason,
  'rename-season-form': submitRenameSeason,
  'game-form': submitGameForm,
}

function submitAddPlayer(form) {
  const name = form.querySelector('[name="name"]').value
  const number = form.querySelector('[name="number"]').value

  if (dispatch(E.addPlayer(newId(), name, number, store.getState().activeSeasonId))) form.reset()

  render()
  document.querySelector('[data-focus="add-number"]')?.focus()
}

/** The same path as a file import, with the text arriving from the clipboard instead. */
function submitPastedGames(form) {
  const text = form.querySelector('[name="games"]').value.trim()
  if (!text) {
    fail('Paste the contents of the games file first.')
    return
  }
  // The box stays open on failure so the paste can be corrected rather than redone.
  if (readHistorical(text)) ui.pastingGames = false
}

function submitCreateSeason(form) {
  const id = newId()
  const name = form.querySelector('[name="name"]').value
  const team = form.querySelector('[name="team"]').value

  if (!dispatch(E.createSeason(id, name, team))) return
  dispatch(E.activateSeason(id))
  form.reset()
}

function submitRenameSeason(form) {
  dispatch(E.renameSeason(
    store.getState().activeSeasonId,
    form.querySelector('[name="name"]').value,
    form.querySelector('[name="team"]').value,
  ))
}

/** Saves a game's context, notes, and -- for a game from paper -- its serve figures. */
function submitGameForm(form) {
  const state = store.getState()
  const current = activeSeason(state)
  const read = readGameForm(form, seasonMembers(state, current?.id))

  if (ui.editingGameId === 'new-historical') {
    if (!dispatch(historicalEvent(E.addHistoricalGame(newId(), current.id, read.context, read.entries, read.notes), read))) return
    ui.editingGameId = null
    ui.tab = 'season'
    return
  }

  const game = gameById(state, ui.editingGameId)
  if (!game) { ui.editingGameId = null; return }

  if (game.kind === E.GAME_KIND.HISTORICAL) {
    if (!dispatch(historicalEvent(E.editHistoricalGame(game.id, read.context, read.entries, read.notes), read))) return
  } else {
    if (!dispatch(E.setGameContext(game.id, read.context))) return
    if (!dispatch(E.setGameNotes(game.id, read.notes))) return
    for (const { index, result } of read.matchResults) {
      const match = game.matches.find((each) => each.index === index)
      if (match && match.result !== result) {
        if (!dispatch(E.setMatchResult(game.id, index, result))) return
      }
    }
  }
  ui.editingGameId = null
}

function historicalEvent(event, read) {
  return { ...event, result: read.result }
}

// --- Wiring -------------------------------------------------------------------

document.addEventListener('click', (event) => {
  const target = event.target.closest('[data-action]')

  // A tap on anything that is not a player abandons a half-made substitution.
  if (target?.dataset.action !== 'select-server') abandonPendingSubstitution(event)

  if (!target || target.disabled) return

  const handler = ACTIONS[target.dataset.action]
  if (!handler) return

  clearPendingConfirmations(target.dataset.action)
  handler(target)
  render()
})

document.addEventListener('submit', (event) => {
  const handler = FORMS[event.target.id]
  if (!handler) return
  event.preventDefault()
  handler(event.target)
  render()
})

document.addEventListener('change', (event) => {
  const field = event.target.closest('[data-edit]')
  if (!field) return

  const player = store.getState().roster.find((each) => each.id === field.dataset.edit)
  if (!player) return

  const edited = { ...player, [field.dataset.field]: field.value }
  dispatch(E.editPlayer(player.id, edited.name, edited.number, store.getState().activeSeasonId))
  render()
})

/**
 * Clears a half-made substitution, and redraws only if that actually changed something.
 *
 * Redrawing on every stray click is what broke every submit button in the app: the click
 * on Save destroyed and rebuilt the form before the browser's own submit event could fire,
 * so the form never submitted. A click inside a form therefore never redraws -- the
 * submit handler that follows will.
 */
function abandonPendingSubstitution(event) {
  const wasArmed = store.pendingSubstitution() !== null || pendingSelect !== null
  store.clearSubstitution()
  cancelPendingSelect()
  if (wasArmed && !event.target.closest('form')) render()
}

/**
 * Brings the focused field clear of the on-screen keyboard.
 *
 * iOS does not shrink the viewport for the keyboard in a standalone app, so a field low on
 * a form -- the notes box, most of all -- ends up behind it with the operator typing blind.
 * The delay lets the keyboard finish animating before the page decides where to scroll.
 */
document.addEventListener('focusin', (event) => {
  const field = event.target.closest('input, textarea')
  if (!field) return
  setTimeout(() => {
    if (document.activeElement === field) field.scrollIntoView({ block: 'center', behavior: 'smooth' })
  }, 300)
})

/** A tap on anything else cancels a confirmation the operator did not follow through on. */
function clearPendingConfirmations(action) {
  for (const [owner, flag] of Object.entries(CONFIRMATIONS)) {
    if (owner !== action) ui[flag] = disarmed(ui[flag])
  }
  if (action !== 'end-match') ui.confirmingEndMatch = false
  clearNotice()
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
  // A new version otherwise needs two launches to appear: one for the worker to install,
  // another for the page to pick it up. That is a trap -- it looks exactly like a fix that
  // did not work, and it costs a round of "it is still broken" every release.
  let reloading = false
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (reloading) return
    reloading = true
    window.location.reload()
  })

  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => {
      // Registration fails on an insecure origin. The app still runs; it just is not
      // installable or offline-capable until served over HTTPS.
    })
  })
}
