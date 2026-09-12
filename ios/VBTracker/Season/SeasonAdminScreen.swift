// Seasons themselves: making one, renaming it, switching to it, and who is on its roster.
//
// The load-bearing idea is that a player is a person who outlives any roster. Adding
// someone to a new season means picking a person the app already knows and giving them the
// number they wear THIS season — which is what makes a career comparable across two teams
// and two numbers.
import SwiftUI
import VBCore
import VBPresentation

struct SeasonAdminScreen: View {
    @Bindable var store: Store

    @State private var name = ""
    @State private var team = ""
    @State private var newSeasonName = ""
    @State private var newSeasonTeam = ""
    @State private var addingPlayerId: String?
    @State private var newNumber = ""
    /// Which season has been asked about once. A second tap is the answer.
    @State private var confirmingDiscard: String?

    private var season: Season? { store.state.activeSeason }

    var body: some View {
        List {
            NoticeBanner(notice: store.notice).listRowInsets(EdgeInsets())

            if let season {
                Section("This season") {
                    TextField("Season name", text: $name)
                    TextField("Team name", text: $team)
                    Button("Save") {
                        store.dispatch(.renameSeason(id: season.id, name: name, team: team))
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Section("Bring a player across") {
                    // Everyone the app knows who is not on this roster. Picking them here
                    // is what keeps a career one person rather than two.
                    let available = store.state.players.filter { player in
                        store.state.number(inSeason: season.id, playerId: player.id) == nil
                    }

                    if available.isEmpty {
                        Text("Everyone you have recorded is already on this roster.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    ForEach(available, id: \.id) { player in
                        if addingPlayerId == player.id {
                            HStack {
                                TextField("Number this season", text: $newNumber)
                                    .keyboardType(.numberPad)
                                Button("Add") {
                                    let accepted = store.dispatch(
                                        .addPlayer(
                                            id: player.id,
                                            name: player.name,
                                            number: newNumber,
                                            seasonId: season.id
                                        )
                                    )
                                    if accepted { addingPlayerId = nil; newNumber = "" }
                                }
                            }
                        } else {
                            Button(player.name) { addingPlayerId = player.id; newNumber = "" }
                        }
                    }

                    Text("A number belongs to the season, never to the person. The same child can wear a different one next year.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                // Getting rid of a season had no control anywhere. A season entered to try
                // the app out could be emptied game by game and player by player and still
                // sit at the top of this screen with nothing that would remove it.
                Section {
                    Button(
                        confirmingDiscard == season.id
                            ? "Discard \"\(season.name)\"?"
                            : "Discard this season",
                        role: .destructive
                    ) {
                        guard confirmingDiscard == season.id else {
                            confirmingDiscard = season.id
                            return
                        }
                        store.dispatch(.discardSeason(id: season.id))
                        confirmingDiscard = nil
                    }
                    .accessibilityIdentifier("discard-season")

                    Text(
                        confirmingDiscard == season.id
                            ? "Tap again to discard. Every game recorded in this season goes with it. The players stay, and so does everything they did in any other season."
                            : "Removes this season and every game in it. The players themselves are kept."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }

                let others = store.state.seasons.filter { $0.id != season.id }
                if !others.isEmpty {
                    Section("Other seasons") {
                        ForEach(others, id: \.id) { other in
                            Button("\(other.name) — \(other.team)") {
                                store.dispatch(.activateSeason(id: other.id))
                            }
                        }
                    }
                }
            }

            Section("Add a season") {
                TextField("Season name", text: $newSeasonName)
                TextField("Team name", text: $newSeasonTeam)
                Button("Create") {
                    let accepted = store.dispatch(
                        .createSeason(
                            id: UUID().uuidString,
                            name: newSeasonName,
                            team: newSeasonTeam,
                            format: .standard
                        )
                    )
                    if accepted { newSeasonName = ""; newSeasonTeam = "" }
                }
                .disabled(newSeasonName.trimmingCharacters(in: .whitespaces).isEmpty)

                Text("A new season starts with an empty roster. Bring players across from the people you have already recorded, so their history follows them.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Seasons")
        .keyboardDismissable()
        .onAppear {
            name = season?.name ?? ""
            team = season?.team ?? ""
        }
    }
}
