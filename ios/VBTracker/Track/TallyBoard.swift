// The tally board: one mark per serve, grouped by turn, in the colour of the player.
//
// Colour carries the PLAYER, not the turn. "The green tallies are number 5" is something a
// coach can hold in their head across a whole match; "the green ones are the third turn"
// is not. A player's own turns are shades of their one hue, so the turns stay separable
// without the colour stopping meaning a person.
//
// The outcome is carried by the mark's shape, so the board still reads without colour
// vision at all.
import SwiftUI
import VBCore
import VBPresentation

struct TallyBoard: View {
    let match: Match?
    let roster: [RosterEntry]

    private var rows: [TallyRow] { tallyRows(of: match) }

    var body: some View {
        if rows.isEmpty {
            EmptyState(title: "No serves yet", detail: "Pick the server below to start recording.")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(rows, id: \.playerId) { row in
                    TallyRowView(row: row, player: roster.first { $0.id == row.playerId })
                }
                Legend()
            }
            .padding(.horizontal)
        }
    }
}

private struct TallyRowView: View {
    let row: TallyRow
    let player: RosterEntry?

    private var tint: Color { Color(hex: row.color) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                // The number carries the player's colour too, so the link between a colour
                // and a person is stated rather than left to be inferred from the marks.
                Text(text(number: player?.number))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(tint)
                Text(player?.name ?? "Removed player").font(.subheadline)
                Spacer()
                Text("\(row.figures.serves) served · \(row.figures.servesIn) in · \(row.figures.points) pts")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(row.turns.enumerated()), id: \.element.ordinal) { position, turn in
                        TurnGroup(turn: turn, tint: Color(hex: row.color(ofTurnAt: position)))
                    }
                }
            }
        }
    }
}

/// One serve turn: its marks, its counts, and a flag when it ran past the limit.
private struct TurnGroup: View {
    let turn: Turn
    let tint: Color

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
}

/// One serve. Shape is the outcome; colour is the player.
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
            Text("colour = player").font(.system(size: 10))
        }
        .foregroundStyle(.tertiary)
    }
}

extension Color {
    /// The palette is written in hex, shared with the web app.
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
