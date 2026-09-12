// Moving a season between the web app and this one.
//
// The route is the backup file the shipped web app already writes: no new capability on the
// web side, no network, and the same file readable in both directions. What is here is the
// whole of it except the writing to disk — parsing, migrating, naming events, and
// recognising a file that is already in.
//
// Every failure is a returned reason. A backup that cannot be read must leave the device
// exactly as it was, and say why in words the operator can act on.
import Foundation

/// Marks a file as one of ours, so an unrelated JSON file is refused rather than loaded.
public let exportMarker = "vbtracking"

/// What came back from reading a backup file.
public enum ImportResult: Equatable, Sendable {
    case ready(ImportedLog)
    case refused(String)

    /// The log, or nil when the file was refused.
    public var log: ImportedLog? {
        if case let .ready(log) = self { return log }
        return nil
    }

    /// Why the file was refused, or nil when it was read.
    public var reason: String? {
        if case let .refused(reason) = self { return reason }
        return nil
    }
}

/// A backup that has been read, migrated, and named, but not yet written anywhere.
public struct ImportedLog: Equatable, Sendable {
    /// The events, carried forward to the current schema and each given an identifier.
    public var events: [RawEvent]

    /// Recognises this exact backup on a second attempt, so a season cannot be doubled.
    public var sourceHash: String

    /// When the web app said it wrote the file, if it said.
    public var exportedAt: String?

    public init(events: [RawEvent], sourceHash: String, exportedAt: String?) {
        self.events = events
        self.sourceHash = sourceHash
        self.exportedAt = exportedAt
    }
}

/// Reads a backup file.
///
/// Never throws, and never loads part of a file: a backup is read in full or refused. The
/// wording of each refusal is carried over from the web app because the operator has
/// already read it in a gym.
public func readBackup(_ text: String) -> ImportResult {
    guard let data = text.data(using: .utf8),
        let decoded = try? JSONDecoder().decode(JSONValue.self, from: data),
        let file = decoded.objectValue
    else {
        return .refused("That file is not readable. It may be damaged or incomplete.")
    }

    guard file["app"]?.stringValue == exportMarker else {
        return .refused("That file is not a Serve Tracker backup.")
    }
    guard let rawEvents = file["events"]?.arrayValue else {
        return .refused("That backup has no recorded data in it.")
    }

    let events = rawEvents.compactMap(\.objectValue)
    let carried = migrate(events, from: file["schemaVersion"]?.intValue)
    guard let migrated = carried.events else {
        return .refused(carried.reason ?? "That backup could not be carried forward.")
    }

    let identified = migrated.enumerated().map { index, event in
        named(event, at: index)
    }

    return .ready(
        ImportedLog(
            events: identified,
            sourceHash: fingerprint(of: identified),
            exportedAt: file["exportedAt"]?.stringValue
        )
    )
}

/// Builds a backup file in the shape the web app writes and reads.
///
/// Byte-compatible with that parser on purpose: it is what lets both apps read the same
/// season while the native app is still being built out.
public func buildBackup(_ events: [RawEvent], exportedAt: String) -> String {
    let payload: JSONValue = .object([
        "app": .string(exportMarker),
        "schemaVersion": .number(Double(schemaVersion)),
        "exportedAt": .string(exportedAt),
        "events": .array(events.map { .object($0) }),
    ])

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    guard let data = try? encoder.encode(payload), let text = String(data: data, encoding: .utf8) else {
        return "{}"
    }
    return text
}

/// A filename the operator can recognise among several backups.
public func backupFilename(on day: String) -> String {
    "vbtracking-backup-\(day).json"
}

/// The extension on a season being handed to another phone.
///
/// Its own extension rather than `.json`, so the receiving phone can offer this app by name
/// when the file arrives. A backup keeps `.json` because the web app reads those, and the
/// two files hold identical bytes -- only the name differs.
public let seasonFileExtension = "vbseason"

/// A filename for a season being passed to somebody else.
public func seasonFilename(on day: String) -> String {
    "vbtracking-season-\(day).\(seasonFileExtension)"
}

// MARK: - Naming events

/// Gives an event an identifier if it does not have one.
///
/// Events written by the web app have none. The identifier is derived from the event's
/// place in the log and its own content, so importing the same file twice produces the
/// same identifiers — which is what stops a second import from doubling a season.
func named(_ event: RawEvent, at index: Int) -> RawEvent {
    if event["eventId"]?.stringValue?.isEmpty == false { return event }
    var next = event
    next["eventId"] = .string("i\(index)-\(fingerprint(of: [event]))")
    return next
}

// MARK: - Fingerprinting

/// A short, stable fingerprint of a log.
///
/// FNV-1a over the canonical encoding. This answers one question — "have I seen this exact
/// file before?" — and nothing about it is a security claim. Swift's own `Hasher` cannot be
/// used: it is seeded differently in every process, so it would give a different answer to
/// the same file tomorrow, and the whole point is that it does not.
public func fingerprint(of events: [RawEvent]) -> String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    let prime: UInt64 = 0x1000_0000_01b3

    for byte in canonical(events) {
        hash ^= UInt64(byte)
        hash = hash &* prime
    }
    return String(hash, radix: 16)
}

/// The canonical bytes of a log: keys in sorted order, so two encodings of the same events
/// are the same bytes.
private func canonical(_ events: [RawEvent]) -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return (try? encoder.encode(events.map { JSONValue.object($0) })) ?? Data()
}

// MARK: - Deciding whether to import at all

/// Refuses a backup that has already been imported.
///
/// Kept apart from reading the file because it is a different question: reading asks
/// whether the file is any good, this asks whether the season is already here. Pure — the
/// caller supplies what it has seen — so the rule is testable without a device.
public func decideImport(_ result: ImportResult, alreadyImported hashes: Set<String>) -> ImportResult {
    guard let log = result.log else { return result }
    guard !hashes.contains(log.sourceHash) else {
        return .refused("That backup is already in. Nothing was changed.")
    }
    return result
}
