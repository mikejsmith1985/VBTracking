// The event log on disk.
//
// One append-only file of JSON lines, replayed on launch. Not SwiftData, not Core Data:
// those persist an object graph that is mutated, and this model is a log that is appended
// to and never updated. A file does that in one call, survives a crash after any complete
// line, and can be handed to a diff.
//
// This is the only type in the package that touches a filesystem.
import Foundation
import VBCore

/// What the store could not do, in words that can be shown to the operator.
public enum LogFileError: Error, Equatable, Sendable {
    case unreadable(String)
    case unwritable(String)

    /// The sentence to show. Never a stack trace: the operator is standing at a court.
    public var message: String {
        switch self {
        case let .unreadable(reason): "The saved log could not be read. \(reason)"
        case let .unwritable(reason): "That could not be saved. \(reason)"
        }
    }
}

/// The append-only log file.
public struct LogFile: Sendable {
    /// Where the log lives.
    public let url: URL

    /// Whether the last read found a line that was never finished being written.
    ///
    /// A crash between the write and the flush leaves one. Nothing is lost except the serve
    /// that was mid-write, and the operator is told rather than left to notice a missing
    /// point later.
    public private(set) var hadPartialLine = false

    public init(url: URL) {
        self.url = url
    }

    /// Every event in the file, in order.
    ///
    /// A file that is not there yet is not an error: it is an operator who has recorded
    /// nothing.
    public mutating func read() throws -> [RawEvent] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            hadPartialLine = false
            return []
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw LogFileError.unreadable(error.localizedDescription)
        }

        guard let contents = String(data: data, encoding: .utf8) else {
            throw LogFileError.unreadable("It is not text this app wrote.")
        }

        let result = LogFormat.read(contents)
        hadPartialLine = result.hadPartialLine
        return result.events
    }

    /// Appends one event.
    ///
    /// One write of one complete line, flushed before returning. A crash after this call
    /// keeps the event; a crash during it loses at most this one line, which the next read
    /// discards rather than guesses at.
    public func append(_ event: RawEvent) throws {
        try append([event])
    }

    /// Appends several events, in order, as one write.
    public func append(_ events: [RawEvent]) throws {
        guard !events.isEmpty else { return }
        let text = LogFormat.write(events)
        guard let data = text.data(using: .utf8) else {
            throw LogFileError.unwritable("The events could not be encoded.")
        }

        do {
            try ensureDirectory()
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.synchronize()
            } else {
                try data.write(to: url, options: .atomic)
            }
        } catch let error as LogFileError {
            throw error
        } catch {
            throw LogFileError.unwritable(error.localizedDescription)
        }
    }

    /// Removes the last event, which is what undo does.
    ///
    /// The only operation that takes a line away, and it is the same one the web app
    /// performs on its array: drop the last event and replay.
    public mutating func removeLast() throws {
        var events = try read()
        guard !events.isEmpty else { return }
        events.removeLast()
        try replace(with: events)
    }

    /// Replaces the whole log.
    ///
    /// Used by an import, which either lands in full or changes nothing — so the write is
    /// atomic: a crash part way through leaves the previous log, never half of each.
    public func replace(with events: [RawEvent]) throws {
        let text = LogFormat.write(events)
        guard let data = text.data(using: .utf8) else {
            throw LogFileError.unwritable("The events could not be encoded.")
        }
        do {
            try ensureDirectory()
            try data.write(to: url, options: .atomic)
        } catch let error as LogFileError {
            throw error
        } catch {
            throw LogFileError.unwritable(error.localizedDescription)
        }
    }

    private func ensureDirectory() throws {
        let directory = url.deletingLastPathComponent()
        guard !FileManager.default.fileExists(atPath: directory.path) else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw LogFileError.unwritable(error.localizedDescription)
        }
    }
}
