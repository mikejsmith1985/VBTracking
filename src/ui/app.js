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
import { activeServerId, SERVE_LIMIT } from '../domain/stats.js'
import { rotateOverlay } from './components/rotate.js'
import * as track from './screens/track.js'
import * as stats from './screens/stats.js'
import * as roster from './screens/roster.js'
import * as season from './screens/season.js'
import { gameFormView, readGameForm } from './screens/gameform.js'
import { gameRecordView, nextOutcome, turnKey } from './screens/gamerecord.js'

const SCREENS = { track, stats, roster, season }

// Two serves cannot physically occur this close together, so a tap inside this window is
// a stray repeat -- a double-tap on the same control -- and is ignored.
const REPEAT_TAP_GUARD_MS = 300

// The end-match panel's own controls, which must not close it. Arming the discard
// confirmation from inside the panel used to close the panel and take the button with it,
// so the second tap that would have committed it had nowhere to land.
const END_MATCH_PANEL_ACTIONS = new Set(['end-match', 'discard-game'])

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
  rotateNotice: null,
  recordGameId: null,
  openTurn: null,
  confirmingDeleteTurn: null,
  reassigningTurn: null,
  message: null,
}

// Destructive or replacing actions arm on the first tap and commit on the second. A tap on
// anything else disarms them, so a confirmation is never left hanging.
const CONFIRMATIONS = {
  'remove-player': 'confirmingRemoveId',
  'discard-game': 'confirmingDiscardGame',
  'delete-turn': 'confirmingDeleteTurn',
  'import-data': 'confirmingImport',
  'import-historical': 'confirmingHistoricalImport',
}

const screenElement = document.getElementById('screen')
const dockElement = document.getElementById('dock')
const overlayElement = document.getElementById('overlay')
const bannerElement = document.getElementById('banner')

let lastServeAt = 0

// --- Rendering ----------------------------------------------------------------

function render() {
  const focus = captureFocus()
  const state = store.getState()

  // Editing a game's record takes over the screen. It is done between matches, with care,
  // and none of it belongs beside the controls tapped during a rally.
  const view = ui.recordGameId
    ? { screen: gameRecordView(state, ui), dock: '' }
    : ui.editingGameId
      ? { screen: gameFormView(state, ui), dock: '' }
      : SCREENS[ui.tab].view({ state, store, ui })

  screenElement.innerHTML = view.screen
  dockElement.innerHTML = view.dock ?? ''
  overlayElement.innerHTML = ui.rotateNotice ? rotateOverlay(ui.rotateNotice, state.roster) : ''

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
    closeRecord()
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
  'dismiss-rotate': () => { ui.rotateNotice = null },

  'open-record': (element) => { ui.recordGameId = element.dataset.id; ui.openTurn = null },
  'close-record': () => closeRecord(),
  'open-turn': (element) => { ui.openTurn = turnAt(element); ui.reassigningTurn = null },
  'close-turn': () => { ui.openTurn = null; ui.reassigningTurn = null },
  'cycle-serve': (element) => correctServes(element, (outcomes) => {
    const index = Number.parseInt(element.dataset.index, 10)
    return outcomes.map((outcome, at) => (at === index ? nextOutcome(outcome) : outcome))
  }),
  'add-serve': (element) => correctServes(element, (outcomes) => [...outcomes, E.OUTCOME.OUT]),
  // Never to nothing: a turn with no serves is a turn that did not happen, and deleting it
  // is a different decision with its own confirmation.
  'drop-serve': (element) => correctServes(element, (outcomes) =>
    (outcomes.length > 1 ? outcomes.slice(0, -1) : outcomes)),
  'reassign-turn': (element) => {
    const key = keyOf(element)
    ui.reassigningTurn = ui.reassigningTurn === key ? null : key
  },
  'reassign-to': (element) => {
    const { matchIndex, ordinal } = turnAt(element)
    if (dispatch(E.reassignTurn(ui.recordGameId, matchIndex, ordinal, element.dataset.id))) {
      ui.reassigningTurn = null
    }
  },
  'delete-turn': (element) => {
    const { matchIndex, ordinal } = turnAt(element)
    confirmThen('confirmingDeleteTurn', keyOf(element), () => {
      if (dispatch(E.deleteTurn(ui.recordGameId, matchIndex, ordinal))) ui.openTurn = null
    })
  },
}

function closeRecord() {
  ui.recordGameId = null
  ui.openTurn = null
  ui.reassigningTurn = null
  ui.confirmingDeleteTurn = null
}

