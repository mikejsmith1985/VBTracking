// What travels to the lock screen.
//
// Shared by the phone app, which starts and updates the activity, and the extension, which
// draws it. Its own folder rather than `Shared`, because `Shared` is compiled into the watch
// app too and watchOS has no ActivityKit -- the same trap the phone-to-phone radio fell into.
//
// The whole court travels, not a summary. The extension re-reads it on its own schedule, so
// it has to be able to work out for itself how old the figures are and refuse to draw them
// once they stop being true. A summary computed at send time could not do that.
import ActivityKit
import Foundation
import VBPresentation

/// The Live Activity for a match in progress.
public struct CourtActivityAttributes: ActivityAttributes {
    /// The part that changes as the match goes on.
    public struct ContentState: Codable, Hashable {
        /// The court exactly as the wrist would receive it, including when it was captured.
        public var court: CourtSnapshot

        public init(court: CourtSnapshot) {
            self.court = court
        }
    }

    /// Who is playing, fixed for the life of the activity. Shown so a lock screen holding
    /// two of these -- a match and something else entirely -- is not a guessing game.
    public var opponent: String

    public init(opponent: String) {
        self.opponent = opponent
    }
}
