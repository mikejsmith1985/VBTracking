// Review screen. Three scopes -- individual turns, each match, and the game as a whole --
// all reading from the same derived statistics, so they cannot disagree.
import { MATCHES_PER_GAME } from '../../domain/events.js'
import { currentGame } from '../../domain/reducer.js'
import { matchStats, gameStats, matchScore, turnStats, isOverServeLimit } from '../../domain/stats.js'
import { statsTable } from '../components/statstable.js'
import { turnGroup } from '../components/tally.js'
import { playerLabel, playerById } from '../html.js'

const SCOPES = [
  { key: 'turns', label: 'Turns' },
  { key: 'match', label: 'Match' },
  { key: 'game', label: 'Game' },
]

/** The stats screen. No dock: nothing here is used mid-rally. */
export function view(context) {
  const { state, ui } = context
  const game = currentGame(state)

  if (!game) {
    return {
      screen: '<div class="empty"><strong>Nothing to show yet</strong>Start a game to record serves.</div>',
      dock: '',
    }
  }

  return { screen: scopeSwitch(ui.scope) + bodyFor(ui.scope, game, state.roster) + discardGame(ui), dock: '' }
}

// Discarding lives here rather than on the track screen: it is destructive, and it has no
// business sitting anywhere near the controls tapped during a rally.
function discardGame(ui) {
  const isConfirming = ui.confirmingDiscardGame

  return `
    <div class="danger-zone">
      <button class="btn btn-danger" data-action="discard-game" type="button">
        ${isConfirming ? 'Discard this game?' : 'Discard this game'}
      </button>
      <div class="roster-count">
        ${isConfirming
          ? 'Tap again to discard. Every serve in all three matches is thrown away. The roster is kept.'
          : 'Removes this game and all of its recorded serves. The roster is not affected.'}
      </div>
    </div>`
}

function scopeSwitch(active) {
  const buttons = SCOPES
    .map(({ key, label }) => `
      <button class="scope" data-action="scope" data-scope="${key}" type="button"
              aria-pressed="${key === active}">${label}</button>`)
    .join('')
  return `<div class="scopes">${buttons}</div>`
}

function bodyFor(scope, game, roster) {
  if (scope === 'game') {
    return `<div class="section-title">Game totals — all ${MATCHES_PER_GAME} matches</div>`
      + statsTable(gameStats(game), roster)
  }
  if (scope === 'turns') return game.matches.map((match) => turnsBlock(match, roster)).join('')
  return game.matches.map((match) => matchBlock(match, roster)).join('')
}

function matchBlock(match, roster) {
  return `
    <div class="match-block">
      <h3>Match ${match.index + 1} <em>${matchLabel(match)}</em></h3>
      ${statsTable(matchStats(match), roster)}
    </div>`
}

function turnsBlock(match, roster) {
  const rows = match.turns.length === 0
    ? '<div class="empty">No serves in this match.</div>'
    : match.turns.map((turn) => turnRow(turn, roster)).join('')

  return `
    <div class="match-block">
      <h3>Match ${match.index + 1} <em>${matchLabel(match)}</em></h3>
      ${rows}
    </div>`
}

function turnRow(turn, roster) {
  const stats = turnStats(turn)
  const flag = isOverServeLimit(turn) ? ' <span class="target-badge">over 5</span>' : ''

  return `
    <div class="tally-row">
      <div class="tally-name">
        ${playerLabel(playerById(roster, turn.playerId))}
        <span class="tally-total">turn ${turn.ordinal + 1} · ${stats.points} pts${flag}</span>
      </div>
      <div class="turns">${turnGroup(turn)}</div>
    </div>`
}

function matchLabel(match) {
  const state = match.status === 'ended' ? 'ended' : 'in progress'
  return `${state} · ${matchScore(match)} pts on serve`
}
