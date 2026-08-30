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
        "CloudKit", "CKContainer", "CKDatabase",
        "Socket", "dataTask", "downloadTask", "uploadTask",
    ]

    /// The directories that ship. Tests are excluded: they are not in the app.
    private static let shippedDirectories = [
        "packages/VBCore/Sources",
        "ios/VBTracker",
        "ios/VBTrackerWatch",
        "ios/Shared",
    ]

    private var repository: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // VBCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // VBCore
            .deletingLastPathComponent()  // packages
            .deletingLastPathComponent()  // the repository
    }

    /// Every Swift file that ends up in one of the two apps.
    private func shippedFiles() -> [URL] {
        Self.shippedDirectories.flatMap { directory -> [URL] in
            let root = repository.appendingPathComponent(directory)
            guard let walker = FileManager.default.enumerator(atPath: root.path) else { return [] }
            return walker.compactMap { entry in
                guard let name = entry as? String, name.hasSuffix(".swift") else { return nil }
                return root.appendingPathComponent(name)
            }
        }
    }

    @Test("No shipped file so much as names a way to open a connection")
    func namesNoNetworkingAPI() throws {
        let files = shippedFiles()
        #expect(files.count > 20, "the files were found at all")

        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            let code = source
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")

            for api in Self.networkingAPIs {
                #expect(
                    !code.contains(api),
                    Comment(rawValue: "\(file.lastPathComponent) names \(api)")
                )
            }
        }
    }

    @Test("Nothing imports a networking framework")
    func importsNoNetworkingFramework() throws {
        let frameworks = ["import Network", "import CloudKit", "import CFNetwork", "import MultipeerConnectivity"]

        for file in shippedFiles() {
            let source = try String(contentsOf: file, encoding: .utf8)
            for framework in frameworks {
                #expect(
                    !source.contains(framework),
                    Comment(rawValue: "\(file.lastPathComponent) has \(framework)")
                )
            }
        }
    }

    @Test("The only link to another device is the one to the wrist, which is local")
    func theOnlyLinkIsLocal() throws {
        // WatchConnectivity is Bluetooth and Wi-Fi Direct between two paired devices. It
        // needs no router, no internet and no account -- which is why it is the one link
        // allowed here, and why turning the radios off entirely is not the test.
        let link = repository.appendingPathComponent("ios/Shared/Link/WatchConnectivitySession.swift")
        let source = try String(contentsOf: link, encoding: .utf8)

        #expect(source.contains("import WatchConnectivity"))
        #expect(!source.contains("URLSession"))
    }
}
