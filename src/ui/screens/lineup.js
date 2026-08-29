// Lineup setup and review. Six players in serving order, chosen before the whistle when
// there is time to think, and read-only once the match has started -- a change mid-match
// is a substitution, so that the record cannot disagree with what was played.
import { LINEUP_SIZE } from '../../domain/events.js'
import { nextRotationPosition } from '../../domain/reducer.js'
import { chip } from '../components/chip.js'
import { esc, playerLabel, playerById } from '../html.js'

/** True when this match still needs a lineup decision from the operator. */
export function needsSetup(match, roster) {
  if (!match || match.lineup) return false
  if (roster.length < LINEUP_SIZE) return false
  return !match.turns.some((turn) => turn.serves.length > 0)
}

/** The setup step: pick six, in order, or skip and select each server by hand. */
export function setupView(context, match) {
  const { state, ui } = context
  const chosen = ui.lineupDraft ?? match.lineup ?? []
  const isComplete = chosen.length === LINEUP_SIZE

  return `
    <div class="section-title">Serving order — match ${match.index + 1}</div>
    <p class="lineup-hint">
      Tap six players in the order they serve. Three sit out, and that changes every match.
    </p>

    ${orderedSlots(chosen, state.roster)}

    <div class="section-title">${isComplete ? 'Tap a slot to remove' : `Choose ${LINEUP_SIZE - chosen.length} more`}</div>
    ${benchGrid(state.roster, chosen)}

    <div class="lineup-actions">
      <button class="btn btn-primary" data-action="confirm-lineup" type="button" ${isComplete ? '' : 'disabled'}>
        ${isComplete ? 'Use this order' : `${chosen.length} of ${LINEUP_SIZE} chosen`}
      </button>
      <button class="btn" data-action="skip-lineup" type="button">Skip — pick each server by hand</button>
    </div>`
}

/** The read-only view during a match, with the next server marked. */
export function reviewView(context, match) {
  const { state } = context
  const nextPosition = nextRotationPosition(match)

  const rows = (match.lineup ?? [])
    .map((playerId, position) => `
      <div class="lineup-row${position === nextPosition ? ' is-next' : ''}">
        <span class="chip-slot">${position + 1}</span>
        <span class="lineup-name">${playerId ? playerLabel(playerById(state.roster, playerId)) : 'Empty'}</span>
        ${position === nextPosition ? '<span class="lineup-next">serves next</span>' : ''}
      </div>`)
    .join('')

  return `
    <div class="section-title">Serving order — match ${match.index + 1}</div>
    ${rows}
    <p class="lineup-hint">
      The order is fixed once the match starts. To change who is on court, substitute:
      tap the player coming on in the picker, then tap whoever they replace.
    </p>
    <div class="lineup-actions">
      <button class="btn btn-primary" data-action="close-lineup" type="button">Back to the match</button>
      <button class="btn" data-action="skip-lineup" type="button">Stop using the rotation</button>
    </div>`
}

function orderedSlots(chosen, roster) {
  const slots = Array.from({ length: LINEUP_SIZE }, (unused, position) => {
    const playerId = chosen[position]
    if (!playerId) {
      return `<div class="lineup-row is-empty"><span class="chip-slot">${position + 1}</span>
        <span class="lineup-name">—</span></div>`
    }
    return `
      <button class="lineup-row" data-action="unchoose-lineup" data-id="${playerId}" type="button">
        <span class="chip-slot">${position + 1}</span>
        <span class="lineup-name">${playerLabel(playerById(roster, playerId))}</span>
      </button>`
  })
  return slots.join('')
}

function benchGrid(roster, chosen) {
  const available = roster.filter((player) => !chosen.includes(player.id))
  if (available.length === 0) return ''

  const chips = available
    .map((player) => `
      <div class="chip-captioned">
        ${chip(player, { action: 'choose-lineup' })}
        <span class="chip-caption">${esc(player.name)}</span>
      </div>`)
    .join('')

  return `<div class="chip-grid chip-grid-captioned">${chips}</div>`
}
