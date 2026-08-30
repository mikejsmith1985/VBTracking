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
    @State private var settings = WatchSettings()

    var body: some Scene {
        WindowGroup {
            ZStack {
                TabView {
                    CourtScreen(link: link)
                    RecordScreen(link: link)
                    SettingsScreen(settings: settings)
                }
                .tabViewStyle(.verticalPage)

                // Over every page, because the rule applies wherever the coach happens to
                // be looking -- and because it is the one thing here worth interrupting
                // for, for as long as the coach wants to be interrupted.
                if let notice = link.serveLimit, settings.preferences.shouldShow(notice) {
                    RotateAlert(notice: notice, shouldBuzz: settings.preferences.shouldBuzz) {
                        link.clearServeLimit()
                    }
                }
            }
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

    /// The serve count at which the coach last cleared the rotate alert.
    ///
    /// Kept rather than a plain "dismissed" flag because the alert has to come back for the
    /// next player. Two raisings never sit at the same count, so this clears one raising and
    /// nothing else.
    private var clearedAtServeCount: Int?

    private var session: (any ConnectivitySession)?

    init() {
        session = WatchConnectivitySession(delegate: self)
    }

    /// The rotate alert that is still standing, if any.
    ///
    /// Derived rather than remembered: the phone stops sending the notice the moment the
    /// next serve is recorded, so an alert answered on the phone disappears from the wrist
    /// without the wrist being told separately.
    var serveLimit: ServeLimitNotice? {
        guard let notice = snapshot?.serveLimit else { return nil }
        return notice.raisedAtServeCount == clearedAtServeCount ? nil : notice
    }

    /// Stops the buzzing. The coach has seen it.
    func clearServeLimit() {
        clearedAtServeCount = snapshot?.serveLimit?.raisedAtServeCount
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
