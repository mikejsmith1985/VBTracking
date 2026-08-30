// The phone's half of the link.
//
// Out goes the newest court, whenever anything changes it. Back come serves recorded on the
// wrist, applied by the same rules as anything else and taken exactly once.
//
// Nothing here is in the recording loop's way. A phone with no watch paired sends into a
// session that does not exist and carries on.
import Foundation
import VBCore
import VBPresentation

@MainActor
final class PhoneLink {
    private let store: Store
    private var session: (any ConnectivitySession)?
    private var sequence = 0

    init(store: Store) {
        self.store = store
        self.session = WatchConnectivitySession(delegate: self)

        // Every accepted event redraws the wrist, substitutions included -- so the coach's
        // decision is never one serve out of date.
        store.onChange = { [weak self] state in
            self?.send(state)
        }
        send(store.state)
    }

    /// Sends the newest court, if there is one to send.
    private func send(_ state: AppState) {
        guard let session, let court = state.courtView() else { return }
        sequence += 1
        let snapshot = CourtSnapshot(
            court: court,
            sequence: sequence,
            capturedAt: Date(),
            // The wrist cannot count a turn -- the record is here -- so the rule is read
            // off the state and sent with the court it applies to.
            serveLimit: ServeLimitNotice.raised(by: state)
        )
        session.send(context: LinkPayload.encode(snapshot: snapshot))
    }
}

extension PhoneLink: ConnectivityDelegate {
    /// The watch does not send a court; only the phone does.
    nonisolated func received(context: [String: Any]) {}

    /// Serves recorded on the wrist.
    nonisolated func received(userInfo: [String: Any]) {
        let events = LinkPayload.decodeEvents(userInfo)
        guard !events.isEmpty else { return }

        Task { @MainActor in
            let accepted = store.accept(fromWatch: events)
            guard !accepted.isEmpty else { return }
            // Tell the wrist what landed, so it can stop showing those serves as unsent.
            session?.transfer(userInfo: LinkPayload.encode(confirmed: accepted))
        }
    }

    nonisolated func reachabilityChanged(isReachable: Bool) {
        guard isReachable else { return }
        Task { @MainActor in self.send(self.store.state) }
    }
}
