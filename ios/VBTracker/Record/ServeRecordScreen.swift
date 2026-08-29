// The serve record of a game already played: every turn, in the order it happened, and
// every serve in it open to correction.
//
// The corrections save the moment they are tapped — there is nothing to submit, and nothing
// half-typed to lose. Each one is a new event appended to the log, so undo keeps working
// and the record of what was first entered is not destroyed by fixing it.
import SwiftUI
import VBCore
import VBPresentation

struct ServeRecordScreen: View {
    let store: Store
    let gameId: String

    @State private var openTurn: TurnLocation?
    @State private var reassigning: TurnLocation?
    @State private var inserting: InsertLocation?
    @State private var confirmingDelete: TurnLocation?

    private var game: Game? { store.state.game(id: gameId) }

    var body: some View {
        List {
            if let game, game.kind == .tracked {
                Text("Tap a turn to correct it. Every change saves as you make it, and Undo still works.")
                    .font(.caption).foregroundStyle(.secondary)

                ForEach(game.matches, id: \.index) { match in
                    Section(header: Text(header(for: match))) {
                        ForEach(match.turns.filter { !$0.serves.isEmpty }, id: \.ordinal) { turn in
                            turnView(match: match, turn: turn)
                        }
                        addTurnButton(match: match, after: match.turns.count - 1)
                    }
                }
            } else {
                Text("This game came from paper, so it has no serve-by-serve record.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Serve record")
    }

    private func header(for match: Match) -> String {
        let figures = match.statistics.values
        let serves = figures.reduce(0) { $0 + $1.serves }
        let servesIn = figures.reduce(0) { $0 + $1.servesIn }
        return "Match \(match.index + 1) · \(servesIn)/\(serves) in · \(match.score) pts"
    }

    @ViewBuilder
    private func turnView(match: Match, turn: Turn) -> some View {
        let location = TurnLocation(matchIndex: match.index, ordinal: turn.ordinal)

        if openTurn == location {
            TurnEditor(
                store: store,
                gameId: gameId,
                match: match,
                turn: turn,
                reassigning: $reassigning,
                inserting: $inserting,
                confirmingDelete: $confirmingDelete,
                onClose: { openTurn = nil }
            )
        } else {
            Button { openTurn = location } label: { TurnRow(store: store, turn: turn) }
                .accessibilityIdentifier("turn-\(match.index)-\(turn.ordinal)")
        }
    }

    /// Adding a turn nobody recorded at the time.
    ///
    /// Offered at the end of every match, and inside an open turn — because a turn is
    /// missed in two ways: noticed later, and noticed at the end.
    @ViewBuilder
    private func addTurnButton(match: Match, after ordinal: Int) -> some View {
        let location = InsertLocation(matchIndex: match.index, afterOrdinal: ordinal)

        Button(inserting == location ? "Cancel" : "＋ Add a missed turn") {
            inserting = inserting == location ? nil : location
        }
        .font(.caption)
        .accessibilityIdentifier("add-turn-\(match.index)")

        if inserting == location {
            ForEach(store.state.roster, id: \.id) { player in
                Button("\(text(number: player.number))  \(player.name)") {
                    let accepted = store.dispatch(
                        .insertTurn(
                            gameId: gameId,
                            matchIndex: match.index,
                            afterOrdinal: ordinal,
                            playerId: player.id
                        )
                    )
                    if accepted {
                        inserting = nil
                        // It arrives holding one serve, opened straight away: the serves it
                        // actually held are the reason it is being added at all.
                        openTurn = TurnLocation(matchIndex: match.index, ordinal: ordinal + 1)
                    }
                }
                .accessibilityIdentifier("insert-for-\(player.id)")
            }
        }
    }
}

/// One turn, closed: who served it, what happened, and what it came to.
private struct TurnRow: View {
    let store: Store
    let turn: Turn

    var body: some View {
        HStack(spacing: 8) {
            Text("\(turn.ordinal + 1)")
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color(hex: colorForTurn(turn.ordinal))))
                .foregroundStyle(.black)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.state.rosterEntry(id: turn.playerId)?.name ?? "Removed player")
                    .font(.subheadline)
                Text(turn.serves.map(symbol).joined(separator: " "))
                    .font(.caption.monospaced())
            }
            Spacer()
            Text("\(turn.isOverServeLimit ? "⚠ " : "")\(turn.serves.count) · \(turn.figures.servesIn) in · \(turn.figures.points) pt")
                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private func symbol(_ serve: Serve) -> String {
        switch serve.outcome {
        case .inPoint: "●"
        case .inNoPoint: "○"
        case .out: "✕"
        }
    }
}

/// Where a turn is, so a correction can name it.
struct TurnLocation: Equatable, Hashable {
    var matchIndex: Int
    var ordinal: Int
}

/// The gap a missed turn would be added into.
struct InsertLocation: Equatable, Hashable {
    var matchIndex: Int
    var afterOrdinal: Int
}
