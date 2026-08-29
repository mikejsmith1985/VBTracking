// The player chip. One implementation for all three places a player is tapped -- the
// picker, lineup setup, and substitution -- so they cannot drift apart.
//
// It shows the jersey number alone, typographically large. A truncated name is neither a
// name nor readable at arm's length, and the number is what the operator scans for anyway.
// Full names live where the space exists: the tally board and the statistics views.
import { esc } from '../html.js'

/** Shown when a player has no jersey number, so they stay identifiable and tappable. */
const NO_NUMBER = '–'

/**
 * One player chip.
 *
 * `state` marks it: 'serving', 'armed' (half of a substitution), 'in-lineup', or ''.
 */
export function chip(player, { action = 'select-server', state = '', position = null } = {}) {
  const marker = position === null ? '' : `<span class="chip-slot">${position + 1}</span>`

  return `
    <button class="chip ${state}" data-action="${action}" data-id="${player.id}" type="button"
            aria-label="${esc(player.name)}${player.number ? `, number ${esc(player.number)}` : ''}">
      ${marker}<span class="chip-number">${esc(player.number) || NO_NUMBER}</span>
    </button>`
}

/** A grid of chips, one per player given. */
export function chipGrid(players, options = {}) {
  const stateFor = options.stateFor ?? (() => '')
  const positionFor = options.positionFor ?? (() => null)

  const chips = players
    .map((player) => chip(player, {
      action: options.action,
      state: stateFor(player),
      position: positionFor(player),
    }))
    .join('')

  return `<div class="chip-grid">${chips}</div>`
}
