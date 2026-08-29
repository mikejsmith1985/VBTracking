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

    /// The smallest screen this has to work on.
    ///
    /// Not the operator's own watch — the smallest watch Apple still supports, which is a
    /// 40 mm Series 6 or SE. The court is designed against that, so every watch that can
    /// install the app can read it; anything bigger is the same layout with more room.
    public static let designSize = smallestSupportedWatch

    /// Every watch size the app can be installed on, smallest first.
    ///
    /// watchOS 11 reaches back to a Series 6, so these are the sizes in the field. They are
    /// listed rather than assumed because the layout has to be checked against all of them,
    /// and the smallest is the one that decides the design.
    public static let supportedWatchSizes: [(name: String, width: Double, height: Double)] = [
        (name: "40 mm (Series 6-9, SE)", width: 324, height: 394),
        (name: "41 mm (Series 7-9)", width: 352, height: 430),
        (name: "42 mm (Series 10-11)", width: 374, height: 446),
        (name: "44 mm (Series 6, SE)", width: 368, height: 448),
        (name: "45 mm (Series 7-9)", width: 396, height: 484),
        (name: "46 mm (Series 10-11)", width: 416, height: 496),
        (name: "49 mm (Ultra 1-2)", width: 410, height: 502),
    ]

    private static let smallestSupportedWatch = (width: 324.0, height: 394.0)

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
