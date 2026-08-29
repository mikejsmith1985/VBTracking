// The five-serve alert: the one thing in the app that deliberately interrupts.
//
// The limit is the referee's to enforce and the easiest thing on the court to lose count
// of, so it is not a badge in a corner -- it covers the screen, names who has finished and
// who has the ball next, and clears on any tap.
import { esc, playerById } from '../html.js'
import { SERVE_LIMIT } from '../../domain/stats.js'

/** The full-screen alert for a server who has taken their five. */
export function rotateOverlay(notice, roster) {
  const from = playerById(roster, notice.fromId)
  const to = notice.toId ? playerById(roster, notice.toId) : null

  return `
    <div class="rotate-overlay" data-action="dismiss-rotate">
      <div class="rotate-card" role="alert">
        <div class="rotate-icon" aria-hidden="true">⟳</div>
        <div class="rotate-title">Rotate</div>
        <div class="rotate-from">
          <b>${esc(from?.number) || '–'}</b> ${esc(from?.name ?? 'That player')} has served ${SERVE_LIMIT}
        </div>
        ${nextLine(to)}
        <button class="btn btn-primary rotate-dismiss" data-action="dismiss-rotate" type="button">Got it</button>
      </div>
    </div>`
}

/**
 * With an order set the app already knows who serves next and says so. Without one it must
 * not guess: the operator picks, and the alert says only that the turn is over.
 */
function nextLine(to) {
  if (!to) return '<div class="rotate-next">Pick the next server.</div>'
  return `<div class="rotate-next">Next up: <b>${esc(to.number) || '–'}</b> ${esc(to.name)}</div>`
}
