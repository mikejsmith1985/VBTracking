// One player, every season they have played. This is what career identity is for: the
// same child, a different team, a different number, and figures that still compare.
import { playerById } from '../../domain/reducer.js'
import { careerStats } from '../../domain/aggregate.js'
import { esc, percent } from '../html.js'

/** A player's whole record, season by season and combined. */
export function careerView(state, playerId) {
  const player = playerById(state, playerId)
  if (!player) return '<div class="empty">That player no longer exists.</div>'

  const { seasons, total, coverage } = careerStats(state, playerId)

  return `
    <button class="btn" data-action="close-career" type="button">Back to the season</button>
    <div class="season-head">
      <div class="season-name">${esc(player.name)}</div>
      <div class="season-team">${seasons.length} season${seasons.length === 1 ? '' : 's'}</div>
    </div>
    ${seasons.map(seasonBlock).join('')}
    ${totalBlock(total, coverage, seasons.length)}`
}

function seasonBlock(season) {
  const figures = season.figures
  return `
    <div class="match-block">
      <h3>${esc(season.name)} <em>${esc(season.team)} · number ${esc(season.number ?? '—')}</em></h3>
      <div class="record-line">
        <b>${season.record.won}–${season.record.lost}</b>
        <span>${season.games} game${season.games === 1 ? '' : 's'}</span>
      </div>
      ${figures ? figureRows(figures) : '<div class="empty">No games played.</div>'}
    </div>`
}

function totalBlock(total, coverage, seasonCount) {
  if (!total) return ''
  const scope = seasonCount === 1 ? 'One season' : `All ${seasonCount} seasons`
  return `
    <div class="match-block">
      <h3>Career <em>${scope}</em></h3>
      ${figureRows(total)}
      ${coverageNote(coverage)}
    </div>`
}

function figureRows(figures) {
  return `
    <div class="figure-grid">
      ${figure('Serves', figures.serves)}
      ${figure('In', figures.servesIn)}
      ${figure('In %', figures.inPercentage === null ? null : percent(figures.inPercentage))}
      ${figure('Points', figures.points)}
      ${figure('Turns', figures.turnsTaken)}
      ${figure('On court', figures.turnsOnCourt)}
    </div>`
}

/**
 * A figure that was never recorded reads as "not recorded", not as zero. Zero would say
 * the player served and won nothing; the dash says the game never wrote it down.
 */
function figure(label, value) {
  const shown = value === null || value === undefined
    ? '<span class="figure-absent" title="Not recorded">—</span>'
    : esc(String(value))
  return `<div class="figure"><span class="figure-label">${label}</span><span class="figure-value">${shown}</span></div>`
}

function coverageNote(coverage) {
  if (!coverage || coverage.trackedGames === coverage.totalGames) return ''
  const paper = coverage.totalGames - coverage.trackedGames
  return `
    <div class="roster-count">
      Points, turns and time on court cover the ${coverage.trackedGames} game${coverage.trackedGames === 1 ? '' : 's'}
      tracked serve by serve. The other ${paper} came from paper, which recorded serves only.
    </div>`
}
