// A game that was never tracked serve by serve — figures copied from a paper sheet.
//
// Serves in and serves out, per player, at game level. Nothing else: nothing else was
// written down, and inventing matches or turns would report play that never happened.
import SwiftUI
import VBCore
import VBPresentation

struct PaperGameScreen: View {
    @Bindable var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var context = GameContext(date: nil, opponent: "", location: "", court: "")
    @State private var notes = GameNotes()
    @State private var result = MatchResult.undecided
    @State private var figures: [String: (servesIn: String, servesOut: String)] = [:]
    @State private var date = Date()

    private var members: [RosterEntry] {
        store.state.members(ofSeason: store.state.activeSeasonId)
    }

    var body: some View {
        Form {
            NoticeBanner(notice: store.notice).listRowInsets(EdgeInsets())

            Section("Who, where, when") {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Opposing team", text: $context.opponent)
                TextField("Location", text: $context.location)
                TextField("Court", text: $context.court)
            }

            Section("Result") {
                Picker("Result", selection: $result) {
                    Text("Won").tag(MatchResult.won)
                    Text("Lost").tag(MatchResult.lost)
                    Text(missingFigure).tag(MatchResult.undecided)
                }
                .pickerStyle(.segmented)
            }

            Section("Serves") {
                if members.isEmpty {
                    Text("Add players to the season first.").foregroundStyle(.secondary)
                }
                ForEach(members, id: \.id) { member in
                    HStack(spacing: 8) {
                        Text(text(number: member.number))
                            .font(.headline.monospacedDigit()).frame(width: 30, alignment: .trailing)
                        Text(member.name).font(.subheadline).lineLimit(1)
                        Spacer()
                        TextField("in", text: binding(for: member.id, \.servesIn))
                            .keyboardType(.numberPad).frame(width: 44).multilineTextAlignment(.trailing)
                        TextField("out", text: binding(for: member.id, \.servesOut))
                            .keyboardType(.numberPad).frame(width: 44).multilineTextAlignment(.trailing)
                    }
                }
                Text("Serves in and out only — that is all the paper had. Points and turns stay dashes for this game.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Notes") {
                TextField("What went well", text: $notes.wentWell, axis: .vertical).lineLimit(2...5)
                TextField("What to work on", text: $notes.needsWork, axis: .vertical).lineLimit(2...5)
                TextField("Anything else", text: $notes.notes, axis: .vertical).lineLimit(2...5)
            }

            Section {
                Button("Add this game", action: add)
                    .disabled(members.isEmpty)
                    .accessibilityIdentifier("add-paper-game")
            }
        }
        .navigationTitle("A game from paper")
    }

    private func binding(
        for playerId: String,
        _ field: WritableKeyPath<(servesIn: String, servesOut: String), String>
    ) -> Binding<String> {
        Binding(
            get: { figures[playerId, default: ("", "")][keyPath: field] },
            set: { figures[playerId, default: ("", "")][keyPath: field] = $0 }
        )
    }

    private func add() {
        var written = context
        written.date = Self.formatter.string(from: date)

        // A blank box is nought serves, not a refusal: a player who did not serve is on the
        // sheet with nothing beside their name.
        let entries = members.map { member -> RawHistoricalEntry in
            let recorded = figures[member.id] ?? ("", "")
            return RawHistoricalEntry(
                playerId: member.id,
                servesIn: Int(recorded.servesIn) ?? 0,
                servesOut: Int(recorded.servesOut) ?? 0
            )
        }

        let accepted = store.dispatch(
            .addHistoricalGame(
                id: UUID().uuidString,
                seasonId: store.state.activeSeasonId,
                context: written,
                entries: entries,
                notes: notes,
                result: .value(result)
            )
        )
        if accepted { dismiss() }
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

/// A batch of games from paper, from a prepared file.
///
/// It ADDS to the season — unlike a backup, which replaces everything. All or nothing: a
/// partial import would leave the operator unable to tell what landed.
struct PaperImportScreen: View {
    @Bindable var store: Store
    @State private var pasted = ""
    @State private var isChoosingFile = false

    var body: some View {
        Form {
            NoticeBanner(notice: store.notice).listRowInsets(EdgeInsets())

            Section("From a file") {
                Button("Choose a file of games") { isChoosingFile = true }
                Text("Games are added to this season; nothing already recorded is replaced.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Or paste them") {
                // Pasting avoids the file system altogether. On iOS, saving a JSON file
                // from Safari lands it as ".json.txt", which is fiddly at best.
                TextField("Open the games file, select all, copy, and paste it here.", text: $pasted, axis: .vertical)
                    .lineLimit(4...10)
                Button("Load these games") { load(pasted) }
                    .disabled(pasted.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Games from paper")
        .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [.item]) { result in
            guard case let .success(url) = result else { return }
            let opened = url.startAccessingSecurityScopedResource()
            defer { if opened { url.stopAccessingSecurityScopedResource() } }
            if let text = try? String(contentsOf: url, encoding: .utf8) { load(text) }
        }
    }

    private func load(_ text: String) {
        let parsed = parsePaperGames(text, season: store.state.activeSeason, members: store.state.roster) {
            UUID().uuidString
        }
        switch parsed {
        case let .refused(reason):
            store.report(failure: reason)
        case let .ready(events):
            for event in events { store.dispatch(event) }
            store.report(success: "Added \(events.count) game\(events.count == 1 ? "" : "s").")
            pasted = ""
        }
    }
}
