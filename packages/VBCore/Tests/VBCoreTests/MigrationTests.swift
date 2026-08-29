// The stored-data version chain. Ported from `tests/unit/migrations.test.js`.
//
// The rule these all serve: a migration is ADDITIVE. It prepends and stamps; it never
// renames, splits or reorders. A shifted index turns a bug into silent corruption of the
// only real season anyone has recorded.
import Testing

@testable import VBCore

private func raw(_ type: String, _ fields: [String: JSONValue] = [:]) -> RawEvent {
    var event: RawEvent = ["t": .string(type)]
    for (key, value) in fields { event[key] = value }
    return event
}

@Suite("Carrying a log forward")
struct MigrationTests {
    @Test("A log already at the current version is left exactly as it is")
    func currentVersionUntouched() {
        let events = [raw(EventType.recordServe, ["outcome": "IN_POINT"])]
        #expect(migrate(events, from: schemaVersion).events == events)
    }

    @Test("A version this build has never heard of is refused, not guessed at")
    func refusesNewerVersion() {
        let result = migrate([], from: schemaVersion + 1)
        #expect(result.reason?.contains("newer version") == true)
        #expect(result.events == nil)
    }

    @Test("A version that is not a version at all is refused")
    func refusesNonsenseVersion() {
        #expect(migrate([], from: nil).reason != nil)
        #expect(migrate([], from: 0).reason != nil)
    }

    @Test("Version 2 to 3 prepends exactly one season, and moves nothing else")
    func prependsOneSeason() {
        let events = [
            raw(EventType.addPlayer, ["id": "p1", "name": "Ella", "number": "7"]),
            raw(EventType.startGame, ["id": "g1"]),
            raw(EventType.recordServe, ["outcome": "IN_POINT"]),
        ]
        let carried = try? #require(migrate(events, from: 2).events)

        #expect(carried?.count == events.count + 1, "one prepend, nothing removed")
        #expect(carried?.first?["t"]?.stringValue == EventType.createSeason)
        #expect(carried?.first?["id"]?.stringValue == migratedSeasonId)
    }

    @Test("It stamps a season onto the events that now need one")
    func stampsSeason() {
        let events = [
            raw(EventType.addPlayer, ["id": "p1", "name": "Ella", "number": "7"]),
            raw(EventType.startGame, ["id": "g1"]),
        ]
        let carried = try? #require(migrate(events, from: 2).events)

        #expect(carried?[1]["seasonId"]?.stringValue == migratedSeasonId)
        #expect(carried?[2]["seasonId"]?.stringValue == migratedSeasonId)
    }

    @Test("It leaves every other event's fields exactly as they were")
    func leavesOtherEventsAlone() {
        let serve = raw(EventType.recordServe, ["outcome": "IN_POINT"])
        let carried = try? #require(migrate([serve], from: 2).events)

        #expect(carried?[1] == serve)
    }

    @Test("An ended match becomes undecided, never lost — silence is not a defeat")
    func endedMatchIsUndecided() {
        let carried = try? #require(migrate([raw(EventType.endMatch)], from: 2).events)
        #expect(carried?[1]["result"]?.stringValue == MatchResult.undecided.rawValue)
    }

    @Test("The whole chain runs from version 1")
    func runsTheWholeChain() {
        let carried = try? #require(migrate([raw(EventType.endMatch)], from: 1).events)

        #expect(carried?.count == 2, "the season is prepended once, not twice")
        #expect(carried?.first?["t"]?.stringValue == EventType.createSeason)
    }

    @Test("The migrated season records the format releases 1 and 2 were played under")
    func recordsLegacyFormat() {
        let carried = try? #require(migrate([], from: 2).events)
        let format = carried?.first?["format"]?.objectValue

        #expect(format?["matchesPerGame"]?.intValue == 3)
        #expect(format?["targetScore"]?.intValue == 21)
        #expect(format?["playersOnCourt"]?.intValue == 6)
    }

    @Test("Migrating is pure: the log it was given is unchanged")
    func doesNotMutateInput() {
        let events = [raw(EventType.addPlayer, ["id": "p1", "name": "Ella", "number": "7"])]
        _ = migrate(events, from: 2)

        #expect(events.first?["seasonId"] == nil, "the original was not stamped")
    }
}
