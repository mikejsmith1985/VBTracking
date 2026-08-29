// Renders a per-player statistics table. Used at game, match, season and career scope,
// because they all produce the same shape.
//
// The rule this component exists to enforce: a figure that was never recorded shows as a
// dash, never as a zero. A season mixing tracked games with games copied from paper would
// otherwise report worse figures than the players earned.
import { playerLabel, playerById, percent } from '../html.js'
import { turnsOnCourt } from '../../domain/stats.js'

/**
 * A table of per-player statistics, ordered by points then serves.
 *
 * `turns` enables the on-court column for a single match or game. `options.coverage`
 * enables the tracked-only labelling for a season or career.
 */
export function statsTable(statsByPlayer, roster, turns = null, options = {}) {
  if (!statsByPlayer || statsByPlayer.size === 0) {
    return '<div class="empty">No serves recorded yet.</div>'
  }

  // "On court" is only meaningful where a lineup was used; without one it would be a
  // column of zeroes pretending to mean something.
  const showsOnCourt = Boolean(turns?.some((turn) => turn.lineupSnapshot))
  const action = options.action ?? null

  const rows = [...statsByPlayer.entries()]
    .sort(([, left], [, right]) => rank(right) - rank(left) || right.serves - left.serves)
    .map(([playerId, stats]) => row(
      playerById(roster, playerId),
      playerId,
      stats,
      showsOnCourt ? turnsOnCourt(turns, playerId) : undefined,
      action,
    ))
    .join('')

  return `
    <table class="stats-table">
      <thead>
        <tr><th>Player</th><th>Srv</th><th>In</th><th>In %</th><th>Pts</th><th>Turns</th>
        ${showsOnCourt ? '<th>Court</th>' : ''}</tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>
    ${coverageNote(options.coverage)}`
}

function row(player, playerId, stats, onCourt, action) {
  const cells = [
    cell(stats.serves),
    cell(stats.servesIn),
    cell(stats.inPercentage === null ? null : percent(stats.inPercentage)),
    cell(stats.points),
    cell(stats.turnsTaken),
    onCourt === undefined ? '' : cell(onCourt ?? stats.turnsOnCourt),
  ].join('')

  const name = action
    ? `<button class="linked-player" data-action="${action}" data-id="${playerId}" type="button">${playerLabel(player)}</button>`
    : playerLabel(player)

  return `<tr><td>${name}</td>${cells}</tr>`
}

/** Null means the figure was never recorded. It is a dash, never a zero. */
function cell(value) {
  if (value === null || value === undefined) {
    return '<td class="none" title="Not recorded">—</td>'
  }
  return `<td>${value}</td>`
}

/** Ranks by points where they exist, and by serves in where they do not. */
function rank(stats) {
  return stats.points ?? stats.servesIn
}

/**
 * Says plainly which columns cover which games, rather than letting a reader assume a
 * season's points column spans games that never recorded points.
 */
function coverageNote(coverage) {
  if (!coverage || coverage.totalGames === 0) return ''
  if (coverage.trackedGames === coverage.totalGames) return ''

  const paper = coverage.totalGames - coverage.trackedGames
  const tracked = coverage.trackedGames
  return `
    <div class="roster-count">
      Serves and In cover all ${coverage.totalGames} games. Points and Turns cover the
      ${tracked} tracked serve by serve — the other ${paper} came from paper, which recorded
      serves only. A dash means the game never recorded that figure.
    </div>`
}
