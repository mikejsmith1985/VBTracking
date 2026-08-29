// swift-tools-version: 6.0
//
// The rulebook, and nothing else. VBCore has no DOM, no storage, no clock and no
// randomness, which is what lets it build and test on the Windows workstation where the
// rest of this app cannot even be compiled. Every rule that decides a figure lives here,
// so the part that matters keeps a fast loop.
import PackageDescription

let package = Package(
    name: "VBCore",
    products: [
        .library(name: "VBCore", targets: ["VBCore"]),
        .library(name: "VBStore", targets: ["VBStore"]),
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
    ]
)
