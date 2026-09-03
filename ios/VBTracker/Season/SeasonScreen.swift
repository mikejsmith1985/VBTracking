// The season: how the team did, how each player served, and the admin for seasons
// themselves.
//
// Read between matches rather than during one, so it favours completeness over speed. It is
// also where saving a copy of everything lives — because the record lives here, and because
// it must be reachable when there is no game in progress.
import SwiftUI
import VBCore
import VBPresentation

struct SeasonScreen: View {
    @Bindable var store: Store
    @State private var isImporting = false
    @State private var isHandingOver = false
    @State private var isExporting = false
    @State private var openGameId: String?
    @State private var careerPlayerId: String?
    /// Asked once. A second tap is the answer, and it is the last one.
    @State private var isConfirmingErase = false

    private var season: Season? { store.state.activeSeason }
    private var games: [Game] {
        guard let id = season?.id else { return [] }
        return store.state.games(inSeason: id).sorted {
            ($0.context.date ?? "") < ($1.context.date ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            List {
                NoticeBanner(notice: store.notice).listRowInsets(EdgeInsets())

                if let season {
                    Section {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(season.name).font(.title2.bold())
                            Text("\(season.team) · \(games.count) game\(games.count == 1 ? "" : "s")")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(text(record: record(of: games))).font(.headline).padding(.top, 4)
                        }
                    }

                    Section("Serving — every game this season") {
                        StatsTable(
                            figures: store.state.seasonStatistics(season.id).byPlayer,
                            roster: store.state.members(ofSeason: season.id),
                            coverage: store.state.seasonStatistics(season.id).coverage,
                            onTapPlayer: { careerPlayerId = $0 }
                        )
                    }

                    Section("Games") {
                        ForEach(games, id: \.id) { game in
                            Button { openGameId = game.id } label: { GameRow(game: game) }
                        }
                        if games.isEmpty {
                            Text("No games yet this season.").foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Section {
                        EmptyState(title: "No season yet", detail: "Add a player to start one.")
                    }
                }

                Section("Games from paper") {
                    NavigationLink("Enter a game by hand") { PaperGameScreen(store: store) }
                    NavigationLink("Import a batch from a file") { PaperImportScreen(store: store) }
                    Text("Adds games recorded before the app existed. Serves in and out only — that is all the paper had.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Seasons") {
                    NavigationLink("Seasons and rosters") { SeasonAdminScreen(store: store) }
                }

                // Reachable whether or not a season exists: a new phone holding a backup
                // has no season, and an operator who cannot reach the restore has lost
                // everything they recorded.
                Section("Your data") {
                    Button("Save a copy of everything") { isExporting = true }
                        .accessibilityIdentifier("export-data")
                    Button("Restore from a saved copy") { isImporting = true }
                        .accessibilityIdentifier("import-data")
                    Text("Every season, every game, every serve — as one file you keep. Nothing is sent anywhere.")
                        .font(.caption).foregroundStyle(.secondary)

                    // Separate from saving a copy, because it answers a different question.
                    // A backup is for getting a season back; this is for a coach and an
                    // assistant coach who both need the figures when only one of them is
                    // tracking. What arrives is merged, so neither phone loses its roster.
                    Button("Send this season to another phone") { isHandingOver = true }
                        .accessibilityIdentifier("hand-over")
                    Text("Sends it over AirDrop. The other phone keeps what it already has and adds what it does not.")
                        .font(.caption).foregroundStyle(.secondary)

                    // The way back to an empty app. Without it, data put in to try the app
                    // out -- or a backup restored to see what it looked like -- could only
                    // be taken out one season, one game, one player at a time.
                    Button(
                        isConfirmingErase ? "Erase everything?" : "Erase everything",
                        role: .destructive
                    ) {
                        guard isConfirmingErase else { isConfirmingErase = true; return }
                        store.eraseEverything()
                        isConfirmingErase = false
                    }
                    .accessibilityIdentifier("erase-everything")

                    Text(
                        isConfirmingErase
                            ? "Tap again to erase. Every season, game, serve and player is thrown away and cannot be recovered — save a copy first if you might want it back."
                            : "Returns the app to how it was on the day it was installed. Save a copy first."
                    )
                    .font(.caption).foregroundStyle(isConfirmingErase ? Color.red : Color.secondary)
                }

                // Last, quietly, on a screen read between matches. It never comes to the
                // operator; the operator has to come to it.
                Section {
                    NavigationLink("About this app") { AboutScreen() }
                        .accessibilityIdentifier("about")
                }
            }
            .navigationTitle("Season")
            .navigationDestination(item: $openGameId) { id in
                GameFormScreen(store: store, gameId: id)
            }
            .navigationDestination(item: $careerPlayerId) { id in
                CareerScreen(store: store, playerId: id)
            }
            .sheet(isPresented: $isExporting) { ExportSheet(store: store, isPresented: $isExporting) }
            .sheet(isPresented: $isHandingOver) { HandoverSheet(store: store) }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.item]) { result in
                // No file-type filter at all: iOS saves a JSON file from Safari as
                // ".json.txt", and a filter greys out the file the phone just wrote. The
                // parser refuses anything that is not ours, with a plain reason.
                guard case let .success(url) = result else { return }
                let opened = url.startAccessingSecurityScopedResource()
                defer { if opened { url.stopAccessingSecurityScopedResource() } }
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    store.restore(from: text)
                }
            }
        }
    }
}

