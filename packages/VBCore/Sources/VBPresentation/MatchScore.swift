// The score of the match being tracked, worked out from what was recorded.
//
// Rally scoring means every rally is a point to somebody, and the serve chart already holds
// half of them: a serve in for a point is ours, a serve in without one or a serve out is
// theirs. What it cannot hold is the rallies played while the OTHER team had the ball -- and
// those are the ones nobody was writing down, so the sheet was always short by every point
// the opposition scored and every point we won to take the ball back.
//
// It produces the same `Scoreboard` the watch already keeps by hand, so there is one idea of
// a score in this app rather than two that could disagree.
//
// Derived on read, never stored. A total that is kept goes wrong the first time a serve is
// corrected, and corrections are half the reason this app exists.
import Foundation
import VBCore

extension Match {
    /// The score, or nil when nobody has recorded the other team's serves.
    ///
    /// Nil rather than a number, for the same reason a figure never recorded renders as a
    /// dash rather than a zero: a match tracked only for serve figures has a real score this
    /// app does not know, and showing our half as though it were the whole would say the
    /// opposition scored nothing.
    public var rallyScore: Scoreboard? {
        guard !opponentServeRallies.isEmpty else { return nil }
        return Scoreboard(
            us: pointsWonOnOurServe + opponentServeRallies.filter { $0 }.count,
            them: pointsLostOnOurServe + opponentServeRallies.filter { !$0 }.count
        )
    }

    /// Rallies we won while serving: every serve that scored.
    private var pointsWonOnOurServe: Int {
        turns.reduce(0) { $0 + $1.serves.filter { $0.outcome == .inPoint }.count }
    }

    /// Rallies they won while we served.
    ///
    /// A serve out is a point to them, and so is a serve that landed in without scoring:
    /// under rally scoring whoever wins the rally takes the point whoever served, and both
    /// of those outcomes end our turn precisely because we lost it.
    private var pointsLostOnOurServe: Int {
        turns.reduce(0) { $0 + $1.serves.filter { $0.outcome != .inPoint }.count }
    }
}
