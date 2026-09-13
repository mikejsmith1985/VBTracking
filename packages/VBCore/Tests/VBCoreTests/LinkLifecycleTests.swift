// When the phone-to-phone link is switched on, checked by reading the screen that switches it.
//
// This exists because of one bug that cost a whole match. Listening for another phone was
// started from `onAppear`, and the link itself is built in the app root's `task` -- which
// runs after the view appears. So on a cold launch `onAppear` found nothing, listening never
// started, and nothing ever fired it again.
//
// It passed every test at a desk because a phone that has been backgrounded and reopened gets
// a scene-phase change, which starts it. A phone opened fresh at a gym does not. Nothing but
// reading the source catches that, so the source is read.
import Foundation
import Testing

@testable import VBCore

@Suite("Switching the link on")
struct LinkLifecycleTests {
    private static func source(_ path: String) throws -> String {
        try String(contentsOf: ShippedSources.repository.appendingPathComponent(path), encoding: .utf8)
    }

    @Test("Listening does not depend on the screen appearing before the link exists")
    func doesNotListenFromAppearAlone() throws {
        let screen = try Self.source("ios/VBTracker/Track/TrackScreen.swift")
        guard screen.contains("listen()") else { return }

        // `onAppear` fires once, before the link is built, and never again. Whatever starts
        // listening has to be keyed on the link existing.
        #expect(
            !screen.contains(".onAppear { peers?.listen() }"),
            "onAppear runs before the link exists, so this starts nothing on a cold launch"
        )
        #expect(
            screen.contains(".task(id: peers == nil)"),
            "listening must start when the link arrives, not only when the screen does"
        )
    }

    @Test("Whatever starts listening also stops it")
    func stopsWhatItStarts() throws {
        let screen = try Self.source("ios/VBTracker/Track/TrackScreen.swift")
        guard screen.contains("listen()") else { return }

        // A radio left scanning on a tab nobody is looking at is a battery nobody can explain.
        #expect(screen.contains("stopListening()"))
        #expect(screen.contains(".onDisappear"), "released when the screen goes, not on a timer")
    }

    @Test("The match is advertised only once the service behind it is registered")
    func advertisesAfterTheServiceIsAdded() throws {
        let radio = try Self.source("ios/VBTracker/Link/BluetoothSession.swift")

        // Advertising a service iOS has not finished registering means a phone can find the
        // advertisement and then find nothing behind it. Apple's own rule, and it was broken.
        #expect(radio.contains("didAdd service"), "advertising waits for the service to land")

        let addIndex = radio.range(of: "manager.add(service)")?.lowerBound
        let advertiseIndex = radio.range(of: "manager.startAdvertising")?.lowerBound
        guard let addIndex, let advertiseIndex else {
            return #expect(Bool(false), "the radio must both add a service and advertise it")
        }
        #expect(addIndex < advertiseIndex, "the service is added before anything is advertised")
    }

    @Test("Sharing is reachable before the first serve")
    func offersSharingBeforeAMatch() throws {
        let screen = try Self.source("ios/VBTracker/Track/TrackScreen.swift")

        // Two people set up before a match, not during one. Sharing that appeared only once
        // a game was running meant arriving at a gym with nothing to tap.
        let beforeAMatch = screen.components(separatedBy: "currentMatch == nil")
        #expect(beforeAMatch.count > 1, "the screen still has a before-the-match state")
        #expect(
            beforeAMatch[1].prefix(600).contains("MatchSharing"),
            "sharing must be offered before a game is running, not only during one"
        )
    }
}
