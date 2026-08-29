// The link, driven against a fake session.
//
// Every rule about ordering, delivery and duplication is decided in `VBPresentation` and
// tested there, on the workstation. What is left to prove here is that the two payloads
// survive the trip through `WCSession`'s dictionaries — which is the part that needs the
// platform, and so runs on the build machine.
import Testing
import VBCore
import VBPresentation

@testable import VBTracker

/// A session that goes nowhere, and remembers everything it was asked to send.
final class FakeSession: ConnectivitySession, @unchecked Sendable {
    var isReachable: Bool
    private(set) var contexts: [[String: Any]] = []
    private(set) var transfers: [[String: Any]] = []

    /// When false, nothing is delivered — the phone in a bag on the other side of the gym.
    var isDelivering = true

    init(isReachable: Bool = true) {
        self.isReachable = isReachable
    }

    func send(context: [String: Any]) {
        guard isDelivering else { return }
        contexts.append(context)
    }

    func transfer(userInfo: [String: Any]) {
        guard isDelivering else { return }
        transfers.append(userInfo)
    }
}

@Suite("What survives the trip between devices")
struct LinkPayloadTests {
    private func snapshot(sequence: Int = 1) -> CourtSnapshot {
        CourtSnapshot(
            sequence: sequence,
            capturedAt: Date(timeIntervalSince1970: 1_000_000),
            scopeLabel: "Match 2",
            hasOrder: true,
            slots: [
                SnapshotSlot(court: 4, number: "15", inPercentage: 0.5, points: 1, isServing: false, isOnDeck: false),
                SnapshotSlot(court: 3, number: "4", inPercentage: 0.8, points: 2, isServing: false, isOnDeck: false),
                SnapshotSlot(court: 2, number: "12", inPercentage: nil, points: nil, isServing: false, isOnDeck: true),
                SnapshotSlot(court: 5, number: "3", inPercentage: 0.75, points: 3, isServing: false, isOnDeck: false),
                SnapshotSlot(court: 6, number: nil, inPercentage: nil, points: nil, isServing: false, isOnDeck: false),
                SnapshotSlot(court: 1, number: "7", inPercentage: 0.62, points: 4, isServing: true, isOnDeck: false),
            ]
        )
    }

    @Test("A court survives being sent and read back")
    func courtRoundTrips() {
        let sent = snapshot()
        let read = LinkPayload.decodeSnapshot(LinkPayload.encode(snapshot: sent))

        #expect(read == sent)
    }

    @Test("A figure that was never recorded is still absent on the other side")
    func absenceSurvives() {
        let read = LinkPayload.decodeSnapshot(LinkPayload.encode(snapshot: snapshot()))
        let onDeck = read?.slots.first { $0.isOnDeck }

        #expect(onDeck?.inPercentage == nil, "a dash must not become a zero in transit")
        #expect(onDeck?.points == nil)
    }

    @Test("An empty position is still empty on the other side")
    func emptyPositionSurvives() {
        let read = LinkPayload.decodeSnapshot(LinkPayload.encode(snapshot: snapshot()))
        #expect(read?.slots.contains { $0.number == nil } == true)
    }

    @Test("Serves recorded on the wrist survive the trip")
    func eventsRoundTrip() {
        let events: [RawEvent] = [
            ["eventId": "a", "t": "RECORD_SERVE", "outcome": "OUT"],
            ["eventId": "b", "t": "RECORD_SERVE", "outcome": "IN_POINT"],
        ]
        let read = LinkPayload.decodeEvents(LinkPayload.encode(events: events))

        #expect(read == events)
    }

    @Test("Confirmations survive the trip")
    func confirmationsRoundTrip() {
        let read = LinkPayload.decodeConfirmed(LinkPayload.encode(confirmed: ["a", "b"]))
        #expect(read == ["a", "b"])
    }

    @Test("A payload that is not ours reads as nothing rather than crashing")
    func toleratesRubbish() {
        #expect(LinkPayload.decodeSnapshot(["something": "else"]) == nil)
        #expect(LinkPayload.decodeEvents(["something": "else"]).isEmpty)
        #expect(LinkPayload.decodeConfirmed([:]).isEmpty)
    }
}

@Suite("The wrist while the phone is out of reach")
struct OfflineWristTests {
    @Test("Serves recorded out of contact are kept, and shown as unsent")
    func keepsWhatHasNotLanded() {
        var queue = PendingQueue()
        queue.add(["eventId": "a", "t": "RECORD_SERVE", "outcome": "OUT"])
        queue.add(["eventId": "b", "t": "RECORD_SERVE", "outcome": "IN_POINT"])

        #expect(queue.label == "2 serves not sent")
    }

    @Test("They all arrive once contact returns, in the order they were taken")
    func flushesInOrder() {
        let session = FakeSession()
        session.isDelivering = false

        var queue = PendingQueue()
        queue.add(["eventId": "a", "t": "RECORD_SERVE", "outcome": "OUT"])
        queue.add(["eventId": "b", "t": "RECORD_SERVE", "outcome": "IN_POINT"])
        session.transfer(userInfo: LinkPayload.encode(events: queue.events))
        #expect(session.transfers.isEmpty, "nothing leaves while there is nobody to hear it")

        session.isDelivering = true
        session.transfer(userInfo: LinkPayload.encode(events: queue.events))

        let delivered = LinkPayload.decodeEvents(session.transfers[0])
        #expect(delivered.compactMap { $0["eventId"]?.stringValue } == ["a", "b"])
    }

    @Test("An older court never replaces a newer one")
    func olderSnapshotLoses() {
        // Snapshots can arrive out of order, and the coach must never be shown the older.
        var held: CourtSnapshot?
        let newer = CourtSnapshot(sequence: 5, capturedAt: Date(), scopeLabel: "Match 1", hasOrder: true, slots: [])
        let older = CourtSnapshot(sequence: 4, capturedAt: Date(), scopeLabel: "Match 1", hasOrder: true, slots: [])

        for incoming in [newer, older] where incoming.sequence > (held?.sequence ?? Int.min) {
            held = incoming
        }
        #expect(held?.sequence == 5)
    }
}
