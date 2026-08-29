// Shared scaffolding for the VBCore suite.
//
// Ported alongside the tests it serves, from `tests/helpers.js` in the web app, so a test
// that reads the same in both languages is testing the same thing.
import Foundation
import Testing

@testable import VBCore

/// Builds an event with a deterministic identifier, so a test never depends on randomness.
func event(_ kind: Event.Kind, id: String = UUID().uuidString) -> Event {
    Event(id: id, kind: kind)
}

/// A roster of `count` players, numbered from one.
func roster(_ count: Int) -> [Event] {
    (1...count).map { index in
        event(.addPlayer(id: "p\(index)", name: "Player \(index)", number: "\(index)", seasonId: nil))
    }
}

/// One complete serve turn: `pointCount` points, then a serve that ends it.
func turn(_ playerId: String, points pointCount: Int, closing: Outcome = .out) -> [Event] {
    var events = [event(.selectServer(playerId: playerId))]
    events += (0..<pointCount).map { _ in event(.recordServe(outcome: .inPoint)) }
    events.append(event(.recordServe(outcome: closing)))
    return events
}

/// Replays a list of event groups, which is how a test reads best: `build(roster(3), started)`.
func build(_ groups: [Event]...) -> State {
    replay(groups.flatMap { $0 })
}

/// The reason the state would refuse this event, or nil.
func refusal(_ state: State, _ kind: Event.Kind) -> String? {
    rejectionReason(state, event(kind))
}

/// Applies one event to a state.
func apply(_ state: State, _ kind: Event.Kind) -> State {
    applyEvent(state, event(kind))
}

// MARK: - Fixtures

enum Fixture {
    /// The repository's own `tests/fixtures/`, found from this file's location.
    ///
    /// The golden files live in exactly one place, shared with the web app's suite. Copying
    /// them into a resource bundle would make a second copy that can drift, and these files
    /// are the format as shipped -- the one thing that must not be edited or duplicated.
    static var directory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // VBCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // VBCore
            .deletingLastPathComponent()  // packages
            .deletingLastPathComponent()  // the repository
            .appendingPathComponent("tests/fixtures")
    }

    /// Reads a golden file. These are logs captured from shipped builds of the web app.
    static func json(_ name: String) throws -> [String: JSONValue] {
        let url = directory.appendingPathComponent("\(name).json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([String: JSONValue].self, from: data)
    }

    /// The events of a stored log fixture, with the version it was written at.
    static func log(_ name: String) throws -> (events: [RawEvent], version: Int?) {
        let file = try json(name)
        let events = (file["events"]?.arrayValue ?? []).compactMap(\.objectValue)
        return (events, file["schemaVersion"]?.intValue)
    }
}
