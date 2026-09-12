// What has already been imported.
//
// One small file beside the log. It exists so that importing the same backup twice is
// recognised rather than doubling a season -- the single mistake an operator is most likely
// to make with a file they have kept in Files and might tap again next week.
import Foundation
import VBCore

/// One import that landed.
public struct ImportEntry: Equatable, Codable, Sendable {
    /// The fingerprint of the log that was imported.
    public var sourceHash: String

    /// When it landed, so the operator can see what happened and when.
    public var importedAt: String

    /// How many events came in, for the same reason.
    public var eventCount: Int

    public init(sourceHash: String, importedAt: String, eventCount: Int) {
        self.sourceHash = sourceHash
        self.importedAt = importedAt
        self.eventCount = eventCount
    }
}

/// The record of every import that has landed on this device.
public struct ImportLedger: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// Every import so far. A missing ledger is a device that has imported nothing, which
    /// is not an error.
    public func entries() -> [ImportEntry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([ImportEntry].self, from: data)) ?? []
    }

    /// The fingerprints already seen, in the shape `decideImport` wants.
    public func knownHashes() -> Set<String> {
        Set(entries().map(\.sourceHash))
    }

    /// Forgets every import.
    ///
    /// Only for erasing everything. The ledger exists so the same backup cannot be imported
    /// twice and double a season; once there is no season left, a ledger that still
    /// remembers would refuse the operator the only file that puts their data back.
    public func forget() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw LogFileError.unwritable(error.localizedDescription)
        }
    }

    /// Records an import that has landed.
    ///
    /// Written after the log itself, never before: a ledger that claimed an import the log
    /// does not hold would refuse the operator their own season.
    public func record(_ entry: ImportEntry) throws {
        var all = entries()
        all.append(entry)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let directory = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            try encoder.encode(all).write(to: url, options: .atomic)
        } catch {
            throw LogFileError.unwritable(error.localizedDescription)
        }
    }
}
