// Keeping score on the wrist, for a game nobody is tracking.
//
// Two big numbers, a tap each to add, a minus under each to take one off. Per side rather
// than a single undo: a scorekeeper who has given a point to the wrong team knows which
// team, and asking them to work out how many steps back that was, in a gym, is asking for
// the wrong correction.
//
// No roster, no season, no log — a Saturday in the park does not go in the record and must
// not be able to.
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
    @State private var isConfirmingNewGame = false

    private var board: Scoreboard { keeper.board }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                column(.us)
                column(.them)
            }

            Text(board.status)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(board.winner == nil ? Color.secondary : Color.orange)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            newGameButton
        }
        .padding(.horizontal, 2)
    }

    /// One side: the number, which is the button that adds to it, and the minus beneath.
    ///
    /// The minus is deliberately the smaller of the two. Adding a point happens every rally
    /// and taking one off happens when somebody made a mistake, so the one under the thumb
    /// is the one that is right nearly every time.
    private func column(_ side: Side) -> some View {
        VStack(spacing: 2) {
            Button {
                act { keeper.board.award(to: side) }
            } label: {
                VStack(spacing: 0) {
                    Text(side.label)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.secondary)
                    Text("\(board.score(side))")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: 68)
            }
            .buttonStyle(.bordered)
            .tint(side == .us ? .cyan : .gray)
            .accessibilityIdentifier("score-\(side.rawValue)")
            .accessibilityLabel("\(side.label), \(board.score(side)). Tap to add a point.")

            Button {
                act { keeper.board.subtract(from: side) }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 24)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
            .disabled(!board.canSubtract(from: side))
            .accessibilityIdentifier("score-minus-\(side.rawValue)")
            .accessibilityLabel("Take a point off \(side.label)")
        }
    }

    /// Starting again, across the bottom where nothing else is.
    ///
    /// Two taps, because it cannot be undone and the whole game is in those two numbers --
    /// there is no copy of it anywhere else. On a board nobody has scored on it is one tap,
    /// since there is nothing there to lose.
    private var newGameButton: some View {
        Button {
            if isConfirmingNewGame || !board.hasStarted {
                act { keeper.board.reset() }
                isConfirmingNewGame = false
            } else {
                isConfirmingNewGame = true
            }
        } label: {
            Text(isConfirmingNewGame ? "Start over?" : "New game")
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 26)
        }
        .buttonStyle(.bordered)
        .tint(isConfirmingNewGame ? .red : .gray)
        .accessibilityIdentifier("score-new-game")
    }

    /// Every change is felt as well as seen: the wrist is glanced at, not watched.
    ///
    /// A change that finishes the game gets the heavier haptic, because that is the one
    /// worth looking down for.
    private func act(_ change: () -> Void) {
        let wasWon = board.winner != nil
        change()
        isConfirmingNewGame = false
        WKInterfaceDevice.current().play(board.winner != nil && !wasWon ? .success : .click)
    }
}
