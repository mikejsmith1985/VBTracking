// How big each box on the wrist is.
//
// The requirement is that the on-deck box — the player who takes the serve next — is the
// largest thing on the screen, because that is the decision the coach is making. On a
// 42 mm watch there is not much screen to spend, so the sizes are worked out here, where
// they can be checked by a test, rather than guessed at in a view that cannot be run.
//
// The court arrangement is not negotiable: the boxes stay where the players stand. So the
// grid tracks are uneven instead — the right column wider, the top row taller — which
// leaves the top-right box uniquely the biggest without moving anybody.
import Foundation
import VBCore

/// The proportions of the grid. Multipliers, not points: the watch decides the points.
public enum CourtLayout {
    /// Column widths, left to right. The right column is where the service corner and the
    /// on-deck box both stand.
    public static let columnWeights: [Double] = [1, 1, 1.35]

    /// Row heights, front to back. The front row is taller because the on-deck box is in it.
    public static let rowWeights: [Double] = [1.25, 1]

    /// The gap between boxes, and the margin around them, as a fraction of the screen's
    /// shorter side. Small: every point spent on space is a point not spent on a number.
    public static let gapFraction = 0.02

    /// The smallest screen this has to work on: an Apple Watch Series 11 at 42 mm.
    /// If the court reads here it reads on the 46 mm.
    public static let designSize = (width: 374.0, height: 446.0)

    /// The box sizes for a given area, in the order the boxes are drawn.
    public static func boxes(in size: (width: Double, height: Double)) -> [BoxSize] {
        let gap = min(size.width, size.height) * gapFraction
        let usableWidth = size.width - gap * Double(columnWeights.count + 1)
        let usableHeight = size.height - gap * Double(rowWeights.count + 1)

        let widths = share(usableWidth, by: columnWeights)
        let heights = share(usableHeight, by: rowWeights)

        return CourtPosition.drawingOrder.enumerated().map { index, position in
            BoxSize(
                position: position,
                width: widths[index % columnWeights.count],
                height: heights[index / columnWeights.count]
            )
        }
    }

    /// Splits a length between weights.
    private static func share(_ total: Double, by weights: [Double]) -> [Double] {
        let sum = weights.reduce(0, +)
        return weights.map { total * $0 / sum }
    }
}

/// One box's measurements.
public struct BoxSize: Equatable, Sendable {
    public var position: CourtPosition
    public var width: Double
    public var height: Double

    /// What the box occupies. The requirement is written in terms of area, so the check is.
    public var area: Double { width * height }
}

/// How the numbers inside a box are set.
///
/// The jersey number is what the coach scans for, so it is the largest thing in every box —
/// and largest of all in the box that matters. The percentage is second and the points
/// third, because that is the order the decision is made in: who, then how they have been
/// serving, then what it has been worth.
public struct BoxTypography: Equatable, Sendable {
    public var number: Double
    public var percentage: Double
    public var points: Double

    /// The type for a box, given whether it is the one the coach is deciding about.
    public static func forBox(isOnDeck: Bool) -> BoxTypography {
        isOnDeck
            ? BoxTypography(number: 46, percentage: 16, points: 14)
            : BoxTypography(number: 32, percentage: 13, points: 12)
    }
}
