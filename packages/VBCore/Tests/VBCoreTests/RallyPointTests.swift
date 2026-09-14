// Recording the rallies played while the other team had the ball.
//
// The one thing the serve chart could never hold. Every rally on our own serve is already
// decided by that serve's outcome, so this event exists for -- and is only accepted during --
// the spell when somebody else is serving.
import Testing

@testable import VBCore

private let six = ["p1", "p2", "p3", "p4", "p5", "p6"]

/// A game underway with six on court and nobody holding the ball, which is the state this
/// event is for: the other team is serving.
private func receiving(_ extra: [Event]...) -> AppState {
    var events = roster(6)
    events += [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))]
    events += [event(.setLineup(playerIds: six))]
    events += extra.flatMap { $0 }
    return replay(events)
}

@Suite("Rallies played while the other team serves")
struct RallyPointTests {
    @Test("A rally they won is kept, in order")
    func keepsWhatWasRecorded() {
        let state = receiving([
            event(.recordRallyPoint(toUs: false)),
            event(.recordRallyPoint(toUs: false)),
            event(.recordRallyPoint(toUs: true)),
        ])
        #expect(state.currentMatch?.opponentServeRallies == [false, false, true])
    }

    @Test("Undo takes back exactly one rally")
    func undoDropsOne() {
        // Kept as a list rather than two totals for this reason: a total cannot say which
        // one to take back.
        let events =
            roster(6) + [
                event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true)),
                event(.setLineup(playerIds: six)),
                event(.recordRallyPoint(toUs: false)),
                event(.recordRallyPoint(toUs: true)),
            ]
        let undone = replay(events.dropLast())
        #expect(undone.currentMatch?.opponentServeRallies == [false])
    }

    @Test("It is refused once our player has actually served")
    func refusedWhileWeServe() {
        let serving = receiving([
            event(.selectServer(playerId: "p1")),
            event(.recordServe(outcome: .inPoint)),
        ])
        // Accepting it here would count the rally twice: once as this, once as the outcome
        // of the serve that decided it.
        #expect(refusal(serving, .recordRallyPoint(toUs: true)) != nil)
        #expect(refusal(serving, .recordRallyPoint(toUs: false))?.contains("serve outcome") == true)
    }

    @Test("It is accepted while somebody holds the ball but has not served")
    func acceptedBeforeTheFirstServe() {
        // The rotation hands the ball on the moment a turn ends, so the next player holds it
        // -- without having served -- for the whole spell the other team is serving. That is
        // the gap this lives in, and it is the only state the app offers for it.
        let waiting = receiving([event(.selectServer(playerId: "p1"))])
        #expect(refusal(waiting, .recordRallyPoint(toUs: false)) == nil)

        let afterATurnEnded = receiving([
            event(.selectServer(playerId: "p1")),
            event(.recordServe(outcome: .out)),
        ])
        #expect(refusal(afterATurnEnded, .recordRallyPoint(toUs: false)) == nil)
    }

    @Test("It is refused when there is no match at all")
    func refusedWithNoMatch() {
        let noGame = build(roster(6))
        #expect(refusal(noGame, .recordRallyPoint(toUs: true))?.contains("No match") == true)
    }

    @Test("It survives being written and read back")
    func survivesTheLog() {
        for toUs in [true, false] {
            let written = EventEncoder.encode(.recordRallyPoint(toUs: toUs))
            #expect(written["t"]?.stringValue == EventType.recordRallyPoint)

            let read = Event(raw: written)
            #expect(read?.kind == .recordRallyPoint(toUs: toUs), "a season must reopen as it was saved")
        }
    }

    @Test("Serve figures are untouched by it")
    func leavesTheServeChartAlone() {
        let withRallies = receiving([
            event(.selectServer(playerId: "p1")),
            event(.recordServe(outcome: .inPoint)),
            event(.recordServe(outcome: .out)),
            event(.recordRallyPoint(toUs: false)),
            event(.recordRallyPoint(toUs: true)),
        ])
        let withoutRallies = receiving([
            event(.selectServer(playerId: "p1")),
            event(.recordServe(outcome: .inPoint)),
            event(.recordServe(outcome: .out)),
        ])
        // The whole point of a separate event: a score somebody keeps must never be able to
        // move a serve percentage.
        #expect(withRallies.currentMatch?.turns == withoutRallies.currentMatch?.turns)
    }
}
