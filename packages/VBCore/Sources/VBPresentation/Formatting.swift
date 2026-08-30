// How a figure reads.
//
// The one rule this file exists for: a figure that was never recorded is a dash. Not a
// zero, not "0%", not an empty space that could be read as either. A game copied from paper
// recorded no points, and reporting nought would say the players earned none.
//
// It lives here rather than in a view because a view on this workstation cannot be run, let
// alone tested — and this is the rule most worth being sure of.
import Foundation
import VBCore

/// What is shown where a figure is missing. One character, unmistakable, and the same one
/// everywhere.
public let missingFigure = "—"

/// A count, or a dash when it was never recorded.
public func text(count: Int?) -> String {
    guard let count else { return missingFigure }
    return String(count)
}

/// A percentage as whole points, or a dash when nothing was served.
///
/// Rounded rather than truncated: 0.666 is 67%, because a player who lands two of three is
/// closer to two thirds than to a rounded-down 66.
public func text(percentage: Double?) -> String {
    guard let percentage else { return missingFigure }
    return "\(Int((percentage * 100).rounded()))%"
}

/// A jersey number, or a marker when a player has none — so they stay identifiable.
public func text(number: String?) -> String {
    guard let number, !number.trimmingCharacters(in: .whitespaces).isEmpty else { return "–" }
    return number
}

/// How a result reads on a screen.
public func text(result: MatchResult) -> String {
    switch result {
    case .won: "Won"
    case .lost: "Lost"
    case .undecided: missingFigure
    }
}

/// A season's record, as it is spoken: "3–2", with games left unrecorded named separately.
public func text(record: Record) -> String {
    let core = "\(record.won)–\(record.lost)"
    guard record.undecided > 0 else { return core }
    return "\(core) · \(record.undecided) not recorded"
}

/// How long ago something was, in the words a glance can take in.
///
/// Used by the watch to say how current the court is. Deliberately coarse: the coach needs
/// to know whether this is now or not, and a figure to the second invites reading it.
public func text(secondsAgo seconds: Int) -> String {
    switch seconds {
    case ..<5: "just now"
    case ..<60: "\(seconds)s ago"
    case ..<3600: "\(seconds / 60)m ago"
    default: "over an hour ago"
    }
}

/// What a game is called on a list, when it has no opponent recorded.
public let unnamedOpponent = "Unnamed opponent"

/// The line naming a game: who, and when.
public func title(of game: Game) -> String {
    game.context.opponent.trimmingCharacters(in: .whitespaces).isEmpty
        ? unnamedOpponent
        : game.context.opponent
}

/// The date a game was played, or a plain admission that it is not recorded.
public func subtitle(of game: Game) -> String {
    game.context.date ?? "No date"
}

/// The heading over the points column, marked when the figure covers fewer games than the
/// serve columns beside it do.
///
/// Serves and serves-in span every game, because a paper sheet recorded them. Points exist
/// only where play was tracked serve by serve. On a season that mixes the two the last
/// column answers a different question from the others, and a reader comparing two players
/// down that column has to be told so before they draw a conclusion from it.
public func pointsHeading(coverage: Coverage?) -> String {
    isPointsASubset(coverage) ? "Pts*" : "Pts"
}

/// True when the points column covers fewer games than the season holds.
public func isPointsASubset(_ coverage: Coverage?) -> Bool {
    guard let coverage else { return false }
    return coverage.trackedGames < coverage.totalGames
}

/// The line under the table explaining the marked column, or nothing when every game was
/// tracked and there is nothing to explain.
public func coverageNote(_ coverage: Coverage?) -> String? {
    guard let coverage, isPointsASubset(coverage) else { return nil }
    let tracked = coverage.trackedGames
    let untracked = coverage.totalGames - tracked
    return "* Points come from the \(tracked) \(word(games: tracked)) of \(coverage.totalGames) "
        + "tracked serve by serve. The other \(untracked) \(word(games: untracked)) came from paper, "
        + "which recorded serves only — so a dash there is a figure nobody wrote down, not a nought."
}

/// "game" or "games", so the sentence reads as one a person would say.
private func word(games count: Int) -> String {
    count == 1 ? "game" : "games"
}
