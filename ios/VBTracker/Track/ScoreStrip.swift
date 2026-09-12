// The score of the match, at the top of the screen, tappable.
//
// Rally scoring gives a point to somebody on every rally, and the serve chart already holds
// half of them -- a serve in for a point is ours, a serve in without one or a serve out is
// theirs. The half nobody could write down is the rallies played while the OTHER team has the
// ball, and those are what these two numbers take.
//
// At the top rather than in the dock, deliberately. The dock holds a status row over exactly
// one action block, and this is the screen where a mis-tap costs a recorded serve -- so the
// two things that must never be confused are kept at opposite ends of the phone.
//
// They only accept a tap while our side is not serving, which the record already knows: the
// rotation hands the ball on the moment a turn ends, so the next player holds it without
// having served for the whole spell the other team is serving. Once they have served once,
// every rally is a serve, and these go quiet rather than double-count it.
import SwiftUI
import VBCore
import VBPresentation

struct ScoreStrip: View {
    let store: Store
    /// Whether a tap would be taken. False while one of ours is actually serving.
    let canRecord: Bool

    private var score: Scoreboard? { store.state.currentMatch?.rallyScore }

    var body: some View {
        HStack(spacing: 8) {
            side("US", points: score?.us, toUs: true)
            Text(canRecord ? "tap to score" : "on serve")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(minWidth: 62)
            side("THEM", points: score?.them, toUs: false)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .accessibilityIdentifier("score-strip")
    }

    /// One half of the scoreboard.
    ///
    /// A dash rather than a zero until somebody has recorded a rally on the other team's
    /// serve. Our half alone would say the opposition had scored nothing, which is a lie
    /// with a number on it -- the same reason a serve figure never recorded shows a dash.
    private func side(_ name: String, points: Int?, toUs: Bool) -> some View {
        Button {
            store.recordRallyPoint(toUs: toUs)
        } label: {
            HStack(spacing: 5) {
                Text(name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(points.map(String.init) ?? "\u{2014}")
                    .font(.system(size: 26, weight: .heavy, design: .rounded).monospacedDigit())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(canRecord ? Color.cyan.opacity(0.16) : Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
        .disabled(!canRecord)
        .accessibilityIdentifier(toUs ? "score-us" : "score-them")
        .accessibilityLabel(toUs ? "Add a point for us" : "Add a point for them")
    }
}
