// The screen the operator uses for the whole match.
//
// Everything here answers one question: how few taps, and how little looking away from the
// court, does one serve cost? With an order set the answer is one — the rotation hands the
// serve on, so the outcome controls stay under the thumb through a side-out.
import SwiftUI
import VBCore
import VBPresentation

struct TrackScreen: View {
    @Bindable var store: Store

    /// The operator asked to change server mid-turn. Their override, nothing else's.
    @State private var isPickerRequested = false

    /// What the operator has picked up: a player waiting for a spot, or a spot waiting for
    /// a player. Both directions arrange the rotation, because before a match people think
    /// in both.
    @State private var armed: Armed?

    @State private var alert: ServeLimitAlert?
    @State private var isEndingMatch = false
    @State private var isChoosingLineup = false
    @State private var isNamingGame = false

    private var dock: DockState {
        DockState(state: store.state, isPickerRequested: isPickerRequested, canUndo: store.canUndo)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                NoticeBanner(notice: store.notice)

                if store.state.roster.isEmpty {
                    EmptyState(
                        title: "No players yet",
                        detail: "Add your team before the first serve."
                    )
                } else if store.state.currentMatch == nil {
                    // Starting a game opens nothing. The whistle is the one moment the
                    // app must not put a sheet in front of anybody -- naming waits on the
                    // header, where it can be done between rallies or afterwards.
                    BetweenGames(store: store)
                } else {
                    MatchHeader(store: store, isEndingMatch: $isEndingMatch, isNamingGame: $isNamingGame)
                    ScrollView { TallyBoard(match: store.state.currentMatch, roster: store.state.roster) }
                    Dock(
                        store: store,
                        dock: dock,
                        armed: $armed,
                        isPickerRequested: $isPickerRequested,
                        isChoosingLineup: $isChoosingLineup,
                        onServe: record
                    )
                }
            }

            if let alert {
                ServeLimitOverlay(alert: alert, roster: store.state.roster) {
                    self.alert = nil
                }
            }
        }
        .keyboardDismissable()
        .sheet(isPresented: $isNamingGame) { GameNameSheet(store: store, isPresented: $isNamingGame) }
        .sheet(isPresented: $isEndingMatch) { EndMatchSheet(store: store, isPresented: $isEndingMatch) }
        .sheet(isPresented: $isChoosingLineup) { LineupSheet(store: store, isPresented: $isChoosingLineup) }
    }

    /// Records one serve, and raises the five-serve alert when it is the fifth.
    private func record(_ outcome: Outcome) {
        let serving = store.state.activeServerId
        guard store.dispatch(.recordServe(outcome: outcome)) else { return }
        alert = ServeLimitAlert.raised(after: store.state, servingPlayerId: serving)
    }
}

/// The match, its score on serve, and the way out of it.
private struct MatchHeader: View {
    let store: Store
    @Binding var isEndingMatch: Bool
    @Binding var isNamingGame: Bool

    private var opponent: String? {
        let name = store.state.currentGame?.context.opponent.trimmingCharacters(in: .whitespaces)
        return (name?.isEmpty == false) ? name : nil
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                // Who they are playing, said here rather than only on a screen reached
                // three taps away. A game that could not be named until afterwards is a
                // game that ends up called "Unnamed opponent" in the season list.
                Button {
                    isNamingGame = true
                } label: {
                    // Always drawn as a control, whether or not it holds a name. As a bare
                    // caption it read as a label, and an operator looking for somewhere to
                    // type the opponent in went looking on other screens instead.
                    HStack(spacing: 4) {
                        Image(systemName: "pencil").font(.caption2)
                        Text(opponent ?? "Name this game").font(.caption.bold())
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(opponent == nil ? Color.cyan : Color.secondary)
                .accessibilityIdentifier("name-game")

                Text("Match \((store.state.currentMatch?.index ?? 0) + 1) of \(matchesPerGame)")
                    .font(.caption).textCase(.uppercase).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(store.state.currentMatch?.score ?? 0)").font(.largeTitle.bold())
                    Text("points on serve").font(.caption).foregroundStyle(.secondary)
                }
                if store.state.currentMatch?.hasReachedTarget() == true {
                    Text("\(targetScore) reached — win by 2")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            Button("End match") { isEndingMatch = true }
                .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

/// Between games: what was recorded, and the way into the next one.
private struct BetweenGames: View {
    let store: Store

    /// Who they are playing, typed before the whistle rather than only after it.
    @State private var opponent = ""
    @FocusState private var isNaming: Bool

    /// Today, in the form the log keeps dates in.
    private func today() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 16) {
            EmptyState(
                title: store.state.isGameComplete ? "Game complete" : "Ready to track",
                detail: store.state.isGameComplete
                    ? "Every match is finished."
                    : "A game is \(matchesPerGame) matches to \(targetScore)."
            )
            // Optional, and in front of the operator rather than behind a tap on the
            // header once play has started. Left empty the game is still started at once --
            // the whistle never waits on typing.
            VStack(spacing: 6) {
                TextField("Opposing team (optional)", text: $opponent)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .focused($isNaming)
                    .onSubmit { isNaming = false }
                    .accessibilityIdentifier("pre-game-opponent")
                Text("You can also name it, or change it, from the header once play starts.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)

            Button("Start game") {
                // The rule is written into the event, never read from the code: a game
                // recorded before the rule existed must replay as it always did.
                let id = UUID().uuidString
                guard store.dispatch(
                    .startGame(
                        id: id,
                        seasonId: store.state.activeSeasonId,
                        rotatesAtServeLimit: true
                    )
                ) else {
                    return
                }
                // Dated the moment it starts. A game being tracked is being played today,
                // and a season full of "No date" is the cost of not saying so.
                store.dispatch(
                    .setGameContext(
                        gameId: id,
                        context: GameContext(
                            date: today(),
                            opponent: opponent.trimmingCharacters(in: .whitespaces)
                        )
                    )
                )
                opponent = ""
                isNaming = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxHeight: .infinity)
    }
}

/// What the app could not do, in the operator's words.
struct NoticeBanner: View {
    let notice: Store.Notice?

    var body: some View {
        if let notice {
            Text(notice.text)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(notice.isFailure ? Color.red.opacity(0.25) : Color.green.opacity(0.25))
        }
    }
}

/// A screen with nothing on it yet, saying so plainly.
struct EmptyState: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
