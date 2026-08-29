// A game's record outside a rally: who was played, where, how it went, the notes — and,
// for a game copied from paper, the figures themselves.
//
// None of it is touched mid-match. It is the same activity, done at the same time, with the
// same care.
import SwiftUI
import VBCore
import VBPresentation

struct GameFormScreen: View {
    let store: Store
    let gameId: String

    @State private var context = GameContext()
    @State private var notes = GameNotes()
    @State private var isConfirmingDiscard = false
    @State private var isShowingRecord = false
    @Environment(\.dismiss) private var dismiss

    private var game: Game? { store.state.game(id: gameId) }

    var body: some View {
        Form {
            if let game {
                if game.kind == .tracked {
                    Section {
                        Button("Serve record — \(game.summary.servesIn)/\(game.summary.serves) in") {
                            isShowingRecord = true
                        }
                        .accessibilityIdentifier("open-record")
                        Text("See every turn, and correct anything mis-entered.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Who, where, when") {
                    // One field per row. iOS gives a date field a minimum width of its own
                    // and overflows whatever column it is given.
                    DatePicker("Date", selection: dateBinding, displayedComponents: .date)
                    TextField("Opposing team", text: $context.opponent)
                    TextField("Location", text: $context.location)
                    TextField("Court", text: $context.court)
                }

                if game.kind == .tracked {
                    Section("Results") {
                        ForEach(game.matches, id: \.index) { match in
                            Picker("Match \(match.index + 1)", selection: resultBinding(match)) {
                                Text("Won").tag(MatchResult.won)
                                Text("Lost").tag(MatchResult.lost)
                                Text(missingFigure).tag(MatchResult.undecided)
                            }
                            .pickerStyle(.segmented)
                        }
                        Text("The game is won when more matches were won than lost. A match left unrecorded counts toward neither.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Section("Serves — copied from paper") {
                        PaperFigures(store: store, game: game)
                    }
                }

                Section("Notes") {
                    LabelledBox("What went well", text: $notes.wentWell)
                    LabelledBox("What to work on", text: $notes.needsWork)
                    LabelledBox("Anything else", text: $notes.notes)
                }

                Section {
                    Button(isConfirmingDiscard ? "Discard this game?" : "Discard this game", role: .destructive) {
                        guard isConfirmingDiscard else { isConfirmingDiscard = true; return }
                        store.dispatch(.discardGame(id: gameId))
                        dismiss()
                    }
                    Text(
                        isConfirmingDiscard
                            ? "Tap again to discard. Everything recorded in this game is thrown away. The roster and the rest of the season are untouched."
                            : "Removes this game and its figures from the season. Use it if the same game was entered twice."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("That game no longer exists.")
            }
        }
        .navigationTitle(game.map(title(of:)) ?? "Game")
        .navigationDestination(isPresented: $isShowingRecord) {
            ServeRecordScreen(store: store, gameId: gameId)
        }
        .onAppear {
            context = game?.context ?? GameContext()
            notes = game?.notes ?? GameNotes()
        }
        .onDisappear(perform: save)
    }

    /// Saves on the way out rather than behind a button.
    ///
    /// Every field here is a correction to a record of something that already happened, so
    /// there is nothing to confirm — and a Save button is one more thing to forget.
    private func save() {
        guard let game else { return }
        if context != game.context { store.dispatch(.setGameContext(gameId: gameId, context: context)) }
        if notes != game.notes { store.dispatch(.setGameNotes(gameId: gameId, notes: notes)) }
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { context.date.flatMap(Self.formatter.date(from:)) ?? Date() },
            set: { context.date = Self.formatter.string(from: $0) }
        )
    }

    private func resultBinding(_ match: Match) -> Binding<MatchResult> {
        Binding(
            get: { match.result },
            set: { store.dispatch(.setMatchResult(gameId: gameId, matchIndex: match.index, result: .value($0))) }
        )
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

/// Serves in and out, per player. Nothing else: nothing else was written down.
private struct PaperFigures: View {
    let store: Store
    let game: Game

    var body: some View {
        ForEach(store.state.members(ofSeason: game.seasonId), id: \.id) { member in
            let entry = game.entries.first { $0.playerId == member.id }
            HStack {
                Text(text(number: member.number)).font(.headline.monospacedDigit()).frame(width: 30)
                Text(member.name).font(.subheadline)
                Spacer()
                Text("\(entry?.servesIn ?? 0) in").font(.caption.monospacedDigit())
                Text("\(entry?.servesOut ?? 0) out").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        Text("Points, turns and time on court were never written down for this game, so they show as dashes rather than as zero.")
            .font(.caption).foregroundStyle(.secondary)
    }
}

/// A note box with its heading.
///
/// Three boxes rather than one: every paper sheet keeps "what went well" and "what to work
/// on" as separate lists, and typing those headings every game is work the app should do.
private struct LabelledBox: View {
    let label: String
    @Binding var text: String

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).textCase(.uppercase).foregroundStyle(.secondary)
            TextEditor(text: $text).frame(minHeight: 70)
        }
    }
}
