// The settings page, and the only place on the watch that writes anything down.
//
// Three choices, one column. What each of them means is decided in `RotateAlertStyle`,
// which is testable; what is here is the storing of it and the rows themselves.
//
// `UserDefaults` rather than the log: this is a choice about a wrist, not a fact about a
// season. Putting it in the append-only log would make it replay, travel in a backup, and
// undo — none of which is true of a preference. `VBStore` stays what it says it is: the log.
import Foundation
import SwiftUI
import VBCore
import VBPresentation

/// The coach's settings, kept on the watch that wears them.
@MainActor
@Observable
final class WatchSettings {
    private let defaults: UserDefaults

    var preferences: WatchPreferences {
        didSet { write(preferences) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // `object(forKey:)` and not a typed read: what is wanted is whether a choice was
        // ever made, and `WatchPreferences` decides what absence means. It means the
        // default, not "off".
        self.preferences = WatchPreferences(
            storedRotateAlert: defaults.object(forKey: WatchPreferences.Key.rotateAlert)
        )
    }

    private func write(_ preferences: WatchPreferences) {
        defaults.set(preferences.rotateAlert.rawValue, forKey: WatchPreferences.Key.rotateAlert)
    }
}

/// The third page: how hard the wrist presses about the five-serve rule.
struct SettingsScreen: View {
    let settings: WatchSettings
    let keeper: ScoreKeeper

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Rotate alert")
                    .font(.system(size: 12, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                // Three rows rather than a segmented control: at 40 mm a third of the width
                // is not a tappable thing, and each choice needs a line saying what it does.
                ForEach(RotateAlertStyle.allCases, id: \.self) { style in
                    choice(style)
                }

                Divider().padding(.vertical, 2)

                Text("Scratch game")
                    .font(.system(size: 12, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text("Played to")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                // Whatever was agreed on the way to the court. Win-by-two is not a choice:
                // it is how the game is played.
                HStack(spacing: 4) {
                    ForEach(Scoreboard.targets, id: \.self) { target in
                        Button("\(target)") { keeper.board.target = target }
                            .font(.system(size: 13, weight: .semibold))
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .tint(keeper.board.target == target ? .cyan : .gray)
                            .accessibilityIdentifier("score-target-\(target)")
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .accessibilityIdentifier("settings-screen")
    }

    private func choice(_ style: RotateAlertStyle) -> some View {
        let isChosen = settings.preferences.rotateAlert == style

        return Button {
            settings.preferences.rotateAlert = style
        } label: {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChosen ? Color.orange : Color.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(style.label).font(.system(size: 14, weight: .semibold))
                    Text(style.detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("setting-rotate-\(style.rawValue)")
    }
}
