// One box on the court.
//
// The jersey number is what the coach scans for, so it is the largest thing in the box.
// The serve-in percentage is second and the points third — the order the decision is made
// in: who, then how they have been serving, then what it has been worth.
//
// A figure that was never recorded is a dash. Never a zero, which would say the player
// served and missed.
import SwiftUI
import VBCore
import VBPresentation

struct PlayerBox: View {
    let slot: SnapshotSlot
    let hasOrder: Bool

    private var type: BoxTypography { .forBox(isOnDeck: slot.isOnDeck) }

    var body: some View {
        VStack(spacing: 0) {
            Text(text(number: slot.number))
                .font(.system(size: type.number, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if slot.number != nil {
                // Both figures carry full weight and a step more contrast than they did.
                // At tertiary they were the dimmest thing on a screen read at arm's length,
                // in a gym, in a second -- which is the one place quiet type does not work.
                Text(text(percentage: slot.inPercentage))
                    .font(.system(size: type.percentage, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.primary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(text(count: slot.points))
                        .font(.system(size: type.points, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                    // The unit stays quiet. It is the same on every box, so it is recognised
                    // rather than read, and every point of width it gives back goes to a
                    // figure that does have to be.
                    Text("pts")
                        .font(.system(size: type.pointsLabel))
                        .foregroundStyle(.tertiary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
        .overlay(border)
        .overlay(alignment: .topLeading) { marker }
        // A SwiftUI stack is not an accessibility element on its own, so an identifier put
        // on one is never matched by a test looking for it -- which is why every court
        // measurement failed on an app that was drawing the court perfectly well.
        // `.contain` rather than `.combine`: combining would fold the figures into one
        // label and take the dash away from the test that checks a dash is drawn.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(spokenLabel)
    }

    /// The service corner and the on-deck box are the two that must read first. Everything
    /// else is quiet on purpose.
    private var background: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(slot.isOnDeck ? Color.orange.opacity(0.22) : Color.white.opacity(0.06))
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(
                slot.isServing ? Color.cyan : (slot.isOnDeck ? Color.orange : Color.white.opacity(0.12)),
                lineWidth: slot.isServing || slot.isOnDeck ? 2 : 1
            )
    }

    /// Nothing is carried by colour alone: the two boxes that matter are also labelled, so
    /// they still read in the always-on display and to a colour-blind eye.
    @ViewBuilder private var marker: some View {
        if slot.isServing {
            CornerLabel("serving")
        } else if slot.isOnDeck, hasOrder {
            CornerLabel("next")
        }
    }

    private var identifier: String {
        if slot.isOnDeck { return "court-box-on-deck" }
        if slot.isServing { return "court-box-serving" }
        return "court-box-\(slot.court)"
    }

    private var spokenLabel: String {
        guard let number = slot.number else { return "Position \(slot.court), empty" }
        let role = slot.isServing ? "serving" : (slot.isOnDeck && hasOrder ? "next to serve" : "on court")
        let percentage = slot.inPercentage == nil ? "no serves yet" : "\(text(percentage: slot.inPercentage)) in"
        return "Number \(number), \(role), \(percentage)"
    }

    /// A small word in the corner of a box.
    ///
    /// Named apart from SwiftUI's own `Label`, which is a different thing and would shadow
    /// confusingly in a file that draws one box six times.
    private struct CornerLabel: View {
        let text: String

        init(_ text: String) { self.text = text }

        var body: some View {
            Text(text)
                .font(.system(size: 8, weight: .heavy))
                .textCase(.uppercase)
                .padding(.horizontal, 3)
                .padding(.top, 2)
        }
    }
}
