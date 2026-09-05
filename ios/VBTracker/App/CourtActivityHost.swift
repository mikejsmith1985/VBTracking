// Putting the court on the lock screen, and taking it off again.
//
// Started when a match starts, updated on every recorded serve, and ended the moment the
// match does. An activity left running after a match is a lock screen that goes quietly out
// of date, and the whole point of `Glance` is that it never does.
//
// Nothing here is in the recording loop's way. A phone that refuses Live Activities, or is
// on an older iOS, records exactly as it always did.
//
// Not `@MainActor`, and that is not an oversight. Read out of the SDK's own interface:
//
//     public class Activity<Attributes> : Identifiable where Attributes : ActivityAttributes
//     public func update(_ content: ActivityContent<...>) async
//     public func end(_ content: ActivityContent<...>?, dismissalPolicy: ...) async
//
// A plain class that ActivityKit never declared `Sendable`, whose update and end are
// nonisolated and async. An activity held on the main actor and passed to one of those is a
// non-sendable value crossing isolation, which Swift 6 refuses outright -- and no amount of
// `Sendable` on the content state changes it, because the class itself is the value that
// travels. So the activity is never isolated in the first place.
import ActivityKit
import Foundation
import VBCore
import VBPresentation

/// `@unchecked` covers ActivityKit's own non-sendable class, not this type's own fields:
/// every entry point below is called from the main actor -- the store's observer, and a
/// SwiftUI toggle -- so its state is reached one call at a time.
final class CourtActivityHost: @unchecked Sendable {
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
        let content = ActivityContent(state: CourtActivityAttributes.ContentState(court: snapshot), staleDate: nil)

        guard let activity else {
            return start(with: content, opponent: state.currentGame?.context.opponent ?? "")
        }
        Task { await activity.update(content) }
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

    private func start(with content: ActivityContent<CourtActivityAttributes.ContentState>, opponent: String) {
        activity = try? Activity.request(
            attributes: CourtActivityAttributes(opponent: opponent),
            content: content,
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
