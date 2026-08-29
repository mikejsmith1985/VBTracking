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

    /// The player being brought on, waiting for the tap that says who they replace.
    @State private var armedIncoming: String?

    @State private var alert: ServeLimitAlert?
    @State private var isEndingMatch = false
    @State private var isChoosingLineup = false

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
                    BetweenGames(store: store)
                } else {
                    MatchHeader(store: store, isEndingMatch: $isEndingMatch)
                    ScrollView { TallyBoard(match: store.state.currentMatch, roster: store.state.roster) }
                    Dock(
                        store: store,
                        dock: dock,
                        armedIncoming: $armedIncoming,
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

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
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

    var body: some View {
        VStack(spacing: 16) {
            EmptyState(
                title: store.state.isGameComplete ? "Game complete" : "Ready to track",
                detail: store.state.isGameComplete
                    ? "Every match is finished."
                    : "A game is \(matchesPerGame) matches to \(targetScore)."
            )
            Button("Start game") {
                // The rule is written into the event, never read from the code: a game
                // recorded before the rule existed must replay as it always did.
                store.dispatch(
                    .startGame(
                        id: UUID().uuidString,
                        seasonId: store.state.activeSeasonId,
                        rotatesAtServeLimit: true
                    )
                )
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
