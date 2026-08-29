// The season: how the team did, how each player served, and the admin for seasons
// themselves. Read between matches rather than during one, so it favours completeness
// over speed.
import { MATCH_RESULT } from '../../domain/events.js'
import { activeSeason, gamesInSeason, seasonMembers } from '../../domain/reducer.js'
import { seasonStats, seasonRecord, recordByOpponent, gameResult, gameSummary } from '../../domain/aggregate.js'
import { statsTable } from '../components/statstable.js'
import { careerView } from './career.js'
import { esc, percent } from '../html.js'
import { APP_VERSION } from '../version.js'

/** The season screen, or a career view when the operator has tapped a player. */
export function view(context) {
  const { state, ui } = context

  if (ui.careerPlayerId) return { screen: careerView(state, ui.careerPlayerId), dock: '' }

  const season = activeSeason(state)
  if (!season) {
    return { screen: '<div class="empty"><strong>No season yet</strong>Add a player to start one.</div>', dock: '' }
  }

  const games = gamesInSeason(state, season.id)
  const { byPlayer, coverage } = seasonStats(state, season.id)

  return {
    screen: header(season, games)
      + record(games)
      + `<div class="section-title">Serving — every game this season</div>`
      + statsTable(byPlayer, seasonMembers(state, season.id), null, { coverage, action: 'open-career' })
      + gameList(state, games)
      + seasonAdmin(state, season, ui),
    dock: '',
  }
}

function header(season, games) {
  return `
    <div class="season-head">
      <div class="season-name">${esc(season.name)}</div>
      <div class="season-team">${esc(season.team)} · ${games.length} game${games.length === 1 ? '' : 's'}</div>
    </div>`
}

function record(games) {
  const overall = seasonRecord(games)
  const byOpponent = [...recordByOpponent(games)]
    .map(([opponent, tally]) => `
      <div class="opponent-row">
        <span class="opponent-name">${esc(opponent)}</span>
        <span class="opponent-record">${tally.won}–${tally.lost}${tally.undecided ? ` · ${tally.undecided} unrecorded` : ''}</span>
      </div>`)
    .join('')

  return `
    <div class="record-line">
      <b>${overall.won}–${overall.lost}</b>
      <span>won–lost${overall.undecided ? ` · ${overall.undecided} not recorded` : ''}</span>
    </div>
    ${byOpponent ? `<div class="section-title">By opponent</div>${byOpponent}` : ''}`
}

function gameList(state, games) {
  if (games.length === 0) {
    return '<div class="empty">No games yet this season.</div>'
  }

  const rows = [...games]
    .sort((left, right) => String(left.date ?? '').localeCompare(String(right.date ?? '')))
    .map((game) => gameRow(state, game))
    .join('')

  return `<div class="section-title">Games</div>${rows}`
}

function gameRow(state, game) {
  const summary = gameSummary(game)
  const result = gameResult(game)
  const top = summary.topScorer
    ? `${esc(nameOf(state, summary.topScorer.playerId))} ${summary.topScorer.servesIn} in`
    : 'no serves'

  return `
    <button class="game-row" data-action="open-game" data-id="${game.id}" type="button">
      <span class="game-when">${esc(game.date ?? 'No date')}</span>
      <span class="game-who">${esc(game.opponent || 'Unnamed opponent')}</span>
      <span class="result-pill result-${result}">${resultLabel(result)}</span>
      <span class="game-figures">${summary.servesIn}/${summary.serves} in · top: ${top}</span>
      ${game.kind === 'historical' ? '<span class="kind-pill">from paper</span>' : ''}
    </button>`
}

function seasonAdmin(state, season, ui) {
  const others = state.seasons.filter((each) => each.id !== season.id)

  const switcher = others.length === 0 ? '' : `
    <div class="section-title">Other seasons</div>
    ${others.map((each) => `
      <button class="btn" data-action="activate-season" data-id="${each.id}" type="button">
        ${esc(each.name)} — ${esc(each.team)}
      </button>`).join('')}`

  return `
    <div class="danger-zone">
      <div class="section-title">This season</div>
      <form class="season-form" id="rename-season-form" autocomplete="off">
        <input name="name" value="${esc(season.name)}" maxlength="40" aria-label="Season name">
        <input name="team" value="${esc(season.team)}" maxlength="40" aria-label="Team name">
        <button type="submit">Save</button>
      </form>
      ${switcher}
      <div class="section-title">Add a season</div>
      <form class="season-form" id="create-season-form" autocomplete="off">
        <input name="name" placeholder="2027" maxlength="40" aria-label="New season name">
        <input name="team" placeholder="Team name" maxlength="40" aria-label="New team name">
        <button type="submit">Create</button>
      </form>
      <div class="roster-count">
        A new season starts with an empty roster. Add players to it from the people you have
        already recorded, so their history follows them.
      </div>

      <div class="app-version">Version ${esc(APP_VERSION)}</div>

      <div class="section-title">Games from paper</div>
      <button class="btn" data-action="add-historical" type="button">Enter a game by hand</button>
      ${ui.pastingGames ? pasteForm() : importControls(ui)}
    </div>`
}

function importControls(ui) {
  return `
    <button class="btn" data-action="paste-games" type="button">Paste a batch of games</button>
    <button class="btn" data-action="import-historical" type="button">
      ${ui.confirmingHistoricalImport ? 'Choose a file of games?' : 'Import a batch from a file'}
    </button>
    <div class="roster-count">
      ${ui.confirmingHistoricalImport
        ? 'Tap again to choose a file. Games are added to this season; nothing already recorded is replaced.'
        : 'Adds games recorded before the app existed. Serves in and out only — that is all the paper had. Pasting is usually easier on a phone than saving a file.'}
    </div>`
}

/**
 * Pasting avoids the file system altogether. On iOS, saving a JSON file from Safari lands
 * it as ".json.txt", which is fiddly at best -- opening the file, selecting all and pasting
 * is both shorter and harder to get wrong.
 */
function pasteForm() {
  return `
    <form id="paste-games-form" autocomplete="off">
      <textarea name="games" rows="6" aria-label="Paste the games here"
                placeholder="Open the games file, select all, copy, and paste it here."></textarea>
      <div class="lineup-actions">
        <button class="btn btn-primary" type="submit">Load these games</button>
        <button class="btn" data-action="cancel-paste" type="button">Cancel</button>
      </div>
    </form>`
}

function nameOf(state, playerId) {
  return state.players.find((player) => player.id === playerId)?.name ?? 'Removed player'
}

function resultLabel(result) {
  if (result === MATCH_RESULT.WON) return 'Won'
  if (result === MATCH_RESULT.LOST) return 'Lost'
  return '—'
}

export { percent }
