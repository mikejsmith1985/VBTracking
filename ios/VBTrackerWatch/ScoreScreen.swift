// Keeping score on the wrist, for a game nobody is tracking.
//
// Two big numbers, a tap each. No roster, no season, no log — a Saturday in the park does
// not go in the record, and it must not be able to.
//
// The score is kept where the settings are, for the same reason: a wrist that sleeps between
// rallies, or an app that gets swapped away, must not lose a game that has no other copy
// anywhere.
import Foundation
import SwiftUI
import VBCore
import VBPresentation
import WatchKit

/// The scratch scoreboard, kept on the watch that keeps it.
@MainActor
@Observable
final class ScoreKeeper {
    private let defaults: UserDefaults
    private static let key = "scratchScoreboard"

    var board: Scoreboard {
        didSet { write(board) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // A game half-played and then lost to a sleeping wrist is worse than no scoreboard
        // at all, so it is read back rather than started fresh.
        if let data = defaults.data(forKey: Self.key),
            let stored = try? JSONDecoder().decode(Scoreboard.self, from: data)
        {
            self.board = stored
        } else {
            self.board = Scoreboard()
        }
    }

    private func write(_ board: Scoreboard) {
        guard let data = try? JSONEncoder().encode(board) else { return }
        defaults.set(data, forKey: Self.key)
    }
}

struct ScoreScreen: View {
    let keeper: ScoreKeeper
    @State private var isConfirmingReset = false

    private var board: Scoreboard { keeper.board }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                side(.us, value: board.us)
                side(.them, value: board.them)
            }

            Text(board.status)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(board.winner == nil ? Color.secondary : Color.orange)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 4) {
                Button("Undo") { act { keeper.board.undo() } }
                    .disabled(!board.canUndo)
                    .accessibilityIdentifier("score-undo")

                Button(isConfirmingReset ? "Sure?" : "Reset") {
                    // Two taps, because a reset cannot be undone and the whole game is in
                    // these two numbers -- there is no copy of it anywhere else.
                    if isConfirmingReset {
                        act { keeper.board.reset() }
                        isConfirmingReset = false
                    } else {
                        isConfirmingReset = true
                    }
                }
                .tint(isConfirmingReset ? .red : nil)
                .accessibilityIdentifier("score-reset")
            }
            .font(.system(size: 12))
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(.horizontal, 2)
    }

    /// One side's number, which is also the button that adds to it.
    private func side(_ side: Side, value: Int) -> some View {
        Button {
            act { keeper.board.award(to: side) }
        } label: {
            VStack(spacing: 0) {
                Text(side.label)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.secondary)
                Text("\(value)")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 74)
        }
        .buttonStyle(.bordered)
        .tint(side == .us ? .cyan : .gray)
        .accessibilityIdentifier("score-\(side.rawValue)")
        .accessibilityLabel("\(side.label), \(value)")
    }

    /// Every change is felt as well as seen: the wrist is glanced at, not watched.
    ///
    /// A change that finishes the game gets the heavier haptic, because that is the one
    /// worth looking down for.
    private func act(_ change: () -> Void) {
        let wasWon = board.winner != nil
        change()
        isConfirmingReset = false
        WKInterfaceDevice.current().play(board.winner != nil && !wasWon ? .success : .click)
    }
}
