// Two things this app does not take: the coach's notifications, and anybody's money.
//
// Both are rules about restraint rather than about behaviour, which means nothing fails if
// they are broken -- the app simply becomes a worse thing to have installed. So both are
// checked by reading the source on every run, rather than remembered by whoever writes the
// next feature.
//
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
        "setInterruptionLevel",
        "UNUserNotificationCenter",
        "INFocusStatusCenter",
        "requestAuthorization",
    ]

    /// Holding the phone's screen awake. Allowed in exactly one file, which must also give
    /// it back.
    ///
    /// Not on the list above, because on a phone it suppresses nothing -- it keeps the
    /// display lit and no notification is affected. The rule that list enforces is about the
    /// WATCH, where holding the screen means an extended runtime session, and several of
    /// those suppress the wearer's notifications for their duration.
    ///
    /// So it is confined rather than banned: one file, which is the board somebody props up
    /// beside the court, and that file has to release it too. Holding it for as long as a
    /// phone was receiving was tried and taken straight back out -- a phone that goes in a
    /// pocket with the screen still lit is the exact thing this rule exists to stop.
    private static let screenHoldOwner = "SidelineScreen.swift"

    @Test("Holding the screen awake is confined to the one screen that does it")
    func confinesTheScreenHold() throws {
        for file in ShippedSources.files() {
            let code = try ShippedSources.code(of: file)
            guard code.contains("isIdleTimerDisabled") else { continue }
            #expect(
                file.lastPathComponent == Self.screenHoldOwner,
                Comment(rawValue: "\(file.lastPathComponent) holds the screen; only \(Self.screenHoldOwner) may")
            )
        }
    }

    @Test("Whatever holds the screen gives it back")
    func givesTheScreenBack() throws {
        let owner = ShippedSources.files().first { $0.lastPathComponent == Self.screenHoldOwner }
        guard let owner else { return }

        let code = try ShippedSources.code(of: owner)
        // A phone that stays lit after somebody puts it away is a flat battery by the third
        // set, and nothing on screen would say why.
        #expect(code.contains("isIdleTimerDisabled = true"))
        #expect(code.contains("isIdleTimerDisabled = false"), "the screen must be released again")
        #expect(code.contains("onDisappear"), "released when the screen goes away, not on a timer")
    }

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


// MARK: - Being paid

@Suite("Nothing in this app takes money")
struct PaymentTests {
    /// Everything that would let the app collect a payment itself.
    ///
    /// A free app may be thanked, but only outside itself: Apple's rules leave exactly one
    /// lawful route, which is a link out to the browser. A payment field of our own would be
    /// rejected, and taking card details in an app that has no networking would be a lie
    /// twice over.
    private static let paymentAPIs = [
        "PKPayment", "PassKit", "StoreKit", "SKPayment", "SKProduct",
        "Product.purchase", "AppStore.sync", "cardNumber", "creditCard",
    ]

    @Test("No shipped file so much as names a way to take a payment")
    func namesNoPaymentAPI() throws {
        for file in ShippedSources.files() {
            let code = try ShippedSources.code(of: file)
            #expect(
                ShippedSources.isReadable(code),
                Comment(rawValue: "nothing was read out of \(file.lastPathComponent)")
            )

            for api in Self.paymentAPIs {
                #expect(
                    !code.contains(api),
                    Comment(rawValue: "\(file.lastPathComponent) names \(api)")
                )
            }
        }
    }

    @Test("Nothing imports a framework that could")
    func importsNoPaymentFramework() throws {
        let frameworks = ["import StoreKit", "import PassKit"]

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

    @Test("The thank-you is a link handed to the browser, and nothing more")
    func theTipJarIsALink() throws {
        let about = ShippedSources.repository
            .appendingPathComponent("ios/VBTracker/Season/AboutScreen.swift")
        let code = try ShippedSources.code(of: about)

        #expect(code.contains("Link(destination:"), "the browser takes over from here")
        #expect(code.contains("TextField") == false, "nothing on this screen collects anything")
        #expect(code.contains("SecureField") == false)
    }

    @Test("The address it points at is set, and is https")
    func theAddressIsReal() throws {
        // The screen hides the whole section rather than show a dead button, which means a
        // blanked address would ship silently as an app with no tip jar. This is what
        // notices.
        let about = ShippedSources.repository
            .appendingPathComponent("ios/VBTracker/Season/AboutScreen.swift")
        let code = try ShippedSources.code(of: about)

        #expect(code.contains("SupportLink(\"https://"), "an unset or plain-http address")
    }
}

@Suite("The scoreboard draws its own controls")
struct ScoreScreenStyleTests {
    @Test("Nothing on the scoreboard is left to the bordered style's own height")
    func nothingIsBordered() throws {
        // watchOS's bordered style has a control height of its own and ignores a frame asked
        // for inside it. That is what put the side's name outside its pill and left the
        // minus nearly as tall as the score, and a number in ScoreLayout cannot govern a
        // shape somebody else is sizing.
        let screen = ShippedSources.repository
            .appendingPathComponent("ios/VBTrackerWatch/ScoreScreen.swift")
        let code = try ShippedSources.code(of: screen)

        #expect(ShippedSources.isReadable(code))
        #expect(code.contains(".buttonStyle(.bordered)") == false, "the sizes stop being ours")
        #expect(code.contains("ScoreLayout."), "the sizes come from one place")
    }
}
