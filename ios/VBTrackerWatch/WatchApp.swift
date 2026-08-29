// The watch app.
//
// Two pages: the court, and recording. The court is the reason for the release, so it is
// the one that is there when the wrist comes up — recording is a deliberate swipe away,
// because nothing may be recorded by an arm moving through a gym evening.
import SwiftUI
import VBCore
import VBPresentation

@main
struct VBTrackerWatchApp: App {
    @State private var link = WatchLink()

    var body: some Scene {
        WindowGroup {
            TabView {
                CourtScreen(link: link)
                RecordScreen(link: link)
            }
            .tabViewStyle(.verticalPage)
        }
    }
}

/// The watch's half of the link.
///
/// It holds the newest court and the serves that have not yet reached the phone. Every rule
/// it follows — discard an older snapshot, keep a serve until it is confirmed — is decided
/// in `VBPresentation` and tested there.
@MainActor
@Observable
final class WatchLink {
    private(set) var snapshot: CourtSnapshot?
    private(set) var pending = PendingQueue()
    private(set) var isReachable = false

    private var session: (any ConnectivitySession)?

    init() {
        session = WatchConnectivitySession(delegate: self)
    }

    /// How current the court is, or nil when none has ever arrived.
    func freshness(now: Date = Date()) -> LinkFreshness? {
        snapshot.map { LinkFreshness(capturedAt: $0.capturedAt, now: now) }
    }

    /// Records a serve from the wrist.
    ///
    /// The identifier is made here, at the moment of the tap: it is the identity of that
    /// tap, not of its delivery, which is what lets the phone take it exactly once however
    /// many times it arrives.
    func record(_ outcome: Outcome) {
        var event = EventEncoder.encode(.recordServe(outcome: outcome))
        event["eventId"] = .string(UUID().uuidString)
        event["recordedAt"] = .string(ISO8601DateFormatter().string(from: Date()))

        pending.add(event)
        flush()
    }

    /// Sends everything not yet confirmed. Safe to call at any time: delivery is queued,
    /// and an event the phone already holds is ignored there.
    private func flush() {
        guard let session, !pending.events.isEmpty else { return }
        session.transfer(userInfo: LinkPayload.encode(events: pending.events))
    }
}

extension WatchLink: ConnectivityDelegate {
    nonisolated func received(context: [String: Any]) {
        guard let incoming = LinkPayload.decodeSnapshot(context) else { return }
        Task { @MainActor in
            // Snapshots can arrive out of order, and the older one must never win.
            guard incoming.sequence > (snapshot?.sequence ?? Int.min) else { return }
            snapshot = incoming
        }
    }

    nonisolated func received(userInfo: [String: Any]) {
        let confirmed = LinkPayload.decodeConfirmed(userInfo)
        guard !confirmed.isEmpty else { return }
        Task { @MainActor in pending.confirm(confirmed) }
    }

    nonisolated func reachabilityChanged(isReachable: Bool) {
        Task { @MainActor in
            self.isReachable = isReachable
            if isReachable { self.flush() }
        }
    }
}
