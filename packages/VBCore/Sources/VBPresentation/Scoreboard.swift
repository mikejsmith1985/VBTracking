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
