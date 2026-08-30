// Every Swift file that ends up in one of the two apps.
//
// Two different rules are enforced by reading the source rather than by running it -- that
// nothing can reach the network, and that nothing can mute the wearer's notifications --
// and both need the same list of files, so the list lives here.
import Foundation

enum ShippedSources {
    /// The directories that ship. Tests are excluded: they are not in the app.
    static let directories = [
        "packages/VBCore/Sources",
        "ios/VBTracker",
        "ios/VBTrackerWatch",
        "ios/Shared",
    ]

    static var repository: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // VBCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // VBCore
            .deletingLastPathComponent()  // packages
            .deletingLastPathComponent()  // the repository
    }

    static func files() -> [URL] {
        directories.flatMap { directory -> [URL] in
            let root = repository.appendingPathComponent(directory)
            guard let walker = FileManager.default.enumerator(atPath: root.path) else { return [] }
            return walker.compactMap { entry in
                guard let name = entry as? String, name.hasSuffix(".swift") else { return nil }
                return root.appendingPathComponent(name)
            }
        }
    }

    /// A file's source with its comment lines removed, so a rule written *about* an API in
    /// a comment does not read as a use of it.
    ///
    /// Split on whatever the line ending happens to be, never on "\n" alone. On a Windows
    /// checkout these files are CRLF, and Swift counts "\r\n" as ONE character -- so a split
    /// on "\n" found no breaks at all, handed back a single line that began with the file's
    /// own header comment, and dropped it. Every rule built on this was reading an empty
    /// string and passing because of it.
    static func code(of file: URL) throws -> String {
        try String(contentsOf: file, encoding: .utf8)
            .split(whereSeparator: \.isNewline)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Proof that the stripping above left something to read.
    ///
    /// Any rule that scans the source is only as good as this, and reading nothing at all
    /// looks exactly like a clean bill of health.
    static func isReadable(_ code: String) -> Bool {
        code.contains("import ")
    }
}
