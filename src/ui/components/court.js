// The six on court, laid out as the court itself: net at the top, service position at the
// bottom right, and the rotation running clockwise through the other five.
//
// The flat grid it replaces was a list of numbers in roster order, which asked the operator
// to hold the serving order in their head while watching the game. Here the arrangement IS
// the order: whoever is standing in the service corner has the ball, and the player who
// takes it next is the one directly above them, exactly as on the floor.
//
// Everyone else is a substitute, and is shown as one -- off the court, marked as bench.
import { chip } from './chip.js'
import { LINEUP_SIZE } from '../../domain/events.js'

// Court positions in the order they are drawn: front row left to right, then back row.
// The number is how far along the serving order that position stands from the server, so
// the whole court re-lays itself around whoever is serving now.
const LAYOUT = [
  { offset: 3, label: '4' },
  { offset: 2, label: '3' },
  { offset: 1, label: '2' },
  { offset: 4, label: '5' },
  { offset: 5, label: '6' },
  { offset: 0, label: '1' },
]

/**
 * The court and the bench.
 *
 * `servingPosition` is the lineup index standing in the service corner. `stateFor` marks a
 * chip exactly as it does anywhere else, so a serving or half-substituted player looks the
 * same here as in the picker it replaces.
 */
export function courtView(roster, lineup, options = {}) {
  const servingPosition = options.servingPosition ?? 0
  const stateFor = options.stateFor ?? (() => '')
  const action = options.action ?? 'select-server'

  const cells = LAYOUT
    .map((slot) => courtCell(roster, lineup, slot, servingPosition, stateFor, action))
    .join('')

  return `
    <div class="court">
      <div class="court-net" aria-hidden="true"></div>
      <div class="court-grid">${cells}</div>
    </div>
    ${benchRow(roster, lineup, stateFor, action)}`
}

/** The lineup index standing at a court position, wrapping round the order. */
export function positionAt(servingPosition, offset) {
  return (servingPosition + offset) % LINEUP_SIZE
}

function courtCell(roster, lineup, slot, servingPosition, stateFor, action) {
  const index = positionAt(servingPosition, slot.offset)
  const player = roster.find((each) => each.id === lineup[index])
  const classes = ['court-cell', slot.offset === 0 ? 'is-service' : '', slot.offset === 1 ? 'is-next' : '']
    .filter(Boolean).join(' ')

  // A slot can empty when a player leaves the roster mid-match. It is still a position in
  // the order, and drawing it says so -- silently closing the gap would misreport who
  // serves next.
  const body = player
    ? chip(player, { action, state: stateFor(player) })
    : '<div class="court-empty" aria-label="Nobody in this position">—</div>'

  return `
    <div class="${classes}">
      <span class="court-pos">${slot.label}</span>
      ${body}
      ${slot.offset === 0 ? '<span class="court-tag">serving</span>' : ''}
      ${slot.offset === 1 ? '<span class="court-tag court-tag-next">next</span>' : ''}
    </div>`
}

/**
 * Everyone not on the court. They are the other half of a substitution -- tapped first,
 * then the player they replace -- so they are kept plainly apart from the six who are on.
 */
function benchRow(roster, lineup, stateFor, action) {
  const bench = roster.filter((player) => !lineup.includes(player.id))
  if (bench.length === 0) return ''

  const chips = bench
    .map((player) => chip(player, { action, state: `is-bench ${stateFor(player)}`.trim() }))
    .join('')

  return `
    <div class="bench">
      <div class="bench-label">Bench</div>
      <div class="bench-chips">${chips}</div>
    </div>`
}
