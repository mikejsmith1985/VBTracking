// The log on disk: appended to, never rewritten, and honest about a line that was never
// finished.
//
// These run against a real filesystem in a temporary directory, on this workstation. The
// crash cases are the reason the store is a target of its own: they can be set up here by
// writing a half line, which is not something a device would let anyone arrange on purpose.
import Foundation
import Testing
import VBCore

@testable import VBStore

/// A log file in a temporary directory, removed when the test is done.
private func temporaryLog() -> (file: LogFile, cleanUp: () -> Void) {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("vbtracking-tests-\(UUID().uuidString)")
    let url = directory.appendingPathComponent("log.jsonl")

    return (LogFile(url: url), { try? FileManager.default.removeItem(at: directory) })
}

private let serve: RawEvent = [
    "eventId": "e1", "t": .string(EventType.recordServe), "outcome": "IN_POINT",
]
private let ended: RawEvent = [
    "eventId": "e2", "t": .string(EventType.endMatch), "result": "won",
]

@Suite("The log on disk")
struct LogFileTests {
    @Test("A log that does not exist yet is an operator who has recorded nothing")
    func missingFileIsEmpty() throws {
        var (file, cleanUp) = temporaryLog()
        defer { cleanUp() }

        #expect(try file.read().isEmpty)
    }

    @Test("An appended event reads back")
    func appendsAndReads() throws {
        var (file, cleanUp) = temporaryLog()
        defer { cleanUp() }

        try file.append(serve)
        #expect(try file.read() == [serve])
    }

    @Test("Events read back in the order they were appended")
    func keepsOrder() throws {
        var (file, cleanUp) = temporaryLog()
        defer { cleanUp() }

        try file.append(serve)
        try file.append(ended)

        #expect(try file.read().map { $0["eventId"]?.stringValue } == ["e1", "e2"])
    }

    @Test("Appending adds to the file rather than replacing it")
    func appendsRatherThanOverwrites() throws {
        var (file, cleanUp) = temporaryLog()
        defer { cleanUp() }

        try file.append([serve, ended])
        try file.append(serve)

        #expect(try file.read().count == 3)
    }

    @Test("Undo takes the last event away, and only the last")
    func removesTheLast() throws {
        var (file, cleanUp) = temporaryLog()
        defer { cleanUp() }

        try file.append([serve, ended])
        try file.removeLast()

        #expect(try file.read().map { $0["eventId"]?.stringValue } == ["e1"])
    }

    @Test("Undo on an empty log does nothing rather than failing")
    func removesNothingFromEmpty() throws {
        var (file, cleanUp) = temporaryLog()
        defer { cleanUp() }

        try file.removeLast()
        #expect(try file.read().isEmpty)
    }

    @Test("An import replaces the whole log in one write")
    func replacesWholeLog() throws {
        var (file, cleanUp) = temporaryLog()
        defer { cleanUp() }

        try file.append([serve, ended])
        try file.replace(with: [ended])

        #expect(try file.read() == [ended])
    }
}

@Suite("A log that was interrupted")
struct PartialWriteTests {
    /// Writes a file by hand, so a half-finished line can be arranged deliberately.
    private func write(_ contents: String, to file: LogFile) throws {
        try FileManager.default.createDirectory(
            at: file.url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: file.url, atomically: true, encoding: .utf8)
    }

    @Test("A line that was never finished is discarded, not guessed at")
    func discardsPartialLine() throws {
        var (file, cleanUp) = temporaryLog()
        defer { cleanUp() }

        // A crash between the write and the flush leaves exactly this.
        try write(LogFormat.line(for: serve) + "\n" + #"{"t":"RECORD_SER"#, to: file)

        let events = try file.read()
        #expect(events.count == 1, "everything complete is kept")
        #expect(file.hadPartialLine, "and the app is told what it lost")
    }

    @Test("A complete log reports no interruption")
    func completeLogIsClean() throws {
        var (file, cleanUp) = temporaryLog()
        defer { cleanUp() }

        try file.append([serve, ended])
        _ = try file.read()

        #expect(file.hadPartialLine == false)
    }

    @Test("A trailing newline is not an interruption")
    func trailingNewlineIsFine() throws {
        var (file, cleanUp) = temporaryLog()
        defer { cleanUp() }

        try write(LogFormat.line(for: serve) + "\n\n", to: file)
        _ = try file.read()

        #expect(file.hadPartialLine == false)
    }

    @Test("Damage in the middle stops the read there rather than loading half a season")
    func stopsAtDamage() throws {
        var (file, cleanUp) = temporaryLog()
        defer { cleanUp() }

        try write("{ not an event }\n" + LogFormat.line(for: ended) + "\n", to: file)

        let events = try file.read()
        #expect(events.isEmpty)
        #expect(file.hadPartialLine == false, "this is damage, not an interruption")
    }

    @Test("A file that is not text this app wrote is refused, not read")
    func refusesBinary() throws {
        var (file, cleanUp) = temporaryLog()
        defer { cleanUp() }

        try FileManager.default.createDirectory(
            at: file.url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([0xff, 0xfe, 0xfd]).write(to: file.url)

        #expect(throws: LogFileError.self) { _ = try file.read() }
    }
}

@Suite("What the log survives")
struct LogDurabilityTests {
    @Test("A log written, closed and reopened is the same log")
    func survivesReopening() throws {
        var (file, cleanUp) = temporaryLog()
        defer { cleanUp() }

        try file.append([serve, ended])

        var reopened = LogFile(url: file.url)
        #expect(try reopened.read() == [serve, ended])
    }

    @Test("Replaying the file gives the state the events describe")
    func replaysToState() throws {
        var (file, cleanUp) = temporaryLog()
        defer { cleanUp() }

        try file.append([
            ["eventId": "a", "t": .string(EventType.addPlayer), "id": "p1", "name": "Ella", "number": "7"],
            ["eventId": "b", "t": .string(EventType.startGame), "id": "g1"],
        ])

        let state = replay(raw: try file.read())
        #expect(state.roster.first?.name == "Ella")
        #expect(state.currentGame?.id == "g1")
    }
}
