// Renders a per-player statistics table. Used at both match and game scope, because the
// two produce the same shape.
import { playerLabel, playerById, percent } from '../html.js'
import { turnsOnCourt } from '../../domain/stats.js'

/** A table of per-player statistics, ordered by points then serves. */
export function statsTable(statsByPlayer, roster, turns = null) {
  if (!statsByPlayer || statsByPlayer.size === 0) {
    return '<div class="empty">No serves recorded yet.</div>'
  }

  // "On court" is only meaningful where a lineup was used; without one it would be a
  // column of zeroes pretending to mean something.
  const showsOnCourt = Boolean(turns?.some((turn) => turn.lineupSnapshot))

  const rows = [...statsByPlayer.entries()]
    .sort(([, left], [, right]) => right.points - left.points || right.serves - left.serves)
    .map(([playerId, stats]) => row(
      playerById(roster, playerId),
      stats,
      showsOnCourt ? turnsOnCourt(turns, playerId) : null,
    ))
    .join('')

  return `
    <table class="stats-table">
      <thead>
        <tr><th>Player</th><th>Srv</th><th>In</th><th>In %</th><th>Pts</th><th>Turns</th>
        ${showsOnCourt ? '<th>Court</th>' : ''}</tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>`
}

function row(player, stats, onCourt) {
  const percentCell = stats.inPercentage === null ? '<td class="none">—</td>' : `<td>${percent(stats.inPercentage)}</td>`
  return `
    <tr>
      <td>${playerLabel(player)}</td>
      <td>${stats.serves}</td>
      <td>${stats.servesIn}</td>
      ${percentCell}
      <td>${stats.points}</td>
      <td>${stats.turnsTaken}</td>
      ${onCourt === null ? '' : `<td>${onCourt}</td>`}
    </tr>`
}
