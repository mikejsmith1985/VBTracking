// The six on court, laid out as the court is — the same arrangement the wrist draws, from
// the same definition, so the two cannot disagree about who serves next.
//
// Net at the top, service corner bottom right, the rotation running clockwise. The
// arrangement stays still and the players move through it.
//
// Before the first serve the boxes are also how the rotation gets set: tap an empty box
// then the player who stands in it, or tap the player then the box. Both work, because
// asking the operator to remember which way round it goes is asking them to look away from
// the court to find out.
import SwiftUI
import VBCore
import VBPresentation

struct CourtPicker: View {
    let store: Store
    @Binding var armed: Armed?
    @Binding var isPickerRequested: Bool

    private var court: CourtView? { store.state.courtView() }

    var body: some View {
        VStack(spacing: 8) {
            if let court {
                CourtGrid(court: court, store: store, armed: armed, onTap: tap, onTapPosition: tapPosition)
                Bench(store: store, court: court, armed: armed, onTap: tap)
            } else {
                // No match at all: every player is simply a choice of server.
                ChipGrid(players: store.state.roster, armed: armed, servingId: store.state.activeServerId, onTap: tap)
            }

            Text(pickerHint(state: store.state, armed: armed))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    /// A tap on a player means one of several things, and which one is decided by where
    /// they are standing and what is already held — never by how fast the operator taps.
    private func tap(_ playerId: String) {
        apply(intent(ofTapping: playerId, state: store.state, armed: armed))
    }

    /// A tap on a place in the serving order.
    private func tapPosition(_ lineupIndex: Int) {
        apply(intent(ofTappingPosition: lineupIndex, state: store.state, armed: armed))
    }

    private func apply(_ decided: TapIntent) {
        switch decided {
        case let .serve(playerId):
            armed = nil
            if store.dispatch(.selectServer(playerId: playerId)) { isPickerRequested = false }

        case let .armSubstitution(incoming):
            armed = .player(incoming)

        case let .armPosition(lineupIndex):
            armed = .position(lineupIndex)

        case let .place(playerId, lineupIndex):
            // The picker stays open: placing one player is a sixth of the job, and closing
            // it would cost a tap to reopen for each of the other five.
            if store.dispatch(.placeInLineup(playerId: playerId, lineupIndex: lineupIndex)) {
                armed = nil
            }

        case let .substitute(out, incoming):
            if store.dispatch(.substitute(outPlayerId: out, inPlayerId: incoming)) {
                armed = nil
                isPickerRequested = false
            }

        case .ignore:
            // Putting something down also puts the picker away. Without this, tapping the
            // player already serving -- which is the most natural way to say "no, carry on"
            // -- left the court open over the outcome controls until Cancel was found.
            armed = nil
            isPickerRequested = false
        }
    }
}

/// The court itself: uneven tracks, so the service corner and the on-deck box are the two
/// that read first.
private struct CourtGrid: View {
    let court: CourtView
    let store: Store
    let armed: Armed?
    let onTap: (String) -> Void
    let onTapPosition: (Int) -> Void

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

    /// Which place in the serving order this box is, right now.
    ///
    /// The court is drawn around whoever is serving, so the same box is a different place
    /// in the order at different moments — which is why this is worked out rather than
    /// stored on the slot.
    private func lineupIndex(of slot: CourtSlot) -> Int {
        VBCore.lineupIndex(servingPosition: court.servingPosition, offset: slot.position.offsetFromServer)
    }

    private func cell(_ slot: CourtSlot) -> some View {
        let index = lineupIndex(of: slot)
        let isHeld = armed == Armed.position(index)

        return VStack(spacing: 2) {
            Text("\(slot.position.rawValue)")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let playerId = slot.playerId, let player = store.state.rosterEntry(id: playerId) {
                Chip(
                    player: player,
                    isServing: slot.isServing,
                    isOnCourt: true,
                    isArmed: armed == Armed.player(playerId),
                    onTap: { onTap(playerId) }
                )
            } else {
                EmptySpot(isHeld: isHeld, onTap: { onTapPosition(index) })
            }

            if slot.isServing {
                Text("serving").font(.system(size: 9, weight: .heavy)).foregroundStyle(.cyan)
            } else if slot.isOnDeck, court.hasOrder {
                Text("next").font(.system(size: 9, weight: .heavy)).foregroundStyle(.secondary)
            }
        }
    }
}

/// A place in the order nobody is standing in — which is still a place, and still a target
/// for the tap that puts someone there.
private struct EmptySpot: View {
    let isHeld: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isHeld ? Color.orange : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: isHeld ? 2 : 1, dash: isHeld ? [] : [4])
                )
                .frame(height: 44)
                .overlay(
                    Text(isHeld ? "WHO?" : missingFigure)
                        .font(isHeld ? .caption.bold() : .body)
                        .foregroundStyle(isHeld ? Color.orange : Color.secondary)
                )
                // `strokeBorder` draws a line and nothing else, so the box had no inside to
                // hit -- only the 1pt border and the dash in the middle. Every tap that
                // landed anywhere else did nothing, which read as needing to tap twice.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("empty-spot")
        .accessibilityLabel(isHeld ? "Empty spot, selected" : "Empty spot")
    }
}

/// Everyone not on the court, shown as what they are.
private struct Bench: View {
    let store: Store
    let court: CourtView
    let armed: Armed?
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
                ChipGrid(players: bench, armed: armed, servingId: nil, onTap: onTap, isBench: true)
            }
        }
    }
}

/// A grid of players, used where there is no court to arrange them on.
private struct ChipGrid: View {
    let players: [RosterEntry]
    let armed: Armed?
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
                    isArmed: armed == Armed.player(player.id),
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
        // Where they are standing is said out loud, not left to the 65% opacity that says it
        // to everybody else. A court chip and a bench chip were otherwise indistinguishable
        // to anything that cannot see them.
        .accessibilityLabel("\(player.name), number \(player.number)\(isOnCourt ? "" : ", on the bench")")
    }
}
