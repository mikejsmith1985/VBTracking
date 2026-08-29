// Reading the log as it is actually written. Ported from the tolerance the web app's
// reducer and parser already have.
//
// The boundary is the point where a value becomes a type. Nothing is coerced across it: a
// count that is not a whole number arrives as "not a whole number" rather than as zero,
// because the difference is what tells a corrupt event from a player who served nothing.
import Testing

@testable import VBCore

private func raw(_ type: String, _ fields: [String: JSONValue] = [:]) -> RawEvent {
    var event: RawEvent = ["t": .string(type)]
    for (key, value) in fields { event[key] = value }
    return event
}

@Suite("Reading a log")
struct EventCodecTests {
    @Test("An event with no type is not an event")
    func refusesTypeless() {
        #expect(Event(raw: ["id": "p1"]) == nil)
    }

    @Test("A type this build does not know decodes, and replay ignores it")
    func tolerantOfUnknownType() {
        let event = try? #require(Event(raw: raw("SOMETHING_NEWER")))
        #expect(event?.kind == .unrecognised(type: "SOMETHING_NEWER"))
    }

    @Test("Fields this build does not know are simply not read")
    func tolerantOfUnknownFields() {
        let event = Event(raw: raw(EventType.recordServe, ["outcome": "OUT", "recordedAt": "2026-08-29"]))
        #expect(event?.kind == .recordServe(outcome: .out))
    }

    @Test("The event identifier is read from eventId, never from id")
    func readsEventIdentifier() {
        // Several types already use `id` for the thing they are about. Reading the event's
        // own identifier from there would rewrite a season the web app recorded.
        let event = Event(raw: raw(EventType.addPlayer, ["id": "p1", "name": "Ella", "number": "7", "eventId": "e1"]))

        #expect(event?.id == "e1")
        #expect(event?.kind == .addPlayer(id: "p1", name: "Ella", number: "7", seasonId: nil))
    }

    @Test("An event written by the web app has no identifier, and that is not an error")
    func toleratesMissingIdentifier() {
        let event = Event(raw: raw(EventType.recordServe, ["outcome": "OUT"]))
        #expect(event?.id == "")
    }

    @Test("A serve outcome this build does not recognise is refused, not silently dropped")
    func refusesUnknownOutcome() {
        let event = try? #require(Event(raw: raw(EventType.recordServe, ["outcome": "ACE"])))
        #expect(event?.kind == .recordServe(outcome: nil))
        #expect(rejectionReason(AppState(), event ?? Event(id: "", kind: .clearLineup)) != nil)
    }

    @Test("A count that is not a whole number is refused rather than read as zero")
    func refusesFractionalCount() {
        let state = build(roster(1))
        let event = try? #require(
            Event(
                raw: raw(
                    EventType.addHistoricalGame,
                    [
                        "id": "h1",
                        "entries": .array([.object(["playerId": "p1", "in": .number(1.5), "out": 0])]),
                    ]
                )
            )
        )

        let reason = rejectionReason(state, event ?? Event(id: "", kind: .clearLineup))
        #expect(reason?.contains("whole numbers") == true)
    }

    @Test("A whole number written as 3.0 is still a count")
    func acceptsWholeDouble() {
        #expect(JSONValue.number(3.0).intValue == 3)
        #expect(JSONValue.number(3.5).intValue == nil)
    }
}
