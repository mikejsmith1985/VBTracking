// Keeping score for a game nobody is tracking.
//
// Separate from everything else on purpose. A season has rosters, serve turns, statistics
// and a record; a Saturday in the park has two numbers. Running the second through the
// first would mean inventing a game, a roster and six players to count to twenty-one, and
// it would put a scratch game in the season record where somebody would later have to find
// it and take it out.
//
// So this touches no log, no season and no player. It is two numbers and the rules for
// when they mean somebody has won.
import Foundation
import VBCore

/// Which side of the net.
public enum Side: String, CaseIterable, Codable, Sendable {
    case us
    case them

    public var label: String {
        switch self {
        case .us: "US"
        case .them: "THEM"
        }
    }
}

/// A scratch game's score, and what it means.
public struct Scoreboard: Equatable, Codable, Sendable {
    public private(set) var us: Int
    public private(set) var them: Int

    /// Where the game is being played to.
    public var target: Int

    public init(us: Int = 0, them: Int = 0, target: Int = targetScore) {
        self.us = us
        self.them = them
        self.target = target
    }

    /// Reads a board that may have been written by an earlier build.
    ///
    /// Leniently, for the same reason the court is: a missing key throws through the
    /// generated decoder, and a throw here loses a game in progress that has no other copy
    /// anywhere. A board that cannot be fully read is still better read as far as it goes.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.us = try container.decodeIfPresent(Int.self, forKey: .us) ?? 0
        self.them = try container.decodeIfPresent(Int.self, forKey: .them) ?? 0
        self.target = try container.decodeIfPresent(Int.self, forKey: .target) ?? targetScore
    }

    /// The score on one side.
    public func score(_ side: Side) -> Int {
        switch side {
        case .us: us
        case .them: them
        }
    }

    /// Adds a point to one side.
    ///
    /// Points keep being accepted after the game is won. A referee's call, a let, a rally
    /// nobody agreed on: the scoreboard is not the authority on when to stop, the people
    /// on the court are.
    public mutating func award(to side: Side) {
        switch side {
        case .us: us += 1
        case .them: them += 1
        }
    }

    /// Takes a point off one side.
    ///
    /// Per side rather than a single undo of the last thing done. A scorekeeper who has
    /// given a point to the wrong team knows which team; asking them to work out how many
    /// steps back that was, in a gym, is asking for the wrong correction.
    public mutating func subtract(from side: Side) {
        guard canSubtract(from: side) else { return }
        switch side {
        case .us: us -= 1
        case .them: them -= 1
        }
    }

    /// True while there is a point on that side to take off. Nothing goes below nothing.
    public func canSubtract(from side: Side) -> Bool {
        score(side) > 0
    }

    /// Back to nothing, ready for the next game. The target is kept: it is a choice about
    /// how they are playing today, not part of the score.
    public mutating func reset() {
        us = 0
        them = 0
    }

    /// True when there is a game here at all, so a reset that would change nothing can say
    /// so rather than asking to be confirmed.
    public var hasStarted: Bool { us > 0 || them > 0 }

    /// The side that has won, or nil while it is still a game.
    ///
    /// To the target and two clear. Both halves matter: 21-20 is not a win, and 26-24 is,
    /// which is the whole reason a scoreboard is worth more than counting on fingers.
    public var winner: Side? {
        guard max(us, them) >= target, abs(us - them) >= 2 else { return nil }
        return us > them ? .us : .them
    }

    /// The side one point from winning, or nil.
    ///
    /// Worth saying out loud, because it is the point where somebody starts wanting to
    /// argue about the score.
    public var onGamePoint: Side? {
        guard winner == nil else { return nil }
        if wouldWin(.us) { return .us }
        if wouldWin(.them) { return .them }
        return nil
    }

    private func wouldWin(_ side: Side) -> Bool {
        var next = self
        next.award(to: side)
        return next.winner == side
    }

    /// The line under the numbers: who has won, who is a point away, or how it is being
    /// played.
    public var status: String {
        if let winner { return "\(winner.label) WIN" }
        if let onGamePoint { return "\(onGamePoint.label) game point" }
        if max(us, them) >= target - 1 { return "to \(target), win by 2" }
        return "playing to \(target)"
    }

    /// The targets offered, because a scratch game is played to whatever was agreed on the
    /// way to the court.
    public static let targets = [11, 15, 21, 25]
}

/// How big each control on the scoreboard is.
///
/// Here rather than in the view for the same reason the court's boxes are: there is no Mac
/// on which to look at the screen, so "the score button is the big one" has to be a number
/// something can check rather than an impression somebody has.
///
/// These are drawn by the view itself rather than handed to `.bordered`. watchOS's bordered
/// style imposes its own control height and ignores a frame asked for inside it, which put
/// the US and THEM labels outside the pill they belonged in and made the minus buttons very
/// nearly as tall as the scores. A shape this file decides the size of is a shape these
/// numbers actually govern.
public enum ScoreLayout {
    /// The tappable height of one side's score. Also the button that adds a point.
    ///
    /// Tall enough that the side's name sits inside the pill with the figure, rather than
    /// riding on its edge.
    public static let scoreHeight = 90.0

    /// The size of the number in it.
    public static let scoreFontSize = 44.0

