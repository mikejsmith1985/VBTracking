// One turn, opened for correction.
//
// The serves are the buttons themselves: tapping one cycles it, which is the correction
// actually wanted almost every time — a serve recorded as a point that was not, or an out
// that landed in.
import SwiftUI
import VBCore
import VBPresentation

struct TurnEditor: View {
    let store: Store
    let gameId: String
    let match: Match
    let turn: Turn

    @Binding var reassigning: TurnLocation?
    @Binding var inserting: InsertLocation?
    @Binding var confirmingDelete: TurnLocation?
    let onClose: () -> Void

    private var location: TurnLocation {
        TurnLocation(matchIndex: match.index, ordinal: turn.ordinal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            // Each serve is its own target, sized for a thumb: this is the correction being
            // made almost every time, and a mis-tap here writes the wrong figure again.
            HStack(spacing: 6) {
                ForEach(Array(turn.serves.enumerated()), id: \.offset) { index, serve in
                    Button(label(for: serve.outcome)) { cycle(at: index) }
                        .buttonStyle(.bordered)
                        .tint(tint(for: serve.outcome))
                        .accessibilityIdentifier("cycle-serve-\(index)")
                }
                Button("＋") { add() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("add-serve")
            }

            Text("Tap a serve to change it: point, then in, then out. ＋ adds one to the end.")
                .font(.caption2).foregroundStyle(.secondary)

            HStack {
                Button("Remove last serve") { removeLast() }
                    .disabled(turn.serves.count <= 1)
                    .accessibilityIdentifier("drop-serve")
                Spacer()
                Button(reassigning == location ? "Cancel" : "Wrong player?") {
                    reassigning = reassigning == location ? nil : location
                }
                .accessibilityIdentifier("reassign-turn")
            }
            .font(.caption)

            if reassigning == location { reassignChoices }

            Button(confirmingDelete == location ? "Delete this whole turn?" : "Delete this turn", role: .destructive) {
                guard confirmingDelete == location else { confirmingDelete = location; return }
                if store.dispatch(.deleteTurn(gameId: gameId, matchIndex: match.index, ordinal: turn.ordinal)) {
                    confirmingDelete = nil
                    onClose()
                }
            }
            .font(.caption)
            .accessibilityIdentifier("delete-turn")

            if confirmingDelete == location {
                Text("Tap again to delete. Every serve in it goes too, and the turns after it renumber.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var header: some View {
        HStack {
            Text("\(turn.ordinal + 1)")
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color(hex: colorForTurn(turn.ordinal))))
                .foregroundStyle(.black)
            Text(store.state.rosterEntry(id: turn.playerId)?.name ?? "Removed player").font(.subheadline)
            Spacer()
            Button("Done", action: onClose)
                .font(.caption)
                .accessibilityIdentifier("close-turn")
        }
    }

    /// Anyone on the roster: a turn can be credited to whoever was actually there.
    private var reassignChoices: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 6) {
            ForEach(store.state.roster.filter { $0.id != turn.playerId }, id: \.id) { player in
                Button("\(text(number: player.number))  \(player.name)") {
                    let accepted = store.dispatch(
                        .reassignTurn(
                            gameId: gameId,
                            matchIndex: match.index,
                            ordinal: turn.ordinal,
                            playerId: player.id
                        )
                    )
                    if accepted { reassigning = nil }
                }
                .font(.caption)
                .accessibilityIdentifier("reassign-to-\(player.id)")
            }
        }
    }

    // MARK: - The corrections

    /// The whole list is sent, not the single serve that moved: the event says what the
    /// turn holds now, so replaying it can never depend on what it held when the button
    /// was tapped.
    private func setServes(_ outcomes: [Outcome]) {
        store.dispatch(
            .setTurnServes(
                gameId: gameId,
                matchIndex: match.index,
                ordinal: turn.ordinal,
                outcomes: outcomes.map(\.rawValue)
            )
        )
    }

    private func cycle(at index: Int) {
        var outcomes = turn.serves.map(\.outcome)
        outcomes[index] = next(after: outcomes[index])
        setServes(outcomes)
    }

    private func add() {
        setServes(turn.serves.map(\.outcome) + [.out])
    }

    /// Never to nothing: a turn with no serves is a turn that did not happen, and deleting
    /// it is a different decision with its own confirmation.
    private func removeLast() {
        let outcomes = turn.serves.map(\.outcome)
        guard outcomes.count > 1 else { return }
        setServes(Array(outcomes.dropLast()))
    }

    /// Tapping a serve moves it round this ring, so any mark can become any other without a
    /// menu. Three taps returns it to where it started.
    private func next(after outcome: Outcome) -> Outcome {
        switch outcome {
        case .inPoint: .inNoPoint
        case .inNoPoint: .out
        case .out: .inPoint
        }
    }

    private func label(for outcome: Outcome) -> String {
        switch outcome {
        case .inPoint: "Pt"
        case .inNoPoint: "In"
        case .out: "Out"
        }
    }

    private func tint(for outcome: Outcome) -> Color {
        switch outcome {
        case .inPoint: .green
        case .inNoPoint: .cyan
        case .out: .red
        }
    }
}
