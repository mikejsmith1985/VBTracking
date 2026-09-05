// The two screens with the least in them, and the one sheet.
//
// The Game tab shows whichever game was picked on the Season screen, falling back to the
// one being tracked — before that it only ever showed the live game, which left every
// finished game with no figures to look at at all.
import SwiftUI
import UniformTypeIdentifiers
import VBCore
import VBPresentation

/// The figures for one game: the whole game, or match by match.
struct GameScreen: View {
    @Bindable var store: Store
    @State private var scope = Scope.match
    /// Which game is being looked at, or nil for whichever is being tracked right now.
    @State private var chosenGameId: String?
    @State private var isEditing = false

    enum Scope: String, CaseIterable { case match, game }

    /// Every game this season, newest first, because a game just finished is the one most
    /// likely to be wanted.
    private var games: [Game] {
        guard let seasonId = store.state.activeSeasonId else { return [] }
        return store.state.games(inSeason: seasonId)
            .sorted { ($0.context.date ?? "") > ($1.context.date ?? "") }
    }

    /// The game on screen: the one chosen, else the one being tracked, else the newest.
    ///
    /// The tab used to show `currentGame` and nothing else, so the moment a game ended there
    /// was no way to look at its figures from here at all -- the whole tab went empty.
    private var game: Game? {
        if let chosenGameId, let chosen = store.state.game(id: chosenGameId) { return chosen }
        return store.state.currentGame ?? games.first
    }

    var body: some View {
        NavigationStack {
            List {
                if let game {
                    Section {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title(of: game)).font(.headline)
                            Text(subtitle(of: game)).font(.caption).foregroundStyle(.secondary)
                        }

                        // The way to a game that is not the live one, and the way to correct
                        // whichever is on screen. Both were only ever reachable from the
                        // Season tab, which is not where somebody looking at a game's
                        // figures thinks to go.
                        if games.count > 1 {
                            Picker("Game", selection: chosenBinding) {
                                ForEach(games, id: \.id) { each in
                                    Text(title(of: each)).tag(each.id)
                                }
                            }
                            .accessibilityIdentifier("choose-game")
                        }

                        Button {
                            isEditing = true
                        } label: {
                            Label("Edit this game", systemImage: "square.and.pencil")
                        }
                        .accessibilityIdentifier("edit-game")
                    }

                    if game.kind == .historical {
                        Section("Serves — copied from paper") {
                            StatsTable(
                                figures: aggregate([game]).byPlayer,
                                roster: store.state.members(ofSeason: game.seasonId)
                            )
                            Text("Points, turns and time on court were never written down for this game.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Picker("Scope", selection: $scope) {
                            Text("Match").tag(Scope.match)
                            Text("Game").tag(Scope.game)
                        }
                        .pickerStyle(.segmented)

                        if scope == .game {
                            Section("Game totals") {
                                MatchFigures(figures: game.statistics, roster: store.state.roster)
                            }
                        } else {
                            ForEach(game.matches, id: \.index) { match in
                                Section("Match \(match.index + 1) · \(match.score) pts") {
                                    MatchFigures(figures: match.statistics, roster: store.state.roster)
                                    Substitutions(match: match, store: store)
                                }
                            }
                        }
                    }
                } else {
                    EmptyState(title: "Nothing to show yet", detail: "Start a game to record serves.")
                }
            }
            .navigationTitle("Game")
            .navigationDestination(isPresented: $isEditing) {
                if let game {
                    GameFormScreen(store: store, gameId: game.id)
                }
            }
        }
    }

    /// The chosen game, defaulting to whatever is on screen so the picker never shows blank.
    private var chosenBinding: Binding<String> {
        Binding(
            get: { chosenGameId ?? game?.id ?? "" },
            set: { chosenGameId = $0 }
        )
    }
}

/// Per-player figures for one match or game.
/// Per-player figures for one match or one whole game.
///
/// Not private: the same table is wanted on a past game opened from the season, and a
/// second copy of it would be a second place for a column to drift.
struct MatchFigures: View {
    let figures: [String: Figures]
    let roster: [RosterEntry]

