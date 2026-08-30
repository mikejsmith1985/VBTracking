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
        VStack(spacing: ScoreLayout.spacing) {
            HStack(spacing: 6) {
                column(.us)
                column(.them)
            }

            Text(board.status)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(board.winner == nil ? Color.secondary : Color.orange)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: ScoreLayout.statusHeight)

            newGameButton
        }
        .padding(.horizontal, 2)
    }

    /// One side: the number, which is the button that adds to it, and the minus beneath.
    ///
    /// Both are plain buttons over a shape this file draws. watchOS's bordered style has a
    /// control height of its own and ignores a frame asked for inside it, which is what put
    /// the side's name outside its pill and left the minus nearly as tall as the score.
    private func column(_ side: Side) -> some View {
        VStack(spacing: ScoreLayout.spacing) {
            Button {
                act { keeper.board.award(to: side) }
            } label: {
                VStack(spacing: 0) {
                    Text(side.label)
                        .font(.system(size: ScoreLayout.sideFontSize, weight: .heavy))
                        .foregroundStyle(tint(side))
                        .opacity(0.75)
                    Text("\(board.score(side))")
                        .font(.system(size: ScoreLayout.scoreFontSize, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(tint(side))
                }
                .frame(maxWidth: .infinity, minHeight: ScoreLayout.scoreHeight)
                .background(
                    RoundedRectangle(cornerRadius: ScoreLayout.cornerRadius)
                        .fill(tint(side).opacity(0.22))
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("score-\(side.rawValue)")
            .accessibilityLabel("\(side.label), \(board.score(side)). Tap to add a point.")

            Button {
                act { keeper.board.subtract(from: side) }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: ScoreLayout.minusFontSize, weight: .bold))
                    .foregroundStyle(board.canSubtract(from: side) ? Color.secondary : Color.secondary.opacity(0.3))
                    .frame(maxWidth: .infinity, minHeight: ScoreLayout.minusPillHeight)
                    .background(
                        RoundedRectangle(cornerRadius: ScoreLayout.minusPillHeight / 2)
                            .fill(Color.white.opacity(0.10))
                    )
                    // Drawn small, tapped bigger. A control small enough to read as
                    // secondary is smaller than a thumb, and the difference is free.
                    .frame(height: ScoreLayout.minusTapHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!board.canSubtract(from: side))
            .accessibilityIdentifier("score-minus-\(side.rawValue)")
            .accessibilityLabel("Take a point off \(side.label)")
        }
    }

    private func tint(_ side: Side) -> Color {
        side == .us ? .cyan : Color(white: 0.75)
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
                .font(.system(size: ScoreLayout.newGameFontSize, weight: .semibold))
                .foregroundStyle(isConfirmingNewGame ? Color.red : Color.secondary)
                .frame(maxWidth: .infinity, minHeight: ScoreLayout.newGameHeight)
                .background(
                    RoundedRectangle(cornerRadius: ScoreLayout.cornerRadius)
                        .fill(isConfirmingNewGame ? Color.red.opacity(0.22) : Color.white.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
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
