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
    @State private var paperRows: [PaperRow] = []
    /// Which field is being typed in, so leaving one is a moment to save.
    @FocusState private var isTyping: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var isConfirmingDiscard = false
    @State private var isShowingRecord = false
    @State private var scope = Scope.game

    /// Whether the figures cover the whole game or are broken out match by match.
    private enum Scope: String, CaseIterable { case game, match }
    @Environment(\.dismiss) private var dismiss

    private var game: Game? { store.state.game(id: gameId) }

    /// Who was on the roster for the season this game belongs to.
    ///
    /// Not today's roster: a player who left the squad still served the serves they served,
    /// and reading a past game against the present roster would drop them from its figures.
    private func seasonRoster(of game: Game) -> [RosterEntry] {
        let members = store.state.members(ofSeason: game.seasonId)
        return members.isEmpty ? store.state.roster : members
    }

    var body: some View {
        Form {
            if let game {
                if game.kind == .tracked {
                    Section {
                        // Named for what it opens, not for what it counts. As
                        // "Serve record — 47/62 in" it read as a statistic somebody had
                        // put on a row, and the one way into the serve-by-serve history went
                        // unfound.
                        Button {
                            isShowingRecord = true
                        } label: {
                            Label("Serve record — every turn", systemImage: "list.bullet.rectangle")
                        }
                        .accessibilityIdentifier("open-record")
                        Text("\(game.summary.servesIn) of \(game.summary.serves) serves in. Tap to see every turn and correct anything mis-entered.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if game.kind == .tracked, !game.matches.isEmpty {
                    // The figures, on the screen somebody opens when they tap a game. They
                    // were only ever shown for the game being tracked right now, so a game
                    // from three weeks ago could be corrected serve by serve without ever
                    // showing what those serves came to.
                    Section {
                        Picker("Scope", selection: $scope) {
                            Text("Game").tag(Scope.game)
                            Text("Match").tag(Scope.match)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("figures-scope")
                    }

                    if scope == .game {
                        Section("Game totals") {
                            MatchFigures(figures: game.statistics, roster: seasonRoster(of: game))
                        }
                    } else {
                        ForEach(game.matches, id: \.index) { match in
                            Section("Match \(match.index + 1) · \(match.score) pts") {
                                MatchFigures(figures: match.statistics, roster: seasonRoster(of: game))
                            }
                        }
                    }
                }

                Section("Who, where, when") {
                    // One field per row. iOS gives a date field a minimum width of its own
                    // and overflows whatever column it is given.
                    DatePicker("Date", selection: dateBinding, displayedComponents: .date)
                    TextField("Opposing team", text: $context.opponent).focused($isTyping)
                    TextField("Location", text: $context.location).focused($isTyping)
                    TextField("Court", text: $context.court).focused($isTyping)
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
                        PaperFigures(rows: $paperRows, onCommit: savePaper)
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
        .keyboardDismissable()
        .navigationDestination(isPresented: $isShowingRecord) {
            ServeRecordScreen(store: store, gameId: gameId)
        }
        .onAppear(perform: load)
        // Three moments, because any one of them alone loses work. Leaving a field covers
        // typing and then tapping elsewhere on the screen; the scene leaving the foreground
        // covers the home gesture and the app switcher; and `onDisappear` covers Back. It
        // used to be the last of those on its own, and `onDisappear` does not reliably fire
        // when the operator switches tabs -- so a correction left by any route but one was
        // thrown away without a word.
        .onChange(of: isTyping) { _, nowTyping in if !nowTyping { save() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { save() } }
        .onDisappear(perform: save)
    }

    /// Reads the record into the fields.
    private func load() {
        context = game?.context ?? GameContext()
        notes = game?.notes ?? GameNotes()
        paperRows = game.map { game in
            PaperSheet.rows(roster: seasonRoster(of: game), entries: game.entries)
        } ?? []
    }

    /// Saves whatever has changed.
    ///
    /// Called when a field is finished with, and again on the way out. It used to be called
    /// ONLY on the way out, and `onDisappear` does not reliably fire when the operator
    /// switches tabs rather than tapping Back -- so a correction typed and then left by any
    /// route but one was silently thrown away.
    ///
    /// Every field here corrects a record of something that already happened, so there is
    /// nothing to confirm and no Save button to forget. Saving twice costs nothing: each
    /// dispatch is guarded by whether the value actually moved.
    private func save() {
        guard let game else { return }
        if context != game.context { store.dispatch(.setGameContext(gameId: gameId, context: context)) }
        if notes != game.notes { store.dispatch(.setGameNotes(gameId: gameId, notes: notes)) }
        savePaper()
    }

    /// Sends a corrected paper sheet, if it says anything the record does not.
    ///
    /// A game from paper carries its figures on the game itself rather than in turns, so
    /// correcting one means resending the whole sheet -- context, notes and result with it,
    /// which is what `editHistoricalGame` takes. Half-typed rows are left out by
    /// `PaperSheet`, so a row abandoned mid-thought cannot become a nought.
    private func savePaper() {
        guard let game, game.kind == .historical else { return }
        guard PaperSheet.hasChanges(paperRows, against: game.entries) else { return }

        store.dispatch(
            .editHistoricalGame(
                id: gameId,
                context: context,
                entries: PaperSheet.entries(from: paperRows),
                notes: notes,
                result: .value(game.recordedResult)
            )
        )
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
    @Binding var rows: [PaperRow]
    let onCommit: () -> Void

    var body: some View {
        ForEach($rows) { $row in
            HStack(spacing: 8) {
                Text(text(number: row.number)).font(.headline.monospacedDigit()).frame(width: 30)
                Text(row.name).font(.subheadline).lineLimit(1)
                Spacer(minLength: 4)
                CountField("in", value: $row.servesIn, onCommit: onCommit)
                CountField("out", value: $row.servesOut, onCommit: onCommit)
            }
        }
        Text("Type over a figure to correct it. A player with nothing written down for them shows a dash, not a zero — fill in both boxes to add them.")
            .font(.caption).foregroundStyle(.secondary)
    }
}

/// One serve count, which is a number or is genuinely nothing.
///
/// Bound to `Int?` rather than to a string with a nought in it: an empty box means the sheet
/// said nothing about this player, and turning that into `0` on the way in would claim they
/// served and missed serves they never took.
private struct CountField: View {
    let label: String
    @Binding var value: Int?
    let onCommit: () -> Void

    @FocusState private var isFocused: Bool

    init(_ label: String, value: Binding<Int?>, onCommit: @escaping () -> Void) {
        self.label = label
        self._value = value
        self.onCommit = onCommit
    }

    var body: some View {
        HStack(spacing: 3) {
            TextField(missingFigure, value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(width: 38)
                .accessibilityIdentifier("paper-\(label)")
                // Saved when the field is finished with, not only when the screen goes away.
                .focused($isFocused)
                .onSubmit(onCommit)
                .onChange(of: isFocused) { _, nowFocused in if !nowFocused { onCommit() } }
            Text(label).font(.caption2).foregroundStyle(.secondary).frame(width: 22, alignment: .leading)
        }
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
