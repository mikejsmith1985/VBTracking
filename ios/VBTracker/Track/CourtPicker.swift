// The six on court, laid out as the court is — the same arrangement the wrist draws, from
// the same definition, so the two cannot disagree about who serves next.
//
// Net at the top, service corner bottom right, the rotation running clockwise. The
// arrangement stays still and the players move through it.
import SwiftUI
import VBCore
import VBPresentation

struct CourtPicker: View {
    let store: Store
    @Binding var armedIncoming: String?
    @Binding var isPickerRequested: Bool

    private var court: CourtView? { store.state.courtView() }

    var body: some View {
        VStack(spacing: 8) {
            if let court {
                CourtGrid(court: court, store: store, armedIncoming: armedIncoming, onTap: tap)
                Bench(store: store, court: court, armedIncoming: armedIncoming, onTap: tap)
            } else {
                // No order set: every player is simply a choice of server.
                ChipGrid(players: store.state.roster, armedIncoming: armedIncoming, servingId: store.state.activeServerId, onTap: tap)
            }

            Text(pickerHint(state: store.state, armedIncoming: armedIncoming))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    /// A tap means one of two things, and which one is decided by where the player is
    /// standing rather than by how fast the operator taps.
    private func tap(_ playerId: String) {
        switch intent(ofTapping: playerId, state: store.state, armedIncoming: armedIncoming) {
        case let .serve(playerId):
            armedIncoming = nil
            if store.dispatch(.selectServer(playerId: playerId)) { isPickerRequested = false }

        case let .armSubstitution(incoming):
            armedIncoming = incoming

        case let .substitute(out, incoming):
            if store.dispatch(.substitute(outPlayerId: out, inPlayerId: incoming)) {
                armedIncoming = nil
                isPickerRequested = false
            }

        case .ignore:
            armedIncoming = nil
            isPickerRequested = false
        }
    }
}

/// The court itself: uneven tracks, so the service corner and the on-deck box are the two
/// that read first.
private struct CourtGrid: View {
    let court: CourtView
    let store: Store
    let armedIncoming: String?
    let onTap: (String) -> Void

    var body: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            GridRow {
                ForEach(court.slots.prefix(3), id: \.position) { slot in cell(slot) }
            }
            GridRow {
                ForEach(court.slots.suffix(3), id: \.position) { slot in cell(slot) }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14).stroke(.quaternary)
        )
        .overlay(alignment: .top) {
            // The net, so which way the court faces is never in doubt.
            Rectangle().fill(.quaternary).frame(height: 2).padding(.horizontal, 14).padding(.top, 3)
        }
    }

    private func cell(_ slot: CourtSlot) -> some View {
        VStack(spacing: 2) {
            Text("\(slot.position.rawValue)")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let playerId = slot.playerId, let player = store.state.rosterEntry(id: playerId) {
                Chip(
                    player: player,
                    isServing: slot.isServing,
                    isOnCourt: true,
                    isArmed: armedIncoming == playerId,
                    onTap: { onTap(playerId) }
                )
            } else {
                // A position nobody is standing in is still a place in the order.
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.tertiary)
                    .frame(height: 44)
                    .overlay(Text(missingFigure).foregroundStyle(.tertiary))
            }

            if slot.isServing {
                Text("serving").font(.system(size: 9, weight: .heavy)).foregroundStyle(.cyan)
            } else if slot.isOnDeck, court.hasOrder {
                Text("next").font(.system(size: 9, weight: .heavy)).foregroundStyle(.secondary)
            }
        }
    }
}

/// Everyone not on the court, shown as what they are.
private struct Bench: View {
    let store: Store
    let court: CourtView
    let armedIncoming: String?
    let onTap: (String) -> Void

    private var bench: [RosterEntry] {
        let onCourt = Set(court.slots.compactMap(\.playerId))
        return store.state.roster.filter { !onCourt.contains($0.id) }
    }

    var body: some View {
        if !bench.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bench").font(.system(size: 10, weight: .heavy)).textCase(.uppercase)
                    .foregroundStyle(.secondary)
                ChipGrid(players: bench, armedIncoming: armedIncoming, servingId: nil, onTap: onTap, isBench: true)
            }
        }
    }
}

/// A grid of players, used where there is no court to arrange them on.
private struct ChipGrid: View {
    let players: [RosterEntry]
    let armedIncoming: String?
    let servingId: String?
    let onTap: (String) -> Void
    var isBench = false

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 6)], spacing: 6) {
            ForEach(players, id: \.id) { player in
                Chip(
                    player: player,
                    isServing: player.id == servingId,
                    isOnCourt: !isBench,
                    isArmed: armedIncoming == player.id,
                    onTap: { onTap(player.id) }
                )
            }
        }
    }
}

/// One player. The jersey number alone, set large — a truncated name is neither a name nor
/// readable at arm's length, and the number is what the operator scans for.
struct Chip: View {
    let player: RosterEntry
    let isServing: Bool
    let isOnCourt: Bool
    let isArmed: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(text(number: player.number))
                .font(.system(size: 24, weight: .heavy))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(isArmed ? .orange : (isServing ? .cyan : .gray))
        .opacity(isOnCourt || isArmed ? 1 : 0.65)
        .accessibilityIdentifier("player-\(player.id)")
        .accessibilityLabel("\(player.name), number \(player.number)")
    }
}
