// The three things that happen between rallies: the five-serve alert, ending a match, and
// setting the six on court.
//
// None of them belong near the controls tapped during a rally, which is why each is a sheet
// or an overlay rather than another button in the dock.
import SwiftUI
import VBCore
import VBPresentation

/// The five-serve alert.
///
/// The one thing in the app that deliberately interrupts. The limit is the referee's to
/// enforce and the easiest count on the court to lose, so it covers the screen and clears
/// on any tap.
struct ServeLimitOverlay: View {
    let alert: ServeLimitAlert
    let roster: [RosterEntry]
    let onDismiss: () -> Void

    private var finished: RosterEntry? { roster.first { $0.id == alert.finishedPlayerId } }
    private var next: RosterEntry? { alert.nextPlayerId.flatMap { id in roster.first { $0.id == id } } }

    var body: some View {
        ZStack {
            Color.black.opacity(0.86).ignoresSafeArea()
            VStack(spacing: 10) {
                Text("⟳").font(.system(size: 52)).foregroundStyle(.orange)
                Text("Rotate").font(.system(size: 32, weight: .heavy)).foregroundStyle(.orange)
                Text("\(text(number: finished?.number)) \(finished?.name ?? "That player") has served \(serveLimit)")
                    .font(.subheadline).foregroundStyle(.secondary)

                if let next {
                    Text("Next up: \(text(number: next.number)) \(next.name)").font(.title3.bold())
                } else {
                    // Without an order the same player is still holding the ball, and
                    // naming them would read as permission to serve a sixth.
                    Text("Pick the next server.").font(.title3.bold())
                }

                Button("Got it", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 20).fill(.regularMaterial))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.orange, lineWidth: 2))
            .padding(24)
        }
        // A container in SwiftUI is not an accessibility element on its own, so the
        // identifier had nothing to attach to and the overlay could not be addressed at all
        // -- by a test, or by anything else reading the screen. Naming it as a container
        // that keeps its children also lets it be marked modal, which is what tells
        // VoiceOver to ignore the court behind it. That is the whole point of an interrupt.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("serve-limit-alert")
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("Rotate")
        .onTapGesture(perform: onDismiss)
    }
}

/// Ending a match asks how it went in the same breath.
///
/// The opponent's score is still not tracked, so the app cannot know — and this is the one
/// moment the operator certainly does.
struct EndMatchSheet: View {
    let store: Store
    @Binding var isPresented: Bool
    @State private var isConfirmingDiscard = false

    var body: some View {
        NavigationStack {
            List {
                Section("How did that match go?") {
                    Button("Won") { end(.won) }
                    Button("Lost") { end(.lost) }
                    Button("End without recording") { end(.undecided) }
                }

                Section("Or stop here") {
                    Button("End the game — keep what is recorded") {
                        store.dispatch(.endGame(result: .absent))
                        isPresented = false
                    }
                    Button(isConfirmingDiscard ? "Throw this game away?" : "Throw this game away", role: .destructive) {
                        guard isConfirmingDiscard else { isConfirmingDiscard = true; return }
                        if let id = store.state.currentGame?.id {
                            store.dispatch(.discardGame(id: id))
                        }
                        isPresented = false
                    }
                    Text(
                        isConfirmingDiscard
                            ? "Tap again to discard. Every serve in this game goes with it. The roster and the rest of the season are untouched."
                            : "Ending keeps every serve and closes the game where it stands, however many matches were played."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("End match")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep playing") { isPresented = false }
                }
            }
        }
    }

    private func end(_ result: MatchResult) {
        store.dispatch(.endMatch(result: .value(result)))
        isPresented = false
    }
}

/// The six on court, in serving order.
struct LineupSheet: View {
    let store: Store
    @Binding var isPresented: Bool
    @State private var chosen: [String] = []

    private var current: [String] {
        (store.state.currentLineup ?? []).compactMap { $0 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Serving order") {
                    ForEach(Array(chosen.enumerated()), id: \.offset) { index, playerId in
                        HStack {
                            Text("\(index + 1)").font(.caption.bold()).foregroundStyle(.secondary)
                            Text(store.state.rosterEntry(id: playerId)?.name ?? "Removed player")
                            Spacer()
                            Text(text(number: store.state.rosterEntry(id: playerId)?.number))
                                .font(.headline.monospacedDigit())
                        }
                        .onTapGesture { chosen.removeAll { $0 == playerId } }
                    }
                }

                Section("Everyone else") {
                    ForEach(store.state.roster.filter { !chosen.contains($0.id) }, id: \.id) { player in
                        Button {
                            guard chosen.count < lineupSize else { return }
                            chosen.append(player.id)
                        } label: {
                            HStack {
                                Text(player.name)
                                Spacer()
                                Text(text(number: player.number)).font(.headline.monospacedDigit())
                            }
                        }
                    }
                }

                Section {
                    Text("Tap in the order they serve. The first is the server; the rotation hands it on from there.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Six on court")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        if store.dispatch(.setLineup(playerIds: chosen)) { isPresented = false }
                    }
                    .disabled(chosen.count != lineupSize)
                }
            }
            .onAppear { chosen = current }
        }
    }
}

/// Who the game is against, asked where the operator is standing.
///
/// It used to be askable only from the season screen, three taps away and usually after the
/// fact — which is how a game ends up in the record called "Unnamed opponent".
struct GameNameSheet: View {
    let store: Store
    @Binding var isPresented: Bool

    @State private var context = GameContext()

    private var game: Game? { store.state.currentGame }

    var body: some View {
        NavigationStack {
            Form {
                Section("Who, where, when") {
                    TextField("Opposing team", text: $context.opponent)
                        .accessibilityIdentifier("game-opponent")
                    DatePicker("Date", selection: dateBinding, displayedComponents: .date)
                    TextField("Location", text: $context.location)
                    TextField("Court", text: $context.court)
                }

                Section {
                    Text("None of it is required. A game with no opponent is still a game, and this can be filled in afterwards from the season.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("This game")
            .keyboardDismissable()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let id = game?.id else { return isPresented = false }
                        if store.dispatch(.setGameContext(gameId: id, context: context)) {
                            isPresented = false
                        }
                    }
                    .accessibilityIdentifier("save-game-name")
                }
            }
            .onAppear {
                context = game?.context ?? GameContext()
                // A game being tracked right now was played today. Offering that rather
                // than nothing is what stops a season filling up with "No date".
                if context.date == nil { context.date = Self.formatter.string(from: Date()) }
            }
        }
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { context.date.flatMap(Self.formatter.date(from:)) ?? Date() },
            set: { context.date = Self.formatter.string(from: $0) }
        )
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
