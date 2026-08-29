// The stored-data version chain.
//
// It transforms an array of raw events and knows nothing about storage, so every branch is
// testable without a device. It works on raw events rather than decoded ones on purpose: a
// migration's whole job is to change the shape events are written in, and a decoder that
// already understood the new shape would have nothing to migrate.
import Foundation

/// The data format this build writes and understands.
public let schemaVersion = 3

/// The season a migrated log is gathered into. Renameable by the operator afterwards.
public let migratedSeasonId = "season-1"

/// What came back from a migration: a log, or a reason it could not be carried forward.
public enum MigrationResult: Equatable, Sendable {
    case carried([RawEvent])
    case refused(String)

    /// The events, or nil when the log was refused.
    public var events: [RawEvent]? {
        if case let .carried(events) = self { return events }
        return nil
    }

    /// Why the log was refused, or nil when it was carried.
    public var reason: String? {
        if case let .refused(reason) = self { return reason }
        return nil
    }
}

/// Carries an event log forward from `fromVersion` to the current version.
///
/// Never throws: a failure is a returned reason, because a corrupt or future log must not
/// take down the app on startup — the operator would be left with an app that will not
/// open and a season they cannot reach.
public func migrate(
    _ events: [RawEvent],
    from fromVersion: Int?,
    to targetVersion: Int = schemaVersion
) -> MigrationResult {
    guard let fromVersion, fromVersion >= 1 else {
        return .refused("Stored data has an unrecognised version (\(String(describing: fromVersion))).")
    }
    if fromVersion > targetVersion {
        return .refused("Stored data was written by a newer version of this app.")
    }

    var carried = events
    for version in fromVersion..<targetVersion {
        guard let step = migrationSteps[version] else {
            return .refused("No way to carry data forward from version \(version).")
        }
        carried = step(carried)
    }
    return .carried(carried)
}

/// Ordered steps. `migrationSteps[n]` upgrades a log at version n to version n+1.
/// Every step is pure and returns a new array.
// `@Sendable`: the table is a global constant, and Swift 6 will not let one hold functions
// that might close over shared state. These close over nothing at all -- they are pure --
// and saying so in the type is how the compiler is told.
let migrationSteps: [Int: @Sendable ([RawEvent]) -> [RawEvent]] = [
    1: migrateOneToTwo,
    2: migrateTwoToThree,
]

/// 1 → 2: release 002 only added event types, so a release-001 log is already valid.
/// Kept as the proof that the chain runs.
private func migrateOneToTwo(_ events: [RawEvent]) -> [RawEvent] {
    events
}

/// 2 → 3: the first migration that does real work.
///
/// Deliberately ADDITIVE. It prepends one season and stamps a field onto the events that
/// now need one. It renames nothing, splits nothing, and moves no event other than by the
/// single prepend.
///
/// The tidier migration would decompose each ADD_PLAYER into a career player plus a season
/// membership — two events where there was one. It matches the new model exactly and it is
/// far riskier: every index shifts, so a bug becomes silent corruption of the only real
/// season anyone has recorded, rather than a visibly wrong number.
///
/// An ended match becomes `undecided`, never `lost`. Silence is not a defeat, and a record
/// that assumed otherwise would be wrong about games already played.
private func migrateTwoToThree(_ events: [RawEvent]) -> [RawEvent] {
    let season: RawEvent = [
        "t": .string(EventType.createSeason),
        "id": .string(migratedSeasonId),
        "name": .string("Season 1"),
        "team": .string("My Team"),
        // The format releases 1 and 2 were played under, recorded so a later release can
        // vary it without touching stored data.
        "format": .object([
            "matchesPerGame": .number(3),
            "targetScore": .number(21),
            "playersOnCourt": .number(6),
        ]),
    ]

    let needsSeason: Set<String> = [
        EventType.addPlayer, EventType.editPlayer, EventType.removePlayer, EventType.startGame,
    ]

    let stamped = events.map { event -> RawEvent in
        guard let type = event["t"]?.stringValue else { return event }
        var next = event
        if needsSeason.contains(type) {
            next["seasonId"] = .string(migratedSeasonId)
        } else if type == EventType.endMatch {
            next["result"] = .string(MatchResult.undecided.rawValue)
        }
        return next
    }

    return [season] + stamped
}