/// One game in the list: when, who, how it went, and how the serving was.
private struct GameRow: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title(of: game)).font(.headline)
                Spacer()
                Text(text(result: game.result))
                    .font(.caption.bold())
                    .foregroundStyle(game.result == .won ? Color.green : (game.result == .lost ? Color.red : Color.secondary))
            }
            HStack(spacing: 8) {
                Text(subtitle(of: game)).font(.caption).foregroundStyle(.secondary)
                Text("\(game.summary.servesIn)/\(game.summary.serves) in")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                if game.kind == .historical {
                    Text("from paper").font(.caption2)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(.quaternary))
                }
            }
        }
    }
}

/// A player's whole career: each season separately, and everything combined.
struct CareerScreen: View {
    let store: Store
    let playerId: String

    var body: some View {
        List {
            ForEach(store.state.career(of: playerId).seasons, id: \.seasonId) { season in
                Section("\(season.name) · \(season.team)") {
                    LabeledContent("Number", value: text(number: season.number))
                    LabeledContent("Games", value: "\(season.games)")
                    LabeledContent("Record", value: text(record: season.record))
                    if let figures = season.figures {
                        LabeledContent("Serves", value: "\(figures.servesIn)/\(figures.serves)")
                        LabeledContent("In", value: text(percentage: figures.inPercentage))
                        LabeledContent("Points", value: text(count: figures.points))
                    }
                }
            }
        }
        .navigationTitle(store.state.player(id: playerId)?.name ?? "Player")
    }
}

/// Per-player figures. A figure never recorded is a dash — never a zero.
struct StatsTable: View {
    let figures: [String: CareerFigures]
    let roster: [RosterEntry]
    var coverage: Coverage?
    var onTapPlayer: ((String) -> Void)?

    /// Ordered by how much of their serving landed in.
    ///
    /// Not by points: someone who scored ten from a hundred serves should not stand above
    /// someone who scored six from ten.
    private var ordered: [(entry: RosterEntry, figures: CareerFigures)] {
        roster.compactMap { entry in
            figures[entry.id].map { (entry, $0) }
        }
        .sorted { ($0.figures.inPercentage ?? -1) > ($1.figures.inPercentage ?? -1) }
    }

    /// True when at least one player has a time-on-court figure to show.
    ///
    /// Without a lineup the column would be a row of dashes pretending to mean something,
    /// which is the same rule the web app has always followed.
    private var showsCourt: Bool {
        ordered.contains { $0.figures.turnsOnCourt != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header

            ForEach(ordered, id: \.entry.id) { row in
                Button {
                    onTapPlayer?(row.entry.id)
                } label: {
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
                        Text(text(count: row.figures.points))
                            .font(.caption.monospacedDigit()).frame(width: 26, alignment: .trailing)
                        Text(text(count: row.figures.turnsTaken))
                            .font(.caption.monospacedDigit()).frame(width: 26, alignment: .trailing)
                            .foregroundStyle(.secondary)
                        if showsCourt {
                            Text(text(count: row.figures.turnsOnCourt))
                                .font(.caption.monospacedDigit()).frame(width: 30, alignment: .trailing)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(onTapPlayer == nil)
            }

            note
        }
    }

    /// What each column is. Without it the reader is left to work out whether 19/22 is
    /// serves in out of serves, or something else entirely.
    private var header: some View {
        HStack(spacing: 8) {
            Text("").frame(width: 28)
            Text("Player")
            Spacer()
            Text("In / served").frame(width: 52, alignment: .trailing)
            Text("In %").frame(width: 44, alignment: .trailing)
            Text(pointsHeading(coverage: coverage)).frame(width: 26, alignment: .trailing)
            // How many turns they served, and how many they stood on court for. The second
            // is what turns "she served twice" into "she served twice in nine".
            Text("Turns").frame(width: 26, alignment: .trailing)
            if showsCourt {
                Text("Court").frame(width: 30, alignment: .trailing)
            }
        }
        .font(.caption2.weight(.semibold))
        .textCase(.uppercase)
        .foregroundStyle(.tertiary)
    }

    @ViewBuilder private var note: some View {
        if let note = coverageNote(coverage) {
            Text(note).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
