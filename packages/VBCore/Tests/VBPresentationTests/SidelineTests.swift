// The whole picture, for a phone propped up beside the court.
//
// Six on court and everybody else beside them, with the figures that decide a substitution.
// The watch cannot hold this much and does not try; a phone lying on the scorer's table can,
// and it is what somebody glances at when they want more than the next server.
import Testing
import VBCore

@testable import VBPresentation

@Suite("The court and the bench together")
struct SidelineTests {
    /// Eight players, six of them on court.
    private var match: AppState {
        var events: [Event] = [
            event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))
        ]
        events += (1...8).map {
            event(.addPlayer(id: "p\($0)", name: "Player \($0)", number: "\($0)", seasonId: nil))
        }
        events.append(event(.setLineup(playerIds: ["p1", "p2", "p3", "p4", "p5", "p6"])))
        return replay(events)
    }

    @Test("Six boxes, always, whoever is standing in them")
    func drawsSixPositions() {
        #expect(Sideline(state: match)?.court.count == 6)
    }

    @Test("Everybody not on court is on the bench")
    func benchesTheRest() {
        let bench = Sideline(state: match)?.bench ?? []
        #expect(bench.map(\.number).sorted() == ["7", "8"])
    }

    @Test("A bench player carries the figures that decide whether to bring them on")
    func benchCarriesFigures() {
        let bench = Sideline(state: match)?.bench ?? []
        // Nobody has served, so every figure is unknown -- and unknown is nil here, so the
        // screen draws a dash. A nought would say they served and missed.
        #expect(bench.first?.inPercentage == nil)
        #expect(bench.first?.points == nil)
    }

    @Test("A bench player who served earlier keeps what they did")
    func benchKeepsEarlierFigures() {
        var events: [Event] = [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))]
        events += (1...7).map {
            event(.addPlayer(id: "p\($0)", name: "Player \($0)", number: "\($0)", seasonId: nil))
        }
        events.append(event(.setLineup(playerIds: ["p1", "p2", "p3", "p4", "p5", "p7"])))
        events += turn("p7", points: 2, closing: .out)
        // p7 comes off for p6.
        events.append(event(.substitute(outPlayerId: "p7", inPlayerId: "p6")))

        let bench = Sideline(state: replay(events))?.bench ?? []
        let seven = bench.first { $0.number == "7" }
        #expect(seven?.points == 2, "coming off does not undo what they served")
    }

    @Test("With no match there is nothing to prop up")
    func nothingWithoutAMatch() {
        #expect(Sideline(state: replay([])) == nil)
    }

    @Test("The bench is in jersey order, so the same player is in the same place all night")
    func ordersTheBenchPredictably() {
        var events: [Event] = [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))]
        for (id, number) in [("p1", "1"), ("p2", "2"), ("p3", "3"), ("p4", "4"), ("p5", "5"), ("p6", "6"), ("p7", "21"), ("p8", "9")] {
            events.append(event(.addPlayer(id: id, name: "Player \(number)", number: number, seasonId: nil)))
        }
        events.append(event(.setLineup(playerIds: ["p1", "p2", "p3", "p4", "p5", "p6"])))

        // Nine before twenty-one: read as numbers, not as text, or 21 sorts before 9.
        #expect(Sideline(state: replay(events))?.bench.map(\.number) == ["9", "21"])
    }
}
