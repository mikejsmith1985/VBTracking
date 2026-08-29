// The screen the operator uses for the whole match. Everything here answers one question:
// how few taps, and how little looking away from the court, does one serve cost?
import { OUTCOME, MATCHES_PER_GAME } from '../../domain/events.js'
import { currentGame, currentMatch, isGameComplete } from '../../domain/reducer.js'
import { matchScore, hasReachedTarget, activeServerId, gameStats, TARGET_SCORE } from '../../domain/stats.js'
import { tallyBoard } from '../components/tally.js'
import { statsTable } from '../components/statstable.js'
import { esc, playerLabel, playerById } from '../html.js'

/** Builds the scrolling area and the fixed dock beneath it. */
export function view(context) {
  const { state } = context

  if (state.roster.length === 0) return { screen: needsRoster(), dock: '' }

  const match = currentMatch(state)
  if (!match) return { screen: betweenGames(state), dock: '' }

  return { screen: matchView(context, state, match), dock: dockView(context, state) }
}

function needsRoster() {
  return `
    <div class="empty">
      <strong>No players yet</strong>
      Add your team before the first serve.
    </div>
    <button class="btn btn-primary" data-action="tab" data-tab="roster" type="button">Set up the roster</button>`
}

function betweenGames(state) {
  const game = currentGame(state)
  const complete = isGameComplete(state)

  const summary = complete
    ? `<div class="section-title">Game totals</div>${statsTable(gameStats(game), state.roster)}`
    : ''

  return `
    <div class="empty">
      <strong>${complete ? 'Game complete' : 'Ready to track'}</strong>
      ${complete ? 'All three matches are finished.' : `A game is ${MATCHES_PER_GAME} matches to ${TARGET_SCORE}.`}
    </div>
    <button class="btn btn-primary" data-action="start-game" type="button">
      ${complete ? 'Start a new game' : 'Start game'}
    </button>
    ${summary}`
}

function matchView(context, state, match) {
  const confirming = context.ui.confirmingEndMatch
  const reached = hasReachedTarget(match)

  return `
    <div class="match-head">
      <div class="meta">
        <div class="match-label">Match ${match.index + 1} of ${MATCHES_PER_GAME}</div>
        <div class="match-score"><b>${matchScore(match)}</b><span>points on serve</span></div>
        ${reached ? `<div class="target-badge">${TARGET_SCORE} reached — win by 2</div>` : ''}
      </div>
      <button class="btn-end" data-action="end-match" type="button">
        ${confirming ? 'End match?' : 'End match'}
      </button>
    </div>
    ${tallyBoard(match, state.roster)}`
}

function dockView(context, state) {
  const servingId = activeServerId(state)
  const showPicker = !servingId || context.ui.pickerOpen

  return `
    ${showPicker ? picker(state, servingId) : ''}
    ${serverStrip(context, state, servingId)}
    ${outcomes(Boolean(servingId))}`
}

function picker(state, servingId) {
  const chips = state.roster
    .map((player) => `
      <button class="chip${player.id === servingId ? ' is-serving' : ''}"
              data-action="select-server" data-id="${player.id}" type="button">
        <span class="jersey">${esc(player.number) || '—'}</span><span class="name">${esc(player.name)}</span>
      </button>`)
    .join('')

  return `<div class="picker"><div class="picker-grid">${chips}</div></div>`
}

// The side-out state is the loudest thing on the screen: recording a serve against the
// wrong player is exactly the failure this layout exists to prevent.
function serverStrip(context, state, servingId) {
  const player = playerById(state.roster, servingId)
  const canUndo = context.store.canUndo()

  return `
    <div class="server-strip${servingId ? '' : ' side-out'}">
      <div class="who">
        <div class="server-label">${servingId ? 'Now serving' : 'Side out'}</div>
        <div class="server-name">${servingId ? playerLabel(player) : 'Select the next server'}</div>
      </div>
      ${servingId && !context.ui.pickerOpen
        ? '<button class="btn-undo" data-action="toggle-picker" type="button">Change</button>'
        : ''}
      <button class="btn-undo" data-action="undo" type="button" ${canUndo ? '' : 'disabled'}>Undo</button>
    </div>`
}

function outcomes(isEnabled) {
  return `
    <div class="outcomes" data-enabled="${isEnabled}">
      <button class="outcome outcome-out" data-action="serve" data-outcome="${OUTCOME.OUT}" type="button">
        OUT<small>side out</small>
      </button>
      <button class="outcome outcome-in" data-action="serve" data-outcome="${OUTCOME.IN_NO_POINT}" type="button">
        IN<small>no point — side out</small>
      </button>
      <button class="outcome outcome-point" data-action="serve" data-outcome="${OUTCOME.IN_POINT}" type="button">
        IN — POINT<small>keep serving</small>
      </button>
    </div>`
}
