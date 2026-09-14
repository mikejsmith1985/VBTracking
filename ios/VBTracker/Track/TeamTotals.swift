// What the whole side did, as one row.
//
// The tally board has always answered "how is this player serving". It could not answer "how
// are we serving", which is the question somebody asks between sets and at the end of a game
// -- and which nobody could work out from six rows of marks without adding them up by hand.
//
// Two percentages, because they are different questions and the gap between them is the
// interesting part: a side can put nine serves in ten over the net and win nothing with any
// of them.
import SwiftUI
import VBCore
import VBPresentation

struct TeamTotals: View {
    let figures: Figures
    /// What the figures cover, in words -- "this match", "this game".
    let scope: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(scope.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(figures.turnsTaken) serve turns")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 10) {
                total("SERVES", value: "\(figures.serves)")
                total("IN", value: text(percentage: figures.inPercentage), detail: "\(figures.servesIn)")
                total("POINTS", value: text(percentage: figures.pointPercentage), detail: "\(figures.points)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("team-totals")
    }

    /// One figure, with the count it came from underneath it.
    ///
    /// The count is there because a percentage on its own hides how much it is standing on:
    /// two serves in three and twenty in thirty both read 67%, and only one of them is worth
    /// substituting over.
    private func total(_ name: String, value: String, detail: String? = nil) -> some View {
        VStack(spacing: 1) {
            Text(name).font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded).monospacedDigit())
            if let detail {
                Text(detail)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
