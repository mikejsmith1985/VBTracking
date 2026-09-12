// Reading and writing the backup file — the route the recorded season takes across.
//
// The rule every one of these serves: a backup that cannot be read leaves the device
// exactly as it was, and says why. Nothing is loaded in part.
import Foundation
import Testing

@testable import VBCore

/// A backup file as the shipped web app writes one.
private func backup(
    app: String = exportMarker,
    version: Int? = schemaVersion,
    events: [RawEvent] = [],
    exportedAt: String? = "2026-08-29T18:04:11.000Z"
) -> String {
    var file: [String: JSONValue] = [
        "app": .string(app),
        "events": .array(events.map { .object($0) }),
    ]
    if let version { file["schemaVersion"] = .number(Double(version)) }
    if let exportedAt { file["exportedAt"] = .string(exportedAt) }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = (try? encoder.encode(JSONValue.object(file))) ?? Data()
    return String(data: data, encoding: .utf8) ?? ""
}

private let oneServe: RawEvent = ["t": .string(EventType.recordServe), "outcome": "IN_POINT"]

@Suite("Reading a backup")
struct ReadBackupTests {
    @Test("A backup the web app wrote is read in full")
    func readsAWholeBackup() {
        let result = readBackup(backup(events: [oneServe]))
        #expect(result.log?.events.count == 1)
        #expect(result.log?.exportedAt == "2026-08-29T18:04:11.000Z")
    }

    @Test("Something that is not JSON is refused, and says so plainly")
    func refusesNonJSON() {
        #expect(readBackup("not a file at all").reason?.contains("not readable") == true)
    }

    @Test("A JSON file that is not ours is refused")
    func refusesForeignFile() {
        #expect(readBackup(#"{"app":"something-else","events":[]}"#).reason?.contains("not a Serve Tracker backup") == true)
    }

    @Test("A backup with no events at all is refused")
    func refusesEventless() {
        let text = #"{"app":"vbtracking","schemaVersion":3}"#
        #expect(readBackup(text).reason?.contains("no recorded data") == true)
    }

    @Test("A backup from a newer version of the app is refused, not guessed at")
    func refusesNewerSchema() {
        let result = readBackup(backup(version: schemaVersion + 1, events: [oneServe]))
        #expect(result.reason?.contains("newer version") == true)
        #expect(result.log == nil)
    }

    @Test("An older backup is carried forward rather than refused")
    func migratesOlderBackup() {
        let old: RawEvent = ["t": .string(EventType.addPlayer), "id": "p1", "name": "Ella", "number": "7"]
        let result = readBackup(backup(version: 2, events: [old]))

        let events = try? #require(result.log?.events)
        #expect(events?.count == 2, "the season is prepended")
        #expect(events?.first?["t"]?.stringValue == EventType.createSeason)
        #expect(events?.last?["seasonId"]?.stringValue == migratedSeasonId)
    }

    @Test("A backup with no version is refused rather than assumed to be current")
    func refusesVersionless() {
        #expect(readBackup(backup(version: nil, events: [oneServe])).reason != nil)
    }
}

@Suite("Naming events that arrive without a name")
struct EventNamingTests {
    @Test("Every event that arrives without an identifier is given one")
    func namesEveryEvent() {
        let result = readBackup(backup(events: [oneServe, oneServe]))
        let events = try? #require(result.log?.events)

        #expect(events?.allSatisfy { $0["eventId"]?.stringValue?.isEmpty == false } == true)
    }

    @Test("Two identical events in one log are still told apart")
    func distinguishesIdenticalEvents() {
        let result = readBackup(backup(events: [oneServe, oneServe]))
        let events = try? #require(result.log?.events)

        #expect(events?[0]["eventId"] != events?[1]["eventId"], "their place in the log differs")
    }

    @Test("An identifier the file already carries is left alone")
    func keepsExistingIdentifier() {
        var named = oneServe
        named["eventId"] = "already-named"
        let result = readBackup(backup(events: [named]))

        #expect(result.log?.events.first?["eventId"]?.stringValue == "already-named")
    }

    @Test("The same file always produces the same identifiers")
    func namesDeterministically() {
        // This is what makes a second import recognisable rather than a second season.
        // Swift's own Hasher is seeded per process and could not do this.
        let first = readBackup(backup(events: [oneServe, oneServe])).log
        let second = readBackup(backup(events: [oneServe, oneServe])).log

        #expect(first?.events.map { $0["eventId"] } == second?.events.map { $0["eventId"] })
    }
}

@Suite("Recognising a backup that is already in")
struct ImportIdempotenceTests {
    @Test("The same file fingerprints the same way twice")
    func stableFingerprint() {
        let text = backup(events: [oneServe])
        #expect(readBackup(text).log?.sourceHash == readBackup(text).log?.sourceHash)
    }

    @Test("A different file fingerprints differently")
    func differentFilesDiffer() {
        let one = readBackup(backup(events: [oneServe])).log?.sourceHash
        let two = readBackup(backup(events: [oneServe, oneServe])).log?.sourceHash

        #expect(one != two)
    }

    @Test("Two files holding the same events fingerprint alike, whatever else differs")
    func ignoresSurroundings() {
        // The exported-at stamp is not part of the record, so a second export of an
        // unchanged season is still the same season.
        let morning = readBackup(backup(events: [oneServe], exportedAt: "2026-08-29T08:00:00Z")).log
        let evening = readBackup(backup(events: [oneServe], exportedAt: "2026-08-29T20:00:00Z")).log

        #expect(morning?.sourceHash == evening?.sourceHash)
    }
}

@Suite("Writing a backup")
struct BuildBackupTests {
    @Test("It is written in the shape the web app reads")
    func writesTheWebAppsShape() throws {
        let text = buildBackup([oneServe], exportedAt: "2026-08-29T18:04:11.000Z")
        let data = try #require(text.data(using: .utf8))
        let file = try #require(JSONDecoder().decode(JSONValue.self, from: data).objectValue)

        #expect(file["app"]?.stringValue == exportMarker)
        #expect(file["schemaVersion"]?.intValue == schemaVersion)
        #expect(file["exportedAt"]?.stringValue == "2026-08-29T18:04:11.000Z")
        #expect(file["events"]?.arrayValue?.count == 1)
    }

    @Test("A log written here reads back here unchanged")
    func roundTrips() {
        let events = [oneServe, ["t": .string(EventType.endMatch), "result": "won"] as RawEvent]
        let text = buildBackup(events, exportedAt: "2026-08-29T18:04:11.000Z")
        let read = readBackup(text).log

        #expect(read?.events.count == 2)
        #expect(read?.events.last?["result"]?.stringValue == "won")
    }

    @Test("The filename says which day it was written")
    func namesTheFile() {
        #expect(backupFilename(on: "2026-08-29") == "vbtracking-backup-2026-08-29.json")
    }

    @Test("A season being handed over carries its own extension")
    func namesTheHandover() {
        #expect(seasonFilename(on: "2026-08-29") == "vbtracking-season-2026-08-29.vbseason")
    }

    @Test("A whole season survives a round trip with every figure intact")
    func roundTripsARealSeason() throws {
        // The proof that FR-038 is real: what this app writes, the web app can still read,
        // and the figures do not move on the way.
        let (events, version) = try Fixture.log("v2-log")
        let carried = try #require(migrate(events, from: version).events)
        let before = replay(raw: carried)

        let text = buildBackup(carried, exportedAt: "2026-08-29T18:04:11.000Z")
        let after = try #require(readBackup(text).log)

        #expect(replay(raw: after.events) == before)
    }
}
