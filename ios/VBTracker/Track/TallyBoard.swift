// The tally board: one mark per serve, grouped by turn.
//
// Colour carries the TURN; the outcome is carried by the mark's shape, so the board stays
// readable without colour vision.
import SwiftUI
import VBCore
import VBPresentation

struct TallyBoard: View {
    let match: Match?
    let roster: [RosterEntry]

    /// Turns grouped by player, in the order each player first served.
    private var rows: [(player: RosterEntry?, turns: [Turn])] {
        guard let match else { return [] }
        var order: [String] = []
        var byPlayer: [String: [Turn]] = [:]

        for turn in match.turns where !turn.serves.isEmpty {
            if byPlayer[turn.playerId] == nil { order.append(turn.playerId) }
            byPlayer[turn.playerId, default: []].append(turn)
        }
        return order.map { id in
            (roster.first { $0.id == id }, byPlayer[id] ?? [])
        }
    }

    var body: some View {
        if rows.isEmpty {
            EmptyState(title: "No serves yet", detail: "Pick the server below to start recording.")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    TallyRow(player: row.player, turns: row.turns)
                }
                Legend()
            }
            .padding(.horizontal)
        }
    }
}

private struct TallyRow: View {
    let player: RosterEntry?
    let turns: [Turn]

    private var totals: Figures {
        turns.reduce(into: Figures()) { running, turn in
            let figures = turn.figures
            running.serves += figures.serves
            running.servesIn += figures.servesIn
            running.points += figures.points
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(text(number: player?.number)).font(.headline.monospacedDigit())
                Text(player?.name ?? "Removed player").font(.subheadline)
                Spacer()
                Text("\(totals.serves) served · \(totals.servesIn) in · \(totals.points) pts")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(turns, id: \.ordinal) { TurnGroup(turn: $0) }
                }
            }
        }
    }
}

/// One serve turn: its marks, its counts, and a flag when it ran past the limit.
private struct TurnGroup: View {
    let turn: Turn

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                ForEach(Array(turn.serves.enumerated()), id: \.offset) { _, serve in
                    Mark(outcome: serve.outcome, tint: tint)
                }
            }
            Text("\(turn.isOverServeLimit ? "⚠ " : "")\(turn.serves.count) · \(turn.figures.servesIn) in")
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.7)))
    }

    private var tint: Color {
        Color(hex: colorForTurn(turn.ordinal))
    }
}

/// One serve. Shape is the outcome; colour is the turn.
private struct Mark: View {
    let outcome: Outcome
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(tint, lineWidth: 2)
                .background(RoundedRectangle(cornerRadius: 2).fill(outcome == .inPoint ? tint : .clear))
            if outcome == .out {
                Rectangle().fill(tint).frame(width: 16, height: 2).rotationEffect(.degrees(-45))
            }
        }
        .frame(width: 8, height: 22)
    }
}

private struct Legend: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("filled = point").font(.system(size: 10))
            Text("open = in, no point").font(.system(size: 10))
            Text("crossed = out").font(.system(size: 10))
            Text("colour = turn").font(.system(size: 10))
        }
        .foregroundStyle(.tertiary)
    }
}

extension Color {
    /// The palette is shared with the web app, and it is written in hex there.
    init(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = UInt64(digits, radix: 16) ?? 0
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}
