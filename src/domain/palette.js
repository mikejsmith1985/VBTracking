// Colours used to tell one serve turn from the next. Colour encodes the TURN, never
// the outcome -- outcomes are encoded by mark shape so the display stays readable
// without colour vision.

// Six hues, ordered so that neighbouring entries are far apart on the colour wheel and
// so that the wrap from the last back to the first is far apart too. Every one clears
// WCAG AA contrast against the app's dark background.
export const PALETTE = Object.freeze([
  '#22d3ee', // cyan
  '#f59e0b', // amber
  '#818cf8', // indigo
  '#a3e635', // lime
  '#fb7185', // rose
  '#e879f9', // fuchsia
])

/**
 * The colour for a serve turn at the given position within its match.
 * Depends only on the ordinal, so a turn's colour never changes because of something
 * that happened later -- which is what keeps replay deterministic.
 */
export function colorForTurn(ordinal) {
  return PALETTE[colorIndexForTurn(ordinal)]
}

/** The palette index for a turn ordinal. Adjacent ordinals never collide. */
export function colorIndexForTurn(ordinal) {
  return ((ordinal % PALETTE.length) + PALETTE.length) % PALETTE.length
}
