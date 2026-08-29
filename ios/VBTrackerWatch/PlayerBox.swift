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
                Text(text(percentage: slot.inPercentage))
                    .font(.system(size: type.percentage, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)

                Text("\(text(count: slot.points)) pts")
                    .font(.system(size: type.points).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(background)
        .overlay(border)
        .overlay(alignment: .topLeading) { marker }
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
            Label("serving")
        } else if slot.isOnDeck, hasOrder {
            Label("next")
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
    private struct Label: View {
        let text: String

        init(_ text: String) { self.text = text }

        var body: some View {
            SwiftUI.Text(text)
                .font(.system(size: 8, weight: .heavy))
                .textCase(.uppercase)
                .padding(.horizontal, 3)
                .padding(.top, 2)
        }
    }
}