    /// The side's name above the figure, inside the same pill.
    public static let sideFontSize = 12.0

    /// How much vertical room a line of text takes beyond its point size.
    ///
    /// A font asked for at 44 pt does not occupy 44 pt of a stack; it occupies its line
    /// height. Checking a tile against raw point sizes measures the wrong thing and either
    /// passes a tile that clips or fails one that is fine.
    public static let lineHeightFactor = 1.25

    /// What the two lines inside a score tile actually take up.
    public static let scoreContentHeight = (sideFontSize + scoreFontSize) * lineHeightFactor

    /// The minus beneath, as it is drawn. Half the height it was: it is the control for
    /// fixing a mistake, and it should look like it.
    public static let minusPillHeight = 20.0

    /// The minus beneath, as it is tapped.
    ///
    /// Bigger than it is drawn, because a control small enough to read as secondary is
    /// smaller than a thumb. The extra is invisible and costs nothing but layout.
    public static let minusTapHeight = 24.0

    public static let minusFontSize = 10.0

    /// Starting again, across the bottom.
    public static let newGameHeight = 28.0

    public static let newGameFontSize = 13.0

    /// The line that says who is winning.
    public static let statusHeight = 12.0

    /// Between every stacked element.
    public static let spacing = 3.0

    /// The corner on every drawn control.
    public static let cornerRadius = 18.0

    /// How much bigger the scoring control looks than the correcting one.
    ///
    /// Adding a point happens every rally; taking one off happens when somebody made a
    /// mistake. The one under the thumb has to be the one that is right nearly every time,
    /// and this much difference is what makes that true without looking.
    public static let minimumScoreToMinusRatio = 4.0

    /// The smallest a control may be tapped at, however small it is drawn.
    public static let minimumTapHeight = 20.0

    /// What the whole page needs vertically, so it can be checked against the smallest
    /// watch rather than found not to fit on one.
    public static let requiredHeight =
        scoreHeight + minusTapHeight + newGameHeight + statusHeight + spacing * 4

    /// The shortest screen this has to fit on, in points.
    ///
    /// Note the unit. `CourtLayout.supportedWatchSizes` lists the 40 mm watch as 324 x 394,
    /// which is pixels; SwiftUI lays out in points, and the same watch is 162 x 197 of
    /// those. Mixing the two would make a page that "fits" at twice the room it has.
    public static let shortestScreenHeight = 197.0

    /// What is left after the system's own furniture — the status bar at the top and the
    /// home indicator at the bottom. Measured generously, because being wrong here means a
    /// control pushed off the bottom of the smallest watch anybody owns.
    public static let usableHeightFraction = 0.86
}

/// What the scoreboard is painted in.
///
/// Solid, bright tiles with dark figures on them — not a tint at low opacity over black.
/// The first attempt used the app's accent colour at 22% and the result was unreadable in a
/// lit room: the numbers were the same hue as the tile they sat on, and both were nearly the
/// colour of the screen behind. A scoreboard read at arm's length across a court has to be
/// the brightest thing on the wrist.
///
/// Written as hex here, and checked, because "bright enough" is exactly the kind of judgement
/// that cannot be made on a workstation with no watch attached to it.
public enum ScorePalette {
    /// The tile a side's score sits on.
    public static func fill(for side: Side) -> String {
        switch side {
        case .us: "#a8d5f0"  // light blue
        case .them: "#d5cbf5"  // light lavender
        }
    }

    /// The figure and the side's name, on that tile. Near-black, so the tile does the
    /// shining and the number does the reading.
    public static let figure = "#111826"

    /// The lesser controls: the minus bars and New game. Dark, so they recede behind the
    /// two things that matter.
    public static let controlFill = "#1b2030"

    public static let controlInk = "#c9d2e8"

    /// The line that says who is winning. Brighter than a caption, because at 2-2 it is the
    /// only thing on the page that is not a number.
    public static let statusInk = "#eef2fb"

    /// Once somebody has won, or is a point away.
    public static let alertInk = "#ffb454"

    /// The smallest contrast a figure may have against the tile under it.
    ///
    /// WCAG calls 7:1 "AAA" for body text. A scoreboard glanced at from the far side of a
    /// court in a lit gym has less time and worse conditions than a page of body text, so
    /// that is the floor here rather than the target.
    public static let minimumFigureContrast = 7.0

    /// The smallest contrast anything else may have.
    public static let minimumControlContrast = 4.5
}

/// How far apart two colours are, by the WCAG formula.
///
/// One number, so "is this readable" is a thing a test can answer.
public func contrastRatio(_ first: String, _ second: String) -> Double {
    let lighter = max(relativeLuminance(first), relativeLuminance(second))
    let darker = min(relativeLuminance(first), relativeLuminance(second))
    return (lighter + 0.05) / (darker + 0.05)
}

/// How bright a colour is to an eye, which is not how bright it is to a screen.
private func relativeLuminance(_ hex: String) -> Double {
    let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    let value = UInt64(digits, radix: 16) ?? 0
    let channels = [
        Double((value >> 16) & 0xff) / 255,
        Double((value >> 8) & 0xff) / 255,
        Double(value & 0xff) / 255,
    ]
    .map { channel in
        channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
}
