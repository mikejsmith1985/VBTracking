// Colours that tell one player from the next.
//
// Colour encodes the PLAYER, never the outcome -- outcomes are carried by the shape of a
// mark, so the board stays readable without colour vision (FR-034).
//
// It used to encode the turn. "The green tallies are number 5" is something a coach can
// hold in their head across a whole match; "the green ones are the third turn of this
// match" is not. The native app changed first; this is the same rule, computed the same
// way, so a season looks the same in both.

// Six hues, ordered so that neighbouring entries are far apart on the colour wheel and so
// that the wrap from the last back to the first is far apart too. Every one clears WCAG AA
// contrast against the app's dark background.
export const PALETTE = Object.freeze([
  '#22d3ee', // cyan
  '#f59e0b', // amber
  '#818cf8', // indigo
  '#a3e635', // lime
  '#fb7185', // rose
  '#e879f9', // fuchsia
])

// The same six as hue, saturation and lightness, because a player's own turns are shades of
// their hue and a shade is a change to one of these numbers.
export const PLAYER_PALETTE = Object.freeze([
  Object.freeze({ hue: 188, saturation: 0.86, lightness: 0.53 }),
  Object.freeze({ hue: 38, saturation: 0.92, lightness: 0.5 }),
  Object.freeze({ hue: 234, saturation: 0.89, lightness: 0.74 }),
  Object.freeze({ hue: 83, saturation: 0.78, lightness: 0.55 }),
  Object.freeze({ hue: 351, saturation: 0.95, lightness: 0.71 }),
  Object.freeze({ hue: 292, saturation: 0.92, lightness: 0.73 }),
])

// How a player's own turns are told apart: lighter, darker, lighter still. Applied to the
// lightness, never the hue, so the colour still reads as theirs from across a court.
export const TURN_SHADES = Object.freeze([0, 0.14, -0.11, 0.25])

// The band of lightness that stays legible on the dark board at both ends.
const LIGHTEST = 0.88
const DARKEST = 0.36

/**
 * The colour for a serve turn at the given position within its match.
 *
 * Kept because the reducer stamps `colorIndex` on every turn from it, and that index is
 * part of the state a replayed log produces -- changing it would change what an old log
 * replays to, which is the one thing a migration must never do.
 */
export function colorForTurn(ordinal) {
  return PALETTE[colorIndexForTurn(ordinal)]
}

/** The palette index for a turn ordinal. Adjacent ordinals never collide. */
export function colorIndexForTurn(ordinal) {
  return ((ordinal % PALETTE.length) + PALETTE.length) % PALETTE.length
}

/**
 * The palette index for a player, by their place in the order they first served.
 *
 * Wrapping is unavoidable with more players than hues; the seventh takes the first hue
 * again, which is why `colorForPlayer` also darkens on each lap round.
 */
export function colorIndexForPlayer(index) {
  const count = PLAYER_PALETTE.length
  return ((index % count) + count) % count
}

/** A player's own colour, at their base shade. */
export function colorForPlayer(index) {
  return colorForPlayerTurn(index, 0)
}

/**
 * The colour of one turn: the player's hue, at the shade that turn of theirs takes.
 *
 * `turnIndex` counts the player's own turns, not the match's -- a player's second turn is
 * their second shade whether it was the second serve turn of the match or the ninth.
 */
export function colorForPlayerTurn(playerIndex, turnIndex) {
  const base = PLAYER_PALETTE[colorIndexForPlayer(playerIndex)]
  const shades = TURN_SHADES
  const shade = shades[((turnIndex % shades.length) + shades.length) % shades.length]

  // Past the sixth player the hues start again, so each lap round is darkened to keep the
  // seventh player from being mistaken for the first.
  const lap = playerIndex < 0 ? 0 : Math.floor(playerIndex / PLAYER_PALETTE.length)
  const lightness = clamp(base.lightness + shade - lap * 0.18, DARKEST, LIGHTEST)

  return hslToHex(base.hue, base.saturation, lightness)
}

/**
 * HSL to the hex the rest of the app draws in.
 *
 * Written out rather than left to CSS because the Swift app computes the same colours from
 * the same numbers, and a season has to look the same in both.
 */
export function hslToHex(hue, saturation, lightness) {
  const chroma = (1 - Math.abs(2 * lightness - 1)) * saturation
  const sector = (((hue % 360) + 360) % 360) / 60
  const second = chroma * (1 - Math.abs((sector % 2) - 1))
  const base = lightness - chroma / 2

  const [red, green, blue] =
    sector < 1 ? [chroma, second, 0]
    : sector < 2 ? [second, chroma, 0]
    : sector < 3 ? [0, chroma, second]
    : sector < 4 ? [0, second, chroma]
    : sector < 5 ? [second, 0, chroma]
    : [chroma, 0, second]

  return `#${[red, green, blue].map((channel) => hex(channel + base)).join('')}`
}

function hex(value) {
  return Math.round(clamp(value, 0, 1) * 255).toString(16).padStart(2, '0')
}

function clamp(value, low, high) {
  return Math.min(Math.max(value, low), high)
}
