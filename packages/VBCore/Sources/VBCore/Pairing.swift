// The invitation that rides along with a season handed to another phone.
//
// The problem it solves is not technical. Two people at a match had to agree, out loud, that
// one of them would tap "send" and the other "receive", and get it the right way round, on a
// sideline, before the first serve. Nobody would ever discover that on their own.
//
// So the season file carries an invitation: this is my match, and I am sharing it live. The
// phone it lands on reads that and starts watching, without anybody choosing anything. One
// tap on an AirDrop notification is the whole of the other person's setup.
//
// The invitation is an extra key in a file that already existed, which is what keeps it
// harmless: the web app and every older build read the same file and ignore the key.
import Foundation

/// Who is offering a match, said in a file rather than in words across a gym.
public struct MatchInvitation: Equatable, Sendable {
    /// Which phone to listen to.
    ///
    /// Stable for the life of the app on that phone, not generated per match: a phone that
    /// restarts halfway through a game must still be the phone the other one was told about,
    /// or the link comes back and is then refused for being a stranger.
    public let senderCode: String

    /// What to call the other phone on screen, so the row says something a person recognises.
    public let senderName: String

    public init(senderCode: String, senderName: String) {
        self.senderCode = senderCode
        self.senderName = senderName
    }
}

/// The key the invitation travels under. Nothing else reads it, and everything else ignores it.
private let invitationKey = "liveMatch"
private let senderCodeKey = "senderCode"
private let senderNameKey = "senderName"

/// Builds a season file with an invitation to watch the match live.
///
/// The same bytes as a plain handover plus one object, so a phone that has never heard of
/// live sharing still reads the season out of it exactly as before.
public func buildHandover(
    _ events: [RawEvent],
    exportedAt: String,
    inviting invitation: MatchInvitation?
) -> String {
    let text = buildBackup(events, exportedAt: exportedAt)
    guard let invitation else { return text }

    guard let data = text.data(using: .utf8),
        let decoded = try? JSONDecoder().decode(JSONValue.self, from: data),
        var file = decoded.objectValue
    else {
        return text
    }

    file[invitationKey] = .object([
        senderCodeKey: .string(invitation.senderCode),
        senderNameKey: .string(invitation.senderName),
    ])

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    guard let encoded = try? encoder.encode(JSONValue.object(file)),
        let withInvitation = String(data: encoded, encoding: .utf8)
    else {
        return text
    }
    return withInvitation
}

/// Reads the invitation out of a season file, if it carries one.
///
/// Never throws and never complains. A file with no invitation is the ordinary case -- a
/// season handed over for keeps -- and is not a failure of any kind.
public func readInvitation(_ text: String) -> MatchInvitation? {
    guard let data = text.data(using: .utf8),
        let decoded = try? JSONDecoder().decode(JSONValue.self, from: data),
        let file = decoded.objectValue,
        file["app"]?.stringValue == exportMarker,
        let block = file[invitationKey]?.objectValue,
        let code = block[senderCodeKey]?.stringValue,
        !code.isEmpty
    else {
        return nil
    }
    let name = block[senderNameKey]?.stringValue
    return MatchInvitation(senderCode: code, senderName: name ?? "the other phone")
}
