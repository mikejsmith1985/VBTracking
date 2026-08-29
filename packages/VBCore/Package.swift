// swift-tools-version: 6.0
//
// The rulebook, and nothing else. VBCore has no DOM, no storage, no clock and no
// randomness, which is what lets it build and test on the Windows workstation where the
// rest of this app cannot even be compiled. Every rule that decides a figure lives here,
// so the part that matters keeps a fast loop.
import PackageDescription

let package = Package(
    name: "VBCore",
    // Without these, SwiftPM assumes the oldest Apple platforms it has ever supported --
    // and refuses anything newer, including the JSON encoding options this package relies
    // on to write a log the same way twice. Windows has no such floor, so the mistake only
    // appears on a Mac. These match the app's own deployment targets.
    platforms: [.macOS(.v13), .iOS(.v18), .watchOS(.v11)],
    products: [
        .library(name: "VBCore", targets: ["VBCore"]),
        .library(name: "VBStore", targets: ["VBStore"]),
        .library(name: "VBPresentation", targets: ["VBPresentation"]),
    ],
    targets: [
        .target(
            name: "VBCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // The one place that touches a disk. It is a target of its own so that `VBCore`
        // can keep its promise of having no I/O in it at all -- and so that the rules about
        // a half-written line stay testable on a machine with no device attached.
        .target(
            name: "VBStore",
            dependencies: ["VBCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // What the screens would otherwise decide for themselves.
        //
        // There is no Mac here, so a SwiftUI view cannot be run, let alone tested. Every
        // decision a view would make -- what a figure reads as, how big a box is, what the
        // dock is showing -- is made here instead, where it can be tested in a fast loop.
        // What is left in the view is arrangement.
        .target(
            name: "VBPresentation",
            dependencies: ["VBCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "VBCoreTests",
            dependencies: ["VBCore"],
            // No resource bundle. The golden files live once, in `tests/fixtures/`, and
            // the tests read them from there by a path derived from their own source
            // location -- a second copy inside this target is a second copy that can
            // drift, and these files are the format as shipped.
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "VBStoreTests",
            dependencies: ["VBStore", "VBCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "VBPresentationTests",
            dependencies: ["VBPresentation", "VBCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
