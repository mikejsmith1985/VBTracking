// Who a phone will listen to, once the radio has found somebody.
//
// Bluetooth finds whoever is advertising, and in a gym that could be a second family running
// the same app at the next court. A receiver would take their match, show their court, and
// look exactly like it was working -- which is the worst way for this to be wrong.
//
// So the phones introduce themselves after connecting. The sender says who it is; the
// receiver checks that against the invitation it was handed, and hangs up on a stranger.
//
// A receiver that was switched on by hand has no invitation and no expectation, so it takes
// whoever answers -- the same behaviour as before, kept because AirDrop is not always to
// hand and a link that needs no file at all is worth keeping.
import Foundation
import VBCore

/// What a sending phone says about itself the moment a link comes up.
public struct Introduction: Equatable, Sendable {
    public let senderCode: String
    public let senderName: String

    public init(senderCode: String, senderName: String) {
        self.senderCode = senderCode
        self.senderName = senderName
    }
}

/// What to do about the phone that just answered.
public enum Greeting: Equatable, Sendable {
    /// The phone that was invited, or any phone when none was named.
    case theRightPhone(named: String)
    /// Somebody else's match. Hang up and keep looking.
    case aStranger

    /// Whether to go on listening to this phone.
    public var isWelcome: Bool {
        if case .theRightPhone = self { return true }
        return false
    }

    /// What to call it on screen, or nil when it is not being listened to.
    public var peerName: String? {
        if case let .theRightPhone(named) = self { return named }
        return nil
    }
}

public enum Introductions {
    /// Decides whether the phone that just introduced itself is the one being waited for.
    ///
    /// `expecting` is the code out of the AirDropped invitation, and nil when the operator
    /// simply tapped "receive" -- in which case anybody answering is the right answer.
    public static func consider(
        _ introduction: Introduction,
        expecting invitedCode: String?
    ) -> Greeting {
        guard let invitedCode, !invitedCode.isEmpty else {
            return .theRightPhone(named: introduction.senderName)
        }
        guard introduction.senderCode == invitedCode else { return .aStranger }
        return .theRightPhone(named: introduction.senderName)
    }

    /// What the receiving phone says while it is waiting for the phone it was told about.
    ///
    /// Different words for the two cases on purpose: somebody who tapped an AirDrop is
    /// waiting for one particular phone and should be told so, and somebody who tapped
    /// "receive" is waiting for anybody.
    public static func waitingLabel(expecting invitedCode: String?, from name: String?) -> String {
        guard invitedCode?.isEmpty == false else { return "Looking for a phone sharing a match..." }
        guard let name, !name.isEmpty else { return "Looking for the phone that sent the invitation..." }
        return "Looking for \(name)..."
    }
}
