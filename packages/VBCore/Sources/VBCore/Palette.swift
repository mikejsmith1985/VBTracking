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

// MARK: - A colour per player

/// One hue per player, so a colour means a person rather than a turn.
///
/// "The green tallies are number 5" is a thing a coach can hold in their head across a whole
/// match; "the green ones are the third turn of this match" is not. These are the same six
/// hues the turn palette uses, kept because their contrast against the dark board was
/// already worked out -- what changes is what they are attached to.
///
/// Hue, saturation and lightness rather than hex, because turns within a player are shades
/// of their hue, and a shade is a change to one of these numbers.
public let playerPalette: [(hue: Double, saturation: Double, lightness: Double)] = [
    (188, 0.86, 0.53),  // cyan
    (38, 0.92, 0.50),  // amber
    (234, 0.89, 0.74),  // indigo
    (83, 0.78, 0.55),  // lime
    (351, 0.95, 0.71),  // rose
    (292, 0.92, 0.73),  // fuchsia
]

/// How a player's own turns are told apart: lighter, darker, lighter still.
///
/// Applied to the player's lightness, never their hue, so the colour still reads as theirs
/// from across a court. Four steps because a player rarely serves more than four turns in a
/// match, and a fifth repeating the first is no worse than two turns being the same shade.
public let turnShades: [Double] = [0, 0.14, -0.11, 0.25]

/// The band of lightness that stays legible on the dark board at both ends.
private let legibleLightness = 0.36...0.88

/// The palette index for a player, by their place in the order they first served.
///
/// Wrapping is unavoidable with more players than hues; the seventh player takes the first
/// hue again, which is why `colorForPlayer` also darkens on each lap round.
public func colorIndexForPlayer(_ index: Int) -> Int {
    let count = playerPalette.count
    return ((index % count) + count) % count
}

/// A player's own colour, at their base shade.
public func colorForPlayer(_ index: Int) -> String {
    colorForTurn(playerIndex: index, turnIndex: 0)
}

/// The colour of one turn: the player's hue, at the shade that turn of theirs takes.
///
/// `turnIndex` counts the player's own turns, not the match's -- a player's second turn is
/// their second shade whether it was the second serve turn of the match or the ninth.
public func colorForTurn(playerIndex: Int, turnIndex: Int) -> String {
    let base = playerPalette[colorIndexForPlayer(playerIndex)]
    let shade = turnShades[((turnIndex % turnShades.count) + turnShades.count) % turnShades.count]

    // Past the sixth player the hues start again, so each lap round is darkened to keep the
    // seventh player from being mistaken for the first.
    let lap = Double(max(0, index(ofLap: playerIndex)))
    let lightness = (base.lightness + shade - lap * 0.18).clamped(to: legibleLightness)

    return hex(hue: base.hue, saturation: base.saturation, lightness: lightness)
}

/// Which time round the palette this player is.
private func index(ofLap playerIndex: Int) -> Int {
    playerIndex < 0 ? 0 : playerIndex / playerPalette.count
}

/// HSL to the hex the rest of the app draws in.
///
/// Written out rather than pulled from a colour library because the package has no
/// dependencies, and because a colour that cannot be computed on this workstation cannot be
/// tested on it either.
public func hex(hue: Double, saturation: Double, lightness: Double) -> String {
    let chroma = (1 - abs(2 * lightness - 1)) * saturation
    let sector = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
    let second = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
    let base = lightness - chroma / 2

    let (red, green, blue): (Double, Double, Double) =
        switch sector {
        case ..<1: (chroma, second, 0)
        case ..<2: (second, chroma, 0)
        case ..<3: (0, chroma, second)
        case ..<4: (0, second, chroma)
        case ..<5: (second, 0, chroma)
        default: (chroma, 0, second)
        }

    let channels = [red, green, blue].map { UInt8(((($0 + base) * 255).rounded()).clamped(to: 0...255)) }
    return "#" + channels.map { String(format: "%02x", $0) }.joined()
}

extension Double {
    /// Keeps a value inside a range, so a shade can be nudged without leaving the band that
    /// stays readable.
    fileprivate func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
