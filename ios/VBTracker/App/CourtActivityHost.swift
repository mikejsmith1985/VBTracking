// Putting the court on the lock screen, and taking it off again.
//
// Started when a match starts, updated on every recorded serve, and ended the moment the
// match does. An activity left running after a match is a lock screen that goes quietly out
// of date, and the whole point of `Glance` is that it never does.
//
// Nothing here is in the recording loop's way. A phone that refuses Live Activities, or is
// on an older iOS, records exactly as it always did.
import ActivityKit
import Foundation
import VBCore
import VBPresentation

@MainActor
final class CourtActivityHost {
    private var activity: Activity<CourtActivityAttributes>?
    private var sequence = 0

    /// Whether the operator has switched this on. Off by default: a lock screen is somebody's
    /// own, and an app that puts itself there uninvited is one they turn off entirely.
    var isEnabled = false {
        didSet { if !isEnabled { end() } }
    }

    /// Follows the record: starts an activity when a match appears, updates it while one is
    /// running, and ends it when there is none.
    func follow(_ state: AppState) {
        guard isEnabled, Self.isPermitted else { return }
        guard let court = state.courtView() else { return end() }

        sequence += 1
        let snapshot = CourtSnapshot(
            court: court,
            sequence: sequence,
            capturedAt: Date(),
            // No alert ever rides this. The wrist already buzzes for the serve limit, and a
            // second buzz for the same rotation would train the coach to ignore both.
            serveLimit: nil,
            acknowledgedEventIds: []
        )

        if let activity {
            Task { await activity.update(ActivityContent(state: .init(court: snapshot), staleDate: nil)) }
        } else {
            start(with: snapshot, opponent: state.currentGame?.context.opponent ?? "")
        }
    }

    /// Takes the court off the lock screen.
    ///
    /// `.immediate` rather than letting it linger: a finished match on a lock screen is a
    /// court that will never move again, which is the exact thing this is built not to show.
    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    private func start(with snapshot: CourtSnapshot, opponent: String) {
        activity = try? Activity.request(
            attributes: CourtActivityAttributes(opponent: opponent),
            content: ActivityContent(state: .init(court: snapshot), staleDate: nil),
            // No push token: updates come from this app, over the same radio the match does.
            // A pushed update would need the internet, which this app does not have and does
            // not want.
            pushType: nil
        )
    }

    /// Whether the phone will accept one at all.
    ///
    /// Read rather than assumed: the operator can switch Live Activities off for this app in
    /// Settings, and asking for one anyway throws every time.
    static var isPermitted: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }
}
