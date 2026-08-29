// The tally board: one mark per serve, grouped by serve turn, coloured by turn.
// Colour carries the turn; the outcome is carried by the mark's shape, so the board is
// readable without colour vision (FR-034).
import { OUTCOME } from '../../domain/events.js'
import { colorForTurn } from '../../domain/palette.js'
import { turnStats, isOverServeLimit, matchStats } from '../../domain/stats.js'
import { esc, playerLabel, playerById } from '../html.js'

const MARK_CLASS = {
  [OUTCOME.IN_POINT]: 'mark-point',
  [OUTCOME.IN_NO_POINT]: 'mark-in',
  [OUTCOME.OUT]: 'mark-out',
}

const MARK_TITLE = {
  [OUTCOME.IN_POINT]: 'In — point',
  [OUTCOME.IN_NO_POINT]: 'In — no point',
  [OUTCOME.OUT]: 'Out',
}

/** The full board for a match: one row per player who has served, in first-serve order. */
export function tallyBoard(match, roster) {
  const byPlayer = groupTurnsByPlayer(match)
  if (byPlayer.size === 0) {
    return `<div class="empty"><strong>No serves yet</strong>Pick the server below to start recording.</div>`
  }

  const totals = matchStats(match)
  const rows = [...byPlayer.entries()]
    .map(([playerId, turns]) => tallyRow(playerById(roster, playerId), turns, totals.get(playerId)))
    .join('')

  return rows + legend()
}

/** One player's row: their name, their running totals, and each of their turns. */
export function tallyRow(player, turns, totals) {
  return `
    <div class="tally-row">
      <div class="tally-name">
        ${playerLabel(player)}
        <span class="tally-total">${totals.serves} served · ${totals.servesIn} in · ${totals.points} pts</span>
      </div>
      <div class="turns">${turns.map(turnGroup).join('')}</div>
    </div>`
}

/** One serve turn: its marks, its own counts, and an over-limit flag when it ran long. */
export function turnGroup(turn) {
  const stats = turnStats(turn)
  const overLimit = isOverServeLimit(turn)
  const color = colorForTurn(turn.ordinal)

  return `
    <div class="turn${overLimit ? ' over-limit' : ''}" style="--turn-color:${color}">
      <div class="marks">${turn.serves.map(mark).join('')}</div>
      <div class="turn-meta">${overLimit ? '⚠ ' : ''}${stats.serves} · ${stats.servesIn} in</div>
    </div>`
}

function mark(serve) {
  return `<span class="mark ${MARK_CLASS[serve.outcome]}" title="${esc(MARK_TITLE[serve.outcome])}"></span>`
}

function legend() {
  return `
    <div class="legend">
      <span><i class="mark mark-point"></i> point</span>
      <span><i class="mark mark-in"></i> in, no point</span>
      <span><i class="mark mark-out"></i> out</span>
      <span>colour = serve turn</span>
    </div>`
}

/**
 * Turns keyed by player, ordered by when each player first served in the match.
 *
 * A turn that has just opened holds no serves yet. Drawing it would put an empty box and a
 * `0 served` row on the board for someone who has not served, which reads as a mistake --
 * and the status row is already naming them as the current server.
 */
function groupTurnsByPlayer(match) {
  const byPlayer = new Map()
  for (const turn of match?.turns ?? []) {
    if (turn.serves.length === 0) continue
    if (!byPlayer.has(turn.playerId)) byPlayer.set(turn.playerId, [])
    byPlayer.get(turn.playerId).push(turn)
  }
  return byPlayer
}
