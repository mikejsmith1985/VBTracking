// The phone app.
//
// Four tabs, the same four the web app shipped with, because the operator has been using
// them all season and the names are in their hands already: Track, Game, Season, Roster.
import SwiftUI
import UIKit
import VBCore

@main
struct VBTrackerApp: App {
    @State private var store = Store(directory: AppPaths.storeDirectory)
    @State private var link: PhoneLink?
    @State private var peers: PeerLink?
    @State private var lockScreen = CourtActivityHost()
    @State private var tab = Tab.track
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            // A known rough edge, written down rather than papered over: a SwiftUI tab
            // bar hands the accessibility tree its symbol name and drops the Label's text,
            // so these tabs read aloud as "record.circle" and "person.3". Two attempts have
            // failed -- an `.accessibilityIdentifier` after `.tabItem` lands on the tab's
            // CONTENT instead of the bar button, and an `.accessibilityLabel` on the Label
            // is ignored outright. Fixing it properly means leaving `.tabItem` behind, which
            // is a change worth making on a machine that can run it and watch what happens.
            TabView(selection: $tab) {
                TrackScreen(store: store, peers: peers)
                    .tabItem { Label("Track", systemImage: "record.circle") }
                    .tag(Tab.track)

                GameScreen(store: store)
                    .tabItem { Label("Game", systemImage: "list.number") }
                    .tag(Tab.game)

                SeasonScreen(store: store, peers: peers, lockScreen: lockScreen)
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
                // Built but not started: sharing a match with a second phone is switched on
                // by hand, and until it is, no radio is touched and no permission is asked
                // for. A phone that never shares never sees the local-network prompt.
                peers = PeerLink(store: store, deviceName: UIDevice.current.name)

                // The lock screen follows the record like the wrist does, and is switched on
                // by hand: a lock screen is somebody's own, and an app that puts itself there
                // uninvited is one they turn off entirely.
                store.observe { state in lockScreen.follow(state) }
            }
            // A season sent from another phone. The file arrives here whether the app was
            // running or not, and it is merged rather than restored: the person receiving it
            // has their own roster, and replacing it would be a disaster dressed up as a
            // feature. The Season tab is shown afterwards because that is where the arrival
            // is visible.
            .onOpenURL { url in
                store.receive(fileAt: url)
                tab = .season
            }
            // Nothing is torn down when the app leaves the screen. The Bluetooth link is
            // allowed to keep running while the app is suspended, which is the entire reason
            // it replaced Multipeer: a locked phone in a pocket goes on receiving the match.
            // This only picks the radio up again if it was never started.
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                peers?.appCameBack()
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
