// Importing the same backup twice must be recognised, not doubled.
//
// This is the mistake an operator is most likely to make: the backup lives in Files, and
// tapping it again next week is one tap away.
import Foundation
import Testing
import VBCore

@testable import VBStore

private func temporaryLedger() -> (ledger: ImportLedger, cleanUp: () -> Void) {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("vbtracking-ledger-\(UUID().uuidString)")
    let url = directory.appendingPathComponent("imports.json")
    return (ImportLedger(url: url), { try? FileManager.default.removeItem(at: directory) })
}

private let entry = ImportEntry(
    sourceHash: "abc123",
    importedAt: "2026-08-29T18:04:11Z",
    eventCount: 412
)

@Suite("The record of what has been imported")
struct ImportLedgerTests {
    @Test("A device that has imported nothing has an empty ledger, not an error")
    func startsEmpty() {
        let (ledger, cleanUp) = temporaryLedger()
        defer { cleanUp() }

        #expect(ledger.entries().isEmpty)
        #expect(ledger.knownHashes().isEmpty)
    }

    @Test("An import that landed is recorded with what it was and when")
    func recordsAnImport() throws {
        let (ledger, cleanUp) = temporaryLedger()
        defer { cleanUp() }

        try ledger.record(entry)

        #expect(ledger.entries() == [entry])
        #expect(ledger.knownHashes() == ["abc123"])
    }

    @Test("Several imports are all kept, in the order they landed")
    func keepsEveryImport() throws {
        let (ledger, cleanUp) = temporaryLedger()
        defer { cleanUp() }

        try ledger.record(entry)
        try ledger.record(ImportEntry(sourceHash: "def456", importedAt: "2026-09-01T10:00:00Z", eventCount: 9))

        #expect(ledger.entries().map(\.sourceHash) == ["abc123", "def456"])
    }

    @Test("A damaged ledger reads as empty rather than stopping the app")
    func toleratesDamage() throws {
        let (ledger, cleanUp) = temporaryLedger()
        defer { cleanUp() }

        try FileManager.default.createDirectory(
            at: ledger.url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "not a ledger".write(to: ledger.url, atomically: true, encoding: .utf8)

        // Worst case the operator is offered an import they have already done. That is a
        // duplicate they can see and remove; an app that will not open is not.
        #expect(ledger.entries().isEmpty)
    }
}

@Suite("Refusing a backup that is already in")
struct ImportDecisionTests {
    private let log = ImportedLog(events: [], sourceHash: "abc123", exportedAt: nil)

    @Test("A backup never seen before is allowed through")
    func allowsNewBackup() {
        let decision = decideImport(.ready(log), alreadyImported: [])
        #expect(decision.log?.sourceHash == "abc123")
    }

    @Test("A backup already imported is refused, and says nothing was changed")
    func refusesRepeat() {
        let decision = decideImport(.ready(log), alreadyImported: ["abc123"])
        #expect(decision.reason == "That backup is already in. Nothing was changed.")
    }

    @Test("A file that was already refused stays refused, with its own reason")
    func keepsTheOriginalRefusal() {
        let decision = decideImport(.refused("That file is not readable."), alreadyImported: ["abc123"])
        #expect(decision.reason == "That file is not readable.")
    }

    @Test("A different backup is not mistaken for one already in")
    func allowsDifferentBackup() {
        let decision = decideImport(.ready(log), alreadyImported: ["something-else"])
        #expect(decision.log != nil)
    }
}

@Suite("Forgetting every import")
struct ImportLedgerForgettingTests {
    /// Erasing everything must also erase the memory of what was imported.
    ///
    /// Otherwise the operator wipes the app, reaches for the backup they just made, and is
    /// told it is already in -- with nothing on screen to show for it.
    @Test("A forgotten ledger accepts the same backup again")
    func forgettingLetsTheSameFileBack() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ledger-forget-\(UUID().uuidString)")
        let ledger = ImportLedger(url: directory.appendingPathComponent("imports.json"))

        try ledger.record(ImportEntry(sourceHash: "abc", importedAt: "2026-09-03", eventCount: 3))
        #expect(ledger.knownHashes() == ["abc"])

        try ledger.forget()
        #expect(ledger.knownHashes().isEmpty)

        // And forgetting a ledger that was never written is not an error: a device that has
        // imported nothing is the ordinary case.
        try ledger.forget()
    }
}
