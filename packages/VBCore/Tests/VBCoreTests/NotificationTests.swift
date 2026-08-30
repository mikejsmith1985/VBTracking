// The coach's own notifications are not this app's to take.
//
// A watch app that wants to hold the screen, or buzz on a beat, is one step away from
// asking for an extended runtime session. Several of those session types -- mindfulness and
// its neighbours -- suppress the wearer's notifications for their duration, which would
// trade a rotation reminder for every text message and doorbell camera alert of the evening.
//
// This app buzzes with a plain timer while it is on screen, which needs no session at all.
// So the rule is simply that no shipped file may name one, and it is checked on every run
// rather than remembered by whoever writes the next feature.
import Foundation
import Testing

@testable import VBCore

@Suite("Nothing in this app can silence the wearer")
struct NotificationTests {
    /// Everything that would let a line of code quiet, defer or take over notifications.
    ///
    /// Written as plain text rather than as a linter rule because the point is for somebody
    /// deciding whether to add one to read it. The list is the argument.
    private static let silencingAPIs = [
        "WKExtendedRuntimeSession",
        "WKExtendedRuntimeSessionDelegate",
        "HKWorkoutSession",
        "isIdleTimerDisabled",
        "setInterruptionLevel",
        "UNUserNotificationCenter",
        "INFocusStatusCenter",
        "requestAuthorization",
    ]

    @Test("No shipped file so much as names a way to take over notifications")
    func namesNoSilencingAPI() throws {
        let files = ShippedSources.files()
        #expect(files.count > 20, "the files were found at all")

        for file in files {
            let code = try ShippedSources.code(of: file)
            // Reading nothing at all looks exactly like a clean bill of health, so the
            // scan proves it read something before it decides the file is clean.
            #expect(
                ShippedSources.isReadable(code),
                Comment(rawValue: "nothing was read out of \(file.lastPathComponent)")
            )

            for api in Self.silencingAPIs {
                #expect(
                    !code.contains(api),
                    Comment(rawValue: "\(file.lastPathComponent) names \(api)")
                )
            }
        }
    }

    @Test("Nothing imports a framework that could")
    func importsNoSilencingFramework() throws {
        let frameworks = ["import UserNotifications", "import HealthKit", "import Intents"]

        for file in ShippedSources.files() {
            let source = try String(contentsOf: file, encoding: .utf8)
            for framework in frameworks {
                #expect(
                    !source.contains(framework),
                    Comment(rawValue: "\(file.lastPathComponent) has \(framework)")
                )
            }
        }
    }

    @Test("The rotate alert buzzes on a plain timer, which needs no session")
    func theAlertUsesATimer() throws {
        let alert = ShippedSources.repository.appendingPathComponent("ios/VBTrackerWatch/RotateAlert.swift")
        let code = try ShippedSources.code(of: alert)

        #expect(code.contains("Timer.publish"), "the beat")
        #expect(code.contains("WKInterfaceDevice.current().play"), "the buzz")
        #expect(!code.contains("WKExtendedRuntimeSession"))
    }
}

