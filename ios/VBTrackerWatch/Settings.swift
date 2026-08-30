// The settings page, and the only place on the watch that writes anything down.
//
// Two switches. What they mean is decided in `WatchPreferences`, which is testable; what is
// here is the storing of them and the switches themselves.
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
final class WatchSettings: PreferenceStore {
    private let defaults: UserDefaults

    var preferences: WatchPreferences {
        didSet { write(preferences) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // `object(forKey:)` and not `bool(forKey:)`: a key that was never written reads as
        // false through the latter, which would silence an alert nobody asked to silence.
        // What is read is the presence of a choice; `WatchPreferences` decides the rest.
        self.preferences = WatchPreferences(
            storedRotateAlert: defaults.object(forKey: WatchPreferences.Key.rotateAlert),
            storedRotateBuzz: defaults.object(forKey: WatchPreferences.Key.rotateBuzz)
        )
    }

    private func write(_ preferences: WatchPreferences) {
        defaults.set(preferences.isRotateAlertOn, forKey: WatchPreferences.Key.rotateAlert)
        defaults.set(preferences.isRotateBuzzOn, forKey: WatchPreferences.Key.rotateBuzz)
    }
}

/// The third page: what the wrist does when the rule fires.
struct SettingsScreen: View {
    @Bindable var settings: WatchSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Rotate alert")
                    .font(.system(size: 12, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                Toggle("Show alert", isOn: $settings.preferences.isRotateAlertOn)
                    .font(.system(size: 14))
                    .accessibilityIdentifier("setting-rotate-alert")

                Toggle("Buzz", isOn: $settings.preferences.isRotateBuzzOn)
                    .font(.system(size: 14))
                    // An invisible alert has nothing to buzz about, so the switch that
                    // would say otherwise is not offered.
                    .disabled(!settings.preferences.isRotateAlertOn)
                    .accessibilityIdentifier("setting-rotate-buzz")

                Text(settings.preferences.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 4)
        }
        .accessibilityIdentifier("settings-screen")
    }
}
