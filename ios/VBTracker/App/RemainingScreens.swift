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

    enum Scope: String, CaseIterable { case match, game }

    private var game: Game? { store.state.currentGame }

    var body: some View {
        NavigationStack {
            List {
                if let game {
                    Section {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title(of: game)).font(.headline)
                            Text(subtitle(of: game)).font(.caption).foregroundStyle(.secondary)
                        }
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
        }
    }
}

/// Per-player figures for one match or game.
private struct MatchFigures: View {
    let figures: [String: Figures]
    let roster: [RosterEntry]

    private var ordered: [(entry: RosterEntry, figures: Figures)] {
        roster.compactMap { entry in figures[entry.id].map { (entry, $0) } }
            .sorted { ($0.figures.inPercentage ?? -1) > ($1.figures.inPercentage ?? -1) }
    }

    var body: some View {
        ForEach(ordered, id: \.entry.id) { row in
            HStack(spacing: 8) {
                Text(text(number: row.entry.number))
                    .font(.headline.monospacedDigit()).frame(width: 28, alignment: .trailing)
                Text(row.entry.name).font(.subheadline).lineLimit(1)
                Spacer()
                Text("\(row.figures.servesIn)/\(row.figures.serves)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
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

    var body: some View {
        NavigationStack {
            List {
                NoticeBanner(notice: store.notice).listRowInsets(EdgeInsets())

                Section("Add a player") {
                    TextField("Name", text: $name)
                    TextField("Number", text: $number).keyboardType(.numberPad)
                    Button("Add") {
                        let accepted = store.dispatch(
                            .addPlayer(
                                id: UUID().uuidString,
                                name: name,
                                number: number,
                                seasonId: store.state.activeSeasonId
                            )
                        )
                        if accepted { name = ""; number = "" }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Section("\(store.state.roster.count) of \(maxRoster)") {
                    ForEach(store.state.roster, id: \.id) { player in
                        HStack {
                            Text(text(number: player.number))
                                .font(.headline.monospacedDigit()).frame(width: 34, alignment: .trailing)
                            Text(player.name)
                            Spacer()
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
                        }
                    }
                    // Leaving a squad says nothing about the serves they took last year.
                    Text("Removing a player takes them off this season's roster. Everything they recorded stays theirs.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Roster")
        }
    }
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
