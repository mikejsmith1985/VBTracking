// Scaffolding shared by the presentation suite.
//
// The same shapes the VBCore suite uses, kept here rather than imported: a test target
// cannot import another test target, and duplicating four small builders is cheaper than a
// fixtures module that both would have to depend on.
import Foundation
import Testing
import VBCore

/// An event with a fresh identifier, so a test never depends on randomness that matters.
func event(_ kind: Event.Kind) -> Event {
    Event(id: UUID().uuidString, kind: kind)
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

/// Replays a list of event groups, which is how a test reads best.
func build(_ groups: [Event]...) -> AppState {
    replay(groups.flatMap { $0 })
}

/// Applies one event to a state.
func apply(_ state: AppState, _ kind: Event.Kind) -> AppState {
    applyEvent(state, event(kind))
}

let six = ["p1", "p2", "p3", "p4", "p5", "p6"]

/// Nine on the roster, a game underway, six on court.
func onCourt(_ extra: [Event] = []) -> AppState {
    var events = roster(9)
    events += [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))]
    events += [event(.setLineup(playerIds: six))]
    events += extra
    return replay(events)
}
