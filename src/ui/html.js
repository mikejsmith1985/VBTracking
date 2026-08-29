// Small formatting helpers shared by the screens. Presentation only -- no rules live here.

/** Escapes text for safe interpolation into markup. Player names are operator input. */
export function esc(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

/** A jersey badge followed by the player's name. */
export function playerLabel(player) {
  if (!player) return '<span class="jersey">?</span> Removed player'
  return `<span class="jersey">${esc(player.number || '—')}</span>${esc(player.name)}`
}

/** A percentage, or an em dash when the figure is undefined because nothing was served. */
export function percent(ratio) {
  return ratio === null || ratio === undefined ? '—' : `${Math.round(ratio * 100)}%`
}

/** Looks a player up by id, tolerating one that has since been removed. */
export function playerById(roster, playerId) {
  return roster.find((player) => player.id === playerId) ?? null
}
