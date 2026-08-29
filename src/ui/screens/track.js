// The screen the operator uses for the whole match. Everything here answers one question:
// how few taps, and how little looking away from the court, does one serve cost?
//
// With a lineup set the answer is one: the rotation hands the serve to the next player, so
// the dock stays on the outcome controls through a side-out instead of swapping to the
// picker. The picker returns only when asked for, or when there is no lineup to advance.
import { OUTCOME, MATCHES_PER_GAME } from '../../domain/events.js'
import { currentGame, currentMatch, isGameComplete, openTurn } from '../../domain/reducer.js'
import { matchScore, hasReachedTarget, activeServerId, gameStats, TARGET_SCORE } from '../../domain/stats.js'
import { tallyBoard } from '../components/tally.js'
import { statsTable } from '../components/statstable.js'
import { chipGrid } from '../components/chip.js'
import { needsSetup, setupView, reviewView } from './lineup.js'
import { esc, playerLabel, playerById } from '../html.js'

/** Builds the scrolling area and the fixed dock beneath it. */
export function view(context) {
  const { state, ui } = context

  if (state.roster.length === 0) return { screen: needsRoster(), dock: '' }

  const match = currentMatch(state)
  if (!match) return { screen: betweenGames(state), dock: '' }

  if (ui.showLineup && match.lineup) return { screen: reviewView(context, match), dock: '' }
  if (needsSetup(match, state.roster) && !isSetupDismissed(ui, state, match)) {
    return { screen: setupView(context, match), dock: '' }
  }

  return { screen: matchView(context, state, match), dock: dockView(context, state, match) }
}

/** The setup step is offered once per match; skipping it must not re-prompt every render. */
export function matchKey(state, match) {
  return `${state.currentGameId}:${match.index}`
}

function isSetupDismissed(ui, state, match) {
  return ui.lineupDismissedFor === matchKey(state, match)
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
      ${confirming ? '' : '<button class="btn-end" data-action="end-match" type="button">End match</button>'}
    </div>
    ${confirming ? endMatchChoice(context, state) : ''}
    ${tallyBoard(match, state.roster)}`
}

/**
 * Ending a match asks how it went in the same breath. The opponent's score is still not
 * tracked, so the app cannot know -- and this is the one moment the operator certainly does.
 */
function endMatchChoice(context, state) {
  const game = currentGame(state)
  const confirmingDiscard = context.ui.confirmingDiscardGame === game?.id

  return `
    <div class="end-match-choice">
      <div class="section-title">How did that match go?</div>
      <div class="result-buttons">
        <button class="btn btn-won" data-action="end-match" data-result="won" type="button">Won</button>
        <button class="btn btn-lost" data-action="end-match" data-result="lost" type="button">Lost</button>
      </div>
      <button class="btn" data-action="end-match" data-result="undecided" type="button">End without recording</button>

      <div class="section-title">Or stop here</div>
      <button class="btn" data-action="end-game" type="button">End the game — keep what is recorded</button>
      <button class="btn btn-danger" data-action="discard-game" data-id="${game?.id ?? ''}" type="button">
        ${confirmingDiscard ? 'Throw this game away?' : 'Throw this game away'}
      </button>
      <div class="roster-count">
        ${confirmingDiscard
          ? 'Tap again to discard. Every serve in this game goes with it. The roster and the rest of the season are untouched.'
          : 'Ending keeps every serve and closes the game where it stands, however many matches were played.'}
      </div>

      <button class="btn btn-primary" data-action="cancel-end-match" type="button">Keep playing</button>
    </div>`
}

function dockView(context, state, match) {
  const servingId = activeServerId(state)
  const showPicker = !servingId || context.ui.pickerOpen

  return `
    <div class="dock-panel">${statusRow(context, state, match, servingId, showPicker)}</div>
    ${showPicker ? picker(context, state, servingId) : outcomes()}`
}

function statusRow(context, state, match, servingId, showPicker) {
  const canUndo = context.store.canUndo()
  const player = playerById(state.roster, servingId)
  const isOffLineup = Boolean(openTurn(match)?.isOffLineup)

  return `
    <div class="status-row${servingId ? '' : ' awaiting'}">
      <div class="who">
        ${servingId ? servingPlayer(player, isOffLineup) : '<span class="server-label">Next server</span>'}
      </div>
      ${match.lineup ? '<button class="btn-undo" data-action="show-lineup" type="button">Order</button>' : ''}
      ${servingId ? changeServerButton(showPicker) : ''}
      <button class="btn-undo" data-action="undo" type="button" ${canUndo ? '' : 'disabled'}>Undo</button>
    </div>`
}

// The app chooses the server now, so a wrong one is the app's mistake and the operator has
// to catch it. The number is set at display size for exactly that reason.
function servingPlayer(player, isOffLineup) {
  return `
    <span class="server-label">Now serving</span>
    <span class="serving-number">${esc(player?.number) || '–'}</span>
    <span class="serving-name">${esc(player?.name ?? 'Removed player')}</span>
    ${isOffLineup ? '<span class="off-lineup-badge" title="Not in the lineup">off order</span>' : ''}`
}

function changeServerButton(showPicker) {
  return `<button class="btn-undo" data-action="toggle-picker" type="button">
    ${showPicker ? 'Cancel' : 'Change'}
  </button>`
}

function picker(context, state, servingId) {
  const armed = context.store.pendingSubstitution()
  const lineup = currentMatch(state)?.lineup ?? null

  const grid = chipGrid(state.roster, {
    action: 'select-server',
    stateFor: (player) => {
      if (player.id === armed) return 'is-armed'
      if (player.id === servingId) return 'is-serving'
      return lineup?.includes(player.id) ? 'is-on-court' : ''
    },
    positionFor: (player) => {
      const position = lineup ? lineup.indexOf(player.id) : -1
      return position === -1 ? null : position
    },
  })

  return `
    <div class="picker">
      ${grid}
      <div class="picker-hint">${armed
        ? `Now tap whoever replaces <strong>${esc(playerById(state.roster, armed)?.name ?? '')}</strong>`
        : (lineup ? 'Tap to change server · double-tap to substitute' : 'Tap the next server')}</div>
    </div>`
}

// Rendered only while someone is serving, so these controls are never present-but-dead.
function outcomes() {
  return `
    <div class="outcomes">
      <button class="outcome outcome-out" data-action="serve" data-outcome="${OUTCOME.OUT}" type="button">
        OUT<small>turn ends</small>
      </button>
      <button class="outcome outcome-in" data-action="serve" data-outcome="${OUTCOME.IN_NO_POINT}" type="button">
        IN<small>no point — turn ends</small>
      </button>
      <button class="outcome outcome-point" data-action="serve" data-outcome="${OUTCOME.IN_POINT}" type="button">
        IN — POINT<small>keep serving</small>
      </button>
    </div>`
}