function turnAt(element) {
  return {
    matchIndex: Number.parseInt(element.dataset.match, 10),
    ordinal: Number.parseInt(element.dataset.ordinal, 10),
  }
}

function keyOf(element) {
  const { matchIndex, ordinal } = turnAt(element)
  return turnKey(matchIndex, ordinal)
}

/**
 * Rewrites one turn's serves through the given change.
 *
 * The whole list is sent rather than the single serve that moved, because the correction
 * event says what the turn holds now -- replaying it can never depend on what it held when
 * the button was tapped.
 */
function correctServes(element, change) {
  const { matchIndex, ordinal } = turnAt(element)
  const state = store.getState()
  const turn = gameById(state, ui.recordGameId)
    ?.matches.find((match) => match.index === matchIndex)
    ?.turns.find((each) => each.ordinal === ordinal)
  if (!turn) return

  const outcomes = change(turn.serves.map((serve) => serve.outcome))
  dispatch(E.setTurnServes(ui.recordGameId, matchIndex, ordinal, outcomes))
}

function draft() {
  return ui.lineupDraft ?? currentLineup(store.getState()) ?? []
}

function recordServe(outcome) {
  const now = Date.now()
  if (now - lastServeAt < REPEAT_TAP_GUARD_MS) return
  lastServeAt = now

  const servingId = activeServerId(store.getState())
  if (dispatch(E.recordServe(outcome))) noticeServeLimit(servingId)
}

/**
 * Says so, loudly, the moment a server has taken their five.
 *
 * The rule is the referee's to enforce and easy to lose count of in a rally, so this is
 * deliberately the one thing in the app that interrupts: it covers the screen, and any tap
 * clears it. Raised once, on the fifth serve exactly -- a sixth is a miscount the app still
 * records without nagging about it a second time.
 */
function noticeServeLimit(servingId) {
  const state = store.getState()
  const match = currentMatch(state)
  const served = [...(match?.turns ?? [])].reverse().find((turn) => turn.playerId === servingId)

  if (served?.serves.length !== SERVE_LIMIT) return

  // Only the order can name who is next. Without one the same player is still holding the
  // ball, and naming them as "next up" would read as permission to serve a sixth.
  const nextId = activeServerId(state)
  ui.rotateNotice = { fromId: servingId, toId: nextId === servingId ? null : nextId }
}

/**
 * A tap on a player chip means one of two things, and which one is decided by where the
 * player is standing rather than by how fast the operator taps.
 *
 * Someone already in the order is simply the next server. Someone on the bench is the
 * player coming ON: the next tap names who they replace, and they take that exact slot.
 * Bench first, then the player leaving -- the same order the swap happens on the court.
 * The old gesture asked for a double-tap, which is a thing to remember rather than a thing
 * to do, and it cost a tap on the path that runs every side-out.
 */
function selectOrSubstitute(playerId) {
  const state = store.getState()
  const match = currentMatch(state)
  const isOnCourt = Boolean(match?.lineup) && lineupPositionOf(match, playerId) !== null
  const incomingId = store.pendingSubstitution()

  if (incomingId) {
    // Tapping the armed player again means "they serve now", not a substitution -- the
    // recorded case where the referee lets someone out of the order take the ball.
    if (incomingId === playerId) { store.clearSubstitution(); commitSelect(playerId); return }
    if (isOnCourt) { completeSubstitution(playerId, incomingId); return }
    store.armSubstitution(playerId) // a different bench player: re-aim rather than refuse
    return
  }

  if (!match?.lineup || isOnCourt) { commitSelect(playerId); return }
  store.armSubstitution(playerId)
}

/** Swaps the incoming player in at the outgoing player's exact position in the order. */
function completeSubstitution(outPlayerId, inPlayerId) {
  if (outPlayerId === inPlayerId) {
    store.clearSubstitution()
    return
  }
  if (dispatch(E.substitute(outPlayerId, inPlayerId))) ui.pickerOpen = false
}

/** Hands the serve to a player. Re-selecting whoever is already serving does nothing. */
function commitSelect(playerId) {
  ui.pickerOpen = false
  if (playerId === activeServerId(store.getState())) return
  dispatch(E.selectServer(playerId))
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
  const wasArmed = store.pendingSubstitution() !== null
  store.clearSubstitution()
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
  if (!END_MATCH_PANEL_ACTIONS.has(action)) ui.confirmingEndMatch = false
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
