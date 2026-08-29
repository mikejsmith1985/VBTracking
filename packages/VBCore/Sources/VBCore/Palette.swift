// Colours that tell one serve turn from the next.
//
// Colour encodes the TURN, never the outcome. Outcomes are carried by the shape of a mark,
// so the tally board stays readable without colour vision.
import Foundation

/// Six hues, ordered so neighbouring entries are far apart on the colour wheel -- and so
/// the wrap from the last back to the first is far apart too. Every one clears WCAG AA
/// contrast against the app's dark background.
public let turnPalette = [
    "#22d3ee",  // cyan
    "#f59e0b",  // amber
    "#818cf8",  // indigo
    "#a3e635",  // lime
    "#fb7185",  // rose
    "#e879f9",  // fuchsia
]

/// The palette index for a turn ordinal. Adjacent ordinals never collide.
///
/// Depends only on the ordinal, so a turn's colour never changes because of something that
/// happened later -- which is what keeps replay deterministic.
public func colorIndexForTurn(_ ordinal: Int) -> Int {
    let count = turnPalette.count
    return ((ordinal % count) + count) % count
}

/// The colour for a serve turn at the given position within its match.
public func colorForTurn(_ ordinal: Int) -> String {
    turnPalette[colorIndexForTurn(ordinal)]
}
