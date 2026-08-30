// Recording a serve from the wrist.
//
// Three buttons, one deliberate tap each. Never a gesture, never the crown, never anything
// a raised arm could trigger by itself — an evening of ordinary wrist movement must record
// nothing at all.
//
// The phone holds the truth. What is tapped here is queued, delivered exactly once, and
// shown as unsent until the phone says otherwise.
import SwiftUI
import VBCore
import VBPresentation
import WatchKit

struct RecordScreen: View {
    let link: WatchLink

    var body: some View {
        VStack(spacing: 4) {
            Header(link: link)

            button("OUT", tint: .red, outcome: .out)
            button("IN", tint: .cyan, outcome: .inNoPoint)
            button("IN — POINT", tint: .green, outcome: .inPoint)
        }
        .padding(.horizontal, 2)
    }

    private func button(_ title: String, tint: Color, outcome: Outcome) -> some View {
        Button {
            link.record(outcome)
            // Felt as well as seen: the coach is watching the court, not the wrist.
            WKInterfaceDevice.current().play(outcome == .inPoint ? .success : .click)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .accessibilityIdentifier("watch-serve-\(outcome.rawValue)")
    }

    // The five-serve limit is not checked here. It cannot be: the watch has no count of
    // the turn, only the court it was last sent, and the check that used to live here fired
    // on any serve that had scored a point -- which is not the rule and never was. The phone
    // holds the record, so the phone says when the limit is reached; see `RotateAlert`.
}

/// Who is serving, and what has not reached the phone.
private struct Header: View {
    let link: WatchLink

    private var serving: SnapshotSlot? {
        link.snapshot?.slots.first { $0.isServing }
    }

    var body: some View {
        HStack(spacing: 4) {
            if let serving {
                Text(text(number: serving.number))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                Text(text(percentage: serving.inPercentage))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text("No server").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            // A serve recorded out of range is never assumed safe.
            if let label = link.pending.label {
                Text(label).font(.system(size: 9)).foregroundStyle(.orange)
                    .accessibilityIdentifier("pending-serves")
            }
        }
    }
}
