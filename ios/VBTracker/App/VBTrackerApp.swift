// The phone app.
//
// Four tabs, the same four the web app shipped with, because the operator has been using
// them all season and the names are in their hands already: Track, Game, Season, Roster.
import SwiftUI
import VBCore

@main
struct VBTrackerApp: App {
    @State private var store = Store(directory: AppPaths.sharedContainer)
    @State private var link: PhoneLink?
    @State private var tab = Tab.track

    var body: some Scene {
        WindowGroup {
            TabView(selection: $tab) {
                TrackScreen(store: store)
                    .tabItem { Label("Track", systemImage: "record.circle") }
                    .tag(Tab.track)

                GameScreen(store: store)
                    .tabItem { Label("Game", systemImage: "list.number") }
                    .tag(Tab.game)

                SeasonScreen(store: store)
                    .tabItem { Label("Season", systemImage: "calendar") }
                    .tag(Tab.season)

                RosterScreen(store: store)
                    .tabItem { Label("Roster", systemImage: "person.3") }
                    .tag(Tab.roster)
            }
            .tint(.cyan)
            .preferredColorScheme(.dark)
            .task {
                // The link is started after the store, and nothing waits on it: a phone with
                // no watch paired must behave exactly as it does with one.
                guard link == nil else { return }
                link = PhoneLink(store: store)
            }
        }
    }

    enum Tab: Hashable {
        case track, game, season, roster
    }
}

/// Where the log lives.
enum AppPaths {
    /// The App Group container, so a later widget or complication can read the same log
    /// rather than keeping a second copy of it.
    static var sharedContainer: URL {
        let group = "group.com.mikejsmith.vbtracker"
        if let shared = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) {
            return shared
        }
        // A missing group is a signing problem, not a reason to lose a season: fall back to
        // the app's own documents so recording still works and nothing is thrown away.
        return URL.documentsDirectory
    }
}
