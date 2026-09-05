// The app must work in a gym with no usable network, and the way it does that is by having
// no networking in it at all.
//
// This replaces a manual aeroplane-mode run, which was both dropped by the stakeholder and
// the wrong test anyway: aeroplane mode turns off Bluetooth, and Bluetooth is how the watch
// hears the phone. It would have proved the app works offline by breaking the one link the
// release exists for.
//
// So it is checked here instead, on every run, by reading the source: an app that cannot
// name a networking API cannot call one.
import Foundation
import Testing

@testable import VBCore

@Suite("Nothing in this app can reach the network")
struct OfflineTests {
    /// Everything that would let a line of code open a connection.
    ///
    /// Written as plain text rather than as a linter rule because the point is for somebody
    /// deciding whether to add one to read it. The list is the argument.
    private static let networkingAPIs = [
        "URLSession", "URLRequest", "URLConnection", "NSURLConnection",
        "NWConnection", "NWBrowser", "NWListener", "CFNetwork",
        "CloudKit", "CKContainer", "CKDatabase", "NSUbiquitousKeyValueStore",
        "Socket", "dataTask", "downloadTask", "uploadTask",
    ]

    @Test("No shipped file so much as names a way to open a connection")
    func namesNoNetworkingAPI() throws {
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

            for api in Self.networkingAPIs {
                #expect(
                    !code.contains(api),
                    Comment(rawValue: "\(file.lastPathComponent) names \(api)")
                )
            }
        }
    }

    /// The frameworks that reach the internet. None of these is ever allowed anywhere.
    private static let internetFrameworks = ["import Network", "import CloudKit", "import CFNetwork"]

    /// The frameworks that reach another device in the same room, and the one file each is
    /// allowed in.
    ///
    /// Offline means no internet, not no radios. Both of these are peer to peer: no router,
    /// no account, no server, and nothing that works at a distance. They are still confined
    /// to a single file apiece, so adding a second use is a decision somebody has to make
    /// here, in front of this comment, rather than one that happens quietly.
    private static let localFrameworks = [
        "import WatchConnectivity": "WatchConnectivitySession.swift",
        "import CoreBluetooth": "BluetoothSession.swift",
    ]

    @Test("Nothing imports a framework that reaches the internet")
    func importsNoNetworkingFramework() throws {
        for file in ShippedSources.files() {
            let source = try String(contentsOf: file, encoding: .utf8)
            for framework in Self.internetFrameworks {
                #expect(
                    !source.contains(framework),
                    Comment(rawValue: "\(file.lastPathComponent) has \(framework)")
                )
            }
        }
    }

    @Test("A radio that reaches the next device is confined to the one file that owns it")
    func keepsEachLocalLinkInItsOwnFile() throws {
        for file in ShippedSources.files() {
            let source = try String(contentsOf: file, encoding: .utf8)
            for (framework, owner) in Self.localFrameworks where source.contains(framework) {
                #expect(
                    file.lastPathComponent == owner,
                    Comment(rawValue: "\(file.lastPathComponent) has \(framework); only \(owner) may")
                )
            }
        }
    }

    @Test("The phone-to-phone link reaches the next phone and nothing further")
    func thePeerLinkIsLocal() throws {
        // Core Bluetooth is a radio between two devices in
        // the same room. It needs no router, no internet and no account -- which is the whole
        // reason it is the way a season reaches a second phone, rather than a server.
        let peer = ShippedSources.repository
            .appendingPathComponent("ios/VBTracker/Link/BluetoothSession.swift")
        let source = try String(contentsOf: peer, encoding: .utf8)

        #expect(source.contains("import CoreBluetooth"))
        for api in Self.networkingAPIs {
            #expect(!source.contains(api), Comment(rawValue: "the peer link names \(api)"))
        }
    }

    @Test("The only link to another device is the one to the wrist, which is local")
    func theOnlyLinkIsLocal() throws {
        // WatchConnectivity is Bluetooth and Wi-Fi Direct between two paired devices. It
        // needs no router, no internet and no account -- which is why it is the one link
        // allowed here, and why turning the radios off entirely is not the test.
        let link = ShippedSources.repository
            .appendingPathComponent("ios/Shared/Link/WatchConnectivitySession.swift")
        let source = try String(contentsOf: link, encoding: .utf8)

        #expect(source.contains("import WatchConnectivity"))
        #expect(!source.contains("URLSession"))
    }
}
