// Putting somebody back on the roster, with the career they already have.
//
// Typing a returning player's name into "Add a player" makes a second person who happens to
// share a name, with an empty record -- so a girl who left in October and came back in
// November had two histories and neither was hers.
//
// This offers the people the app already knows. Adding one of them attaches this season's
// membership to the person who served every one of those serves.
import SwiftUI
import VBCore
import VBPresentation

struct ReturningPlayerSheet: View {
    let store: Store
    @Binding var isPresented: Bool

    /// The number being given for this season, keyed by player. A number belongs to the
    /// season being joined, so the one they last wore is a starting point and nothing more.
    @State private var numbers: [String: String] = [:]

    private var candidates: [ReturningPlayer] { playersWhoCouldReturn(to: store.state) }

    var body: some View {
        NavigationStack {
            List {
                if candidates.isEmpty {
                    Section {
                        Text("Everybody this app knows is already on this season's roster.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                } else {
                    Section("Played before") {
                        ForEach(candidates) { player in
                            row(player)
                        }
                    }
                    Section {
                        Text("Their serves, their percentages and their career come with them. The number is this season's, so change it if somebody else has it now.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Bring a player back")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }

    private func row(_ player: ReturningPlayer) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(player.name).font(.body)
                if let history = player.history {
                    Text(history).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)

            TextField("No.", text: binding(for: player))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 52)
                .font(.headline.monospacedDigit())

            Button("Add") { bringBack(player) }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(.cyan)
                .accessibilityIdentifier("bring-back-\(player.id)")
        }
    }

    /// The number field for one player, starting at whatever they last wore.
    private func binding(for player: ReturningPlayer) -> Binding<String> {
        Binding(
            get: { numbers[player.id] ?? player.lastNumber ?? "" },
            set: { numbers[player.id] = $0 }
        )
    }

    /// Adds this season's membership to the person who already exists.
    ///
    /// The same event as adding anybody: it makes no second person when the id is one the
    /// app already holds, and the rulebook refuses a duplicate membership or a full roster.
    private func bringBack(_ player: ReturningPlayer) {
        let number = numbers[player.id] ?? player.lastNumber ?? ""
        let accepted = store.dispatch(
            .addPlayer(
                id: player.id,
                name: player.name,
                number: number,
                seasonId: store.state.activeSeasonId
            )
        )
        // Closed on the last one, because a sheet left open over an empty list is a sheet
        // somebody has to work out how to dismiss.
        if accepted, playersWhoCouldReturn(to: store.state).isEmpty { isPresented = false }
    }
}