    private var ordered: [(entry: RosterEntry, figures: Figures)] {
        roster.compactMap { entry in figures[entry.id].map { (entry, $0) } }
            .sorted { ($0.figures.inPercentage ?? -1) > ($1.figures.inPercentage ?? -1) }
    }

    var body: some View {
        if !ordered.isEmpty {
            // Every figure here comes from one tracked game, so no column needs a caveat --
            // but they still need naming.
            HStack(spacing: 8) {
                Text("").frame(width: 28)
                Text("Player")
                Spacer()
                Text("In / served").frame(width: 52, alignment: .trailing)
                Text("In %").frame(width: 44, alignment: .trailing)
                Text("Pts").frame(width: 26, alignment: .trailing)
            }
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(.tertiary)
        }

        ForEach(ordered, id: \.entry.id) { row in
            HStack(spacing: 8) {
                Text(text(number: row.entry.number))
                    .font(.headline.monospacedDigit()).frame(width: 28, alignment: .trailing)
                Text(row.entry.name).font(.subheadline).lineLimit(1)
                Spacer()
                Text("\(row.figures.servesIn)/\(row.figures.serves)")
                    .font(.caption.monospacedDigit()).frame(width: 52, alignment: .trailing)
                    .foregroundStyle(.secondary)
                Text(text(percentage: row.figures.inPercentage))
                    .font(.caption.monospacedDigit()).frame(width: 44, alignment: .trailing)
                Text("\(row.figures.points)")
                    .font(.caption.monospacedDigit()).frame(width: 26, alignment: .trailing)
            }
        }
        if ordered.isEmpty {
            Text("No serves recorded yet.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Who came off, who came on, and at what point — one line each, in the order made.
private struct Substitutions: View {
    let match: Match
    let store: Store

    var body: some View {
        if !match.substitutions.isEmpty {
            ForEach(Array(match.substitutions.enumerated()), id: \.offset) { _, substitution in
                HStack(spacing: 6) {
                    Text("\(substitution.position + 1)").font(.caption2.bold()).foregroundStyle(.secondary)
                    Text(store.state.rosterEntry(id: substitution.outPlayerId)?.name ?? "—")
                    Text("→")
                    Text(store.state.rosterEntry(id: substitution.inPlayerId)?.name ?? "—")
                    Spacer()
                    Text(
                        substitution.afterTurnOrdinal < 0
                            ? "before play"
                            : "after turn \(substitution.afterTurnOrdinal + 1)"
                    )
                    .font(.caption2).foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
    }
}

/// The roster: who is on this season's squad, and the number they wear this season.
struct RosterScreen: View {
    @Bindable var store: Store
    @State private var name = ""
    @State private var number = ""
    @State private var confirmingRemoval: String?
    @State private var editing: PlayerEdit?

    /// Which of the two fields is being typed into, so Return can move between them.
    ///
    /// The number pad has no Return of its own, which is why the field order matters: the
    /// name is typed first and hands over, and the number is the one the Done button and a
    /// successful Add both close.
    @FocusState private var focus: Field?
    private enum Field { case name, number }

    var body: some View {
        NavigationStack {
            List {
                NoticeBanner(notice: store.notice).listRowInsets(EdgeInsets())

                Section("Add a player") {
                    TextField("Name", text: $name)
                        .focused($focus, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focus = .number }
                    TextField("Number", text: $number)
                        .keyboardType(.numberPad)
                        .focused($focus, equals: .number)
                    Button("Add") {
                        let accepted = store.dispatch(
                            .addPlayer(
                                id: UUID().uuidString,
                                name: name,
                                number: number,
                                seasonId: store.state.activeSeasonId
                            )
                        )
                        // The keyboard goes with the player. Leaving it up over the tab
                        // bar after a successful Add is what trapped an operator on this
                        // screen, and no button they could reach was the way out.
                        if accepted { name = ""; number = ""; focus = nil }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("add-player")
                }

                Section("\(store.state.roster.count) of \(maxRoster)") {
                    ForEach(store.state.roster, id: \.id) { player in
                        HStack {
                            // The row is the way in to correcting it. A name typed wrong at
                            // the first game was, until now, only fixable by removing the
                            // player -- which takes their career with them.
                            Button {
                                editing = PlayerEdit(id: player.id)
                                confirmingRemoval = nil
                            } label: {
                                HStack {
                                    Text(text(number: player.number))
                                        .font(.headline.monospacedDigit()).frame(width: 34, alignment: .trailing)
                                    Text(player.name)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("edit-player-\(player.id)")
                            .accessibilityHint("Change this player's name or number")

                            Button(confirmingRemoval == player.id ? "Remove?" : "Remove", role: .destructive) {
                                guard confirmingRemoval == player.id else {
                                    confirmingRemoval = player.id
                                    return
                                }
                                store.dispatch(
                                    .removeFromSeason(playerId: player.id, seasonId: store.state.activeSeasonId)
                                )
                                confirmingRemoval = nil
                            }
                            .font(.caption)
                            .buttonStyle(.plain)
                        }
                    }
                    // Leaving a squad says nothing about the serves they took last year.
                    Text("Tap a player to fix their name or number. Removing one takes them off this season's roster — everything they recorded stays theirs.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Roster")
            .keyboardDismissable()
            .sheet(item: $editing) { edit in
                PlayerEditor(store: store, playerId: edit.id, editing: $editing)
            }
        }
    }
}

/// Correcting a player's name or the number on their shirt.
///
/// One screen, because they are one correction: a name spelled wrong and a number read wrong
/// happen at the same moment, on the first night, from the same sheet of paper.
///
/// The number belongs to the season membership and the name belongs to the player, so this
/// changes two different things at once — which is exactly why it is worth doing here rather
/// than making the operator find two screens.
struct PlayerEditor: View {
    let store: Store
    let playerId: String
    @Binding var editing: PlayerEdit?

    @State private var name = ""
    @State private var number = ""

    private var player: RosterEntry? {
        store.state.rosterEntry(id: playerId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("edit-name")
                }

                Section("Number this season") {
                    TextField("Number", text: $number)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("edit-number")
                }

                Section {
                    // The one thing about this app that cannot be retrofitted, said plainly
                    // where somebody is about to change a number.
                    Text("A number belongs to the season, not to the player. Changing it here does not touch what they wore in any other season.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(player?.name ?? "Player")
            .keyboardDismissable()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editing = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let accepted = store.dispatch(
                            .editPlayer(
                                id: playerId,
                                name: name,
                                number: number,
                                seasonId: store.state.activeSeasonId
                            )
                        )
                        if accepted { editing = nil }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("save-player")
                }
            }
            .onAppear {
                name = player?.name ?? ""
                number = player?.number ?? ""
            }
        }
    }
}

/// A player being corrected.
///
/// A wrapper rather than binding the sheet to the identifier itself: `sheet(item:)` wants
/// something `Identifiable`, and making every `String` in the app identifiable to satisfy one
/// sheet is a conformance the whole target would then be living with.
struct PlayerEdit: Identifiable {
    let id: String
}

/// Saving a copy of everything, through the share sheet.
///
/// A backup is the only copy of a season that survives a lost phone, so it is offered the
/// way the phone offers anything worth keeping — and never behind a game.
struct ExportSheet: View {
    let store: Store
    @Binding var isPresented: Bool

    var body: some View {
        let text = store.exportedBackup()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(store.backupFilename())

        ShareLink(item: written(text, to: url)) {
            Label("Save a copy of everything", systemImage: "square.and.arrow.up")
        }
        .presentationDetents([.medium])
        .accessibilityIdentifier("share-backup")
    }

    private func written(_ text: String, to url: URL) -> URL {
        try? text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

/// Handing this season to another phone, through the share sheet.
///
/// The same bytes a backup holds, under an extension the app owns, so AirDrop offers the
/// app by name on the other phone instead of dropping the file into Files for somebody to
/// go and find. A backup keeps `.json` because the web app reads those.
struct HandoverSheet: View {
    let store: Store

    var body: some View {
        let text = store.exportedBackup()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(store.handoverFilename())

        ShareLink(item: written(text, to: url)) {
            Label("Send this season", systemImage: "person.2.badge.gearshape")
        }
        .presentationDetents([.medium])
        .accessibilityIdentifier("share-season")
    }

    private func written(_ text: String, to url: URL) -> URL {
        try? text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
