// The phone app.
//
// Four tabs, the same four the web app shipped with, because the operator has been using
// them all season and the names are in their hands already: Track, Game, Season, Roster.
import SwiftUI
import VBCore

@main
struct VBTrackerApp: App {
    @State private var store = Store(directory: AppPaths.storeDirectory)
    @State private var link: PhoneLink?
    @State private var tab = Tab.track

    var body: some Scene {
        WindowGroup {
            // Each tab spells out its own name. A `Label` in a tab bar exposes its symbol
            // name to the accessibility tree and not its text, so the tabs read aloud as
            // "record.circle" and "person.3" -- no use to anybody navigating by voice, and
            // the reason every interface test sat on the roster screen wondering where the
            // Track tab had gone. An identifier does not fix it: applied after `.tabItem` it
            // lands on the tab's CONTENT and spreads to the buttons inside, so a test asking
            // for the tab found something off-screen and tapped nothing. The label belongs on
            // the Label itself, which is the thing the bar button is built from.
            TabView(selection: $tab) {
                TrackScreen(store: store)
                    .tabItem { Label("Track", systemImage: "record.circle").accessibilityLabel("Track") }
                    .tag(Tab.track)

                GameScreen(store: store)
                    .tabItem { Label("Game", systemImage: "list.number").accessibilityLabel("Game") }
                    .tag(Tab.game)

                SeasonScreen(store: store)
                    .tabItem { Label("Season", systemImage: "calendar").accessibilityLabel("Season") }
                    .tag(Tab.season)

                RosterScreen(store: store)
                    .tabItem { Label("Roster", systemImage: "person.3").accessibilityLabel("Roster") }
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
    /// Where the log lives for this launch.
    ///
    /// An interface test asks for a container of its own, and gets an empty one. Without
    /// that every test inherited the season the last one left behind: the suite passed the
    /// `-uiTestFreshStore` argument from the day it was written and nothing ever read it,
    /// so ten tests ran against one accumulating pile of state and failed for reasons that
    /// had nothing to do with what they were testing.
    static var storeDirectory: URL {
        guard ProcessInfo.processInfo.arguments.contains("-uiTestFreshStore") else {
            return sharedContainer
        }

        let fresh = URL.temporaryDirectory.appendingPathComponent("uitest-store", isDirectory: true)
        try? FileManager.default.removeItem(at: fresh)
        try? FileManager.default.createDirectory(at: fresh, withIntermediateDirectories: true)
        return fresh
    }

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
