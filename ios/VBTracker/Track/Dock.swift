// What sits under the thumb.
//
// A status row over exactly ONE action block: the outcome controls, or the court. Never
// both — a control that is present but wrong is a mis-tap, and here a mis-tap is a serve
// recorded against the wrong player.
import SwiftUI
import VBCore
import VBPresentation

struct Dock: View {
    let store: Store
    let dock: DockState
    @Binding var armed: Armed?
    @Binding var isPickerRequested: Bool
    @Binding var isChoosingLineup: Bool
    let onServe: (Outcome) -> Void
    /// False on a phone following somebody else's match. The controls come off rather than
    /// grey out: a disabled button still invites the tap, and the tap does nothing.
    var canRecord = true

    var body: some View {
        VStack(spacing: 8) {
            StatusRow(
                store: store,
                dock: dock,
                isPickerRequested: $isPickerRequested,
                isChoosingLineup: $isChoosingLineup
            )

            switch dock.content {
            case .outcomes:
                if canRecord { OutcomeControls(onServe: onServe) }
            case .picker:
                CourtPicker(store: store, armed: $armed, isPickerRequested: $isPickerRequested)
            case .nothing:
                EmptyView()
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .background(.thinMaterial)
    }
}

/// Who is serving, and the three things that are never in the way of recording.
private struct StatusRow: View {
    let store: Store
    let dock: DockState
    @Binding var isPickerRequested: Bool
    @Binding var isChoosingLineup: Bool

    private var serving: RosterEntry? {
        dock.servingPlayerId.flatMap { store.state.rosterEntry(id: $0) }
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(dock.isRecording ? "Now serving" : "Next server")
                    .font(.caption2).textCase(.uppercase).foregroundStyle(.secondary)
                if let serving {
                    // The app chooses the server now, so a wrong one is the app's mistake
                    // and the operator has to catch it. Hence the display size.
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(text(number: serving.number)).font(.system(size: 34, weight: .heavy))
                        Text(serving.name).font(.subheadline)
                    }
                }
            }
            Spacer()

            if dock.hasLineup || dock.canArrangeRotation {
                Button("Order") { isChoosingLineup = true }
                    .buttonStyle(.bordered).controlSize(.small)
                    .accessibilityIdentifier("set-order")
            }
            if dock.servingPlayerId != nil {
                Button(isPickerRequested ? "Cancel" : "Change") { isPickerRequested.toggle() }
                    .buttonStyle(.bordered).controlSize(.small)
            }
            Button("Undo") { store.undo() }
                .buttonStyle(.bordered).controlSize(.small)
                .disabled(!dock.canUndo)
                .accessibilityIdentifier("undo")
        }
        .padding(.horizontal, 6)
    }
}

/// The three outcomes, in the thumb zone, one tap each.
struct OutcomeControls: View {
    let onServe: (Outcome) -> Void

    /// Two serves cannot physically occur this close together, so a tap inside this window
    /// is a stray repeat and is ignored.
    private static let repeatGuard: TimeInterval = 0.3
    @State private var lastTap = Date.distantPast

    var body: some View {
        HStack(spacing: 8) {
            control("OUT", detail: "turn ends", tint: .red, outcome: .out)
            control("IN", detail: "no point — turn ends", tint: .cyan, outcome: .inNoPoint)
            control("IN — POINT", detail: "keep serving", tint: .green, outcome: .inPoint)
        }
        .frame(height: 96)
    }

    private func control(_ title: String, detail: String, tint: Color, outcome: Outcome) -> some View {
        Button {
            let now = Date()
            guard now.timeIntervalSince(lastTap) > Self.repeatGuard else { return }
            lastTap = now
            onServe(outcome)
        } label: {
            VStack(spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .accessibilityIdentifier("serve-\(outcome.rawValue)")
    }
}
