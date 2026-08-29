// The court, and the one thing the whole release is for: which box is on deck.
//
// The geometry is pinned here rather than in a view, because a view cannot be run on this
// workstation and this is what the watch will draw.
import Testing

@testable import VBCore

private let six = ["p1", "p2", "p3", "p4", "p5", "p6"]

/// A match with the six on court and a rotation in force.
private func onCourt(_ extra: [Event]...) -> AppState {
    var events = roster(8)
    events += [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))]
    events += [event(.setLineup(playerIds: six))]
    events += extra.flatMap { $0 }
    return replay(events)
}

/// The jersey numbers in the six boxes, in drawing order: front row, then back row.
private func numbers(_ view: CourtView) -> [String?] {
    view.slots.map(\.number)
}

@Suite("The six on court")
struct CourtGeometryTests {
    @Test("The server stands in the bottom-right box")
    func serverIsBottomRight() {
        let view = try? #require(onCourt([event(.selectServer(playerId: "p1"))]).courtView())

        #expect(view?.slots.last?.position == .service)
        #expect(view?.slots.last?.number == "1", "p1 wears number 1")
        #expect(view?.slots.last?.isServing == true)
    }

    @Test("The order runs clockwise from the service corner")
    func runsClockwise() {
        let view = try? #require(onCourt([event(.selectServer(playerId: "p1"))]).courtView())

        // Front row left to right is positions 4, 3, 2; back row is 5, 6, 1.
        #expect(numbers(view ?? emptyView()) == ["4", "3", "2", "5", "6", "1"])
    }

    @Test("The court re-lays itself around whoever has the ball")
    func relaysAroundTheServer() {
        let view = try? #require(
            onCourt([
                event(.selectServer(playerId: "p1")),
                event(.recordServe(outcome: .out)),
            ]).courtView()
        )

        #expect(view?.slots.last?.number == "2", "the serve has moved on")
        #expect(numbers(view ?? emptyView()) == ["5", "4", "3", "6", "1", "2"])
    }

    @Test("The player who takes the serve next is in the top-right box")
    func onDeckIsTopRight() {
        let view = try? #require(onCourt([event(.selectServer(playerId: "p1"))]).courtView())
        let onDeck = view?.slots.first { $0.isOnDeck }

        #expect(onDeck?.position == .rightFront)
        #expect(onDeck?.number == "2")
        #expect(view?.onDeckPlayerId == "p2")
    }

    @Test("Exactly one box is serving and exactly one is on deck")
    func oneOfEach() {
        let view = try? #require(onCourt([event(.selectServer(playerId: "p1"))]).courtView())

        #expect(view?.slots.filter(\.isServing).count == 1)
        #expect(view?.slots.filter(\.isOnDeck).count == 1)
    }

    @Test("The arrangement wraps round rather than running off the end")
    func wrapsAround() {
        #expect(lineupIndex(servingPosition: 5, offset: 1) == 0)
        #expect(lineupIndex(servingPosition: 0, offset: 6) == 0)
        #expect(lineupIndex(servingPosition: 4, offset: 3) == 1)
    }
}

@Suite("What each box says")
struct CourtFigureTests {
    @Test("A box carries the number, the serve-in percentage and the points")
    func carriesFigures() {
        let state = onCourt([
            event(.selectServer(playerId: "p1")),
            event(.recordServe(outcome: .inPoint)),
            event(.recordServe(outcome: .out)),
        ])
        let view = try? #require(state.courtView())
        let serving = view?.slots.first { $0.playerId == "p1" }

        #expect(serving?.number == "1")
        #expect(serving?.inPercentage == 0.5)
        #expect(serving?.points == 1)
    }

    @Test("A player who has not served has no percentage, and no zero standing in for one")
    func noServesNoPercentage() {
        let view = try? #require(onCourt([event(.selectServer(playerId: "p1"))]).courtView())
        let waiting = view?.slots.first { $0.playerId == "p4" }

        #expect(waiting?.number == "4")
        #expect(waiting?.inPercentage == nil, "a dash on the wrist, never 0%")
        #expect(waiting?.points == nil)
    }

    @Test("A position nobody is standing in is drawn as empty")
    func drawsEmptyPosition() {
        // A player removed from the roster mid-match leaves their slot empty. The position
        // is still a place in the order, and hiding it would misstate who serves next.
        let state = onCourt([
            event(.selectServer(playerId: "p1")),
            event(.recordServe(outcome: .out)),
            event(.removePlayer(id: "p4", seasonId: nil)),
        ])
        let view = try? #require(state.courtView())

        #expect(view?.slots.contains { $0.playerId == nil } == true)
    }

    @Test("The scope is named, so this match cannot be mistaken for the whole game")
    func namesTheScope() {
        let view = try? #require(onCourt().courtView())
        #expect(view?.scopeLabel == "Match 1")
    }

    @Test("Without an order, the court cannot name a next server and says so")
    func noOrderNoNextServer() {
        let state = build(
            roster(3),
            [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))],
            [event(.selectServer(playerId: "p1"))]
        )
        let view = try? #require(state.courtView())

        #expect(view?.onDeckPlayerId == nil)
        #expect(view?.hasOrder == false)
    }

    @Test("There is no court to draw when no match is in progress")
    func noMatchNoCourt() {
        #expect(build(roster(3)).courtView() == nil)
    }

    @Test("A substitution puts the incoming player in the outgoing player's exact box")
    func substitutionKeepsTheBox() {
        let before = try? #require(onCourt([event(.selectServer(playerId: "p1"))]).courtView())
        let boxIndex = before?.slots.firstIndex { $0.playerId == "p3" }

        let state = onCourt([
            event(.selectServer(playerId: "p1")),
            event(.substitute(outPlayerId: "p3", inPlayerId: "p7")),
        ])
        let after = try? #require(state.courtView())

        #expect(after?.slots[boxIndex ?? 0].playerId == "p7")
    }
}

/// A stand-in used only where an optional has already been checked, so a failing test
/// reports the expectation that failed rather than trapping on a nil.
private func emptyView() -> CourtView {
    CourtView(slots: [], servingPosition: 0, onDeckPlayerId: nil, scopeLabel: "")
}
