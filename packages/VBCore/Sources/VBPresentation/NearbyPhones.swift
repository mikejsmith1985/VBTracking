// The phones nearby that are sharing a match, and how long to keep believing in them.
//
// This replaced sending a file across the room. AirDropping a season answered one question --
// which phone -- and charged the other person a file picker and an "open with" to answer it.
// A phone advertising a match is already saying its name into the room, so the answer was
// there the whole time.
//
// What makes it awkward is that Bluetooth never says goodbye. A phone that has left the gym,
// gone flat, or simply stopped sharing looks exactly like one sitting quietly in range, so a
// name kept forever becomes an offer to join a match that ended an hour ago. Every sighting
// is therefore stamped, and a phone not seen recently is dropped.
import Foundation

/// A phone seen advertising a match, and when it was last heard from.
public struct NearbyPhone: Equatable, Sendable, Identifiable {
    /// The radio's own identifier for that phone. Stable while both apps are running, which
    /// is all that is needed to recognise the same phone across sightings.
    public let id: String

    /// What it calls itself. Empty when the other app is in the background, because iOS drops
    /// the name out of an advertisement then -- so it is never shown raw.
    public let name: String

    public let lastSeen: Date

    public init(id: String, name: String, lastSeen: Date) {
        self.id = id
        self.name = name
        self.lastSeen = lastSeen
    }

    /// What to call it on screen. Never blank, whatever the radio said.
    public var shownName: String {
        name.trimmingCharacters(in: .whitespaces).isEmpty ? "Another phone" : name
    }
}

/// Everything heard recently, with the stale dropped.
public struct NearbyPhones: Equatable, Sendable {
    /// How long a phone is believed in after its last sighting.
    ///
    /// Bluetooth advertises every couple of seconds, so ten covers several missed ones -- a
    /// phone in a pocket at the far end of a gym -- without leaving an offer up long after
    /// somebody walked out with the phone.
    public static let trustedFor: TimeInterval = 10

    private var seen: [String: NearbyPhone]

    public init() { seen = [:] }

    /// Records a sighting.
    public mutating func noticed(id: String, name: String, at moment: Date) {
        seen[id] = NearbyPhone(id: id, name: name, lastSeen: moment)
    }

    /// Forgets everything. Used when this phone stops listening at all.
    public mutating func forgetAll() { seen = [:] }

    /// The phones still worth offering, most recently heard first.
    ///
    /// Sorted by name after that, so a list of two does not swap places every second as their
    /// advertisements arrive in whatever order the radio delivers them.
    public func current(at moment: Date) -> [NearbyPhone] {
        seen.values
            .filter { moment.timeIntervalSince($0.lastSeen) <= Self.trustedFor }
            .sorted { left, right in
                if left.shownName != right.shownName { return left.shownName < right.shownName }
                return left.id < right.id
            }
    }

    /// The one to offer, when there is exactly one worth offering.
    ///
    /// Nil for none and nil for several. Two phones sharing at once is two courts in one gym,
    /// and guessing between them would put somebody else's match on this screen -- so the
    /// offer names them all rather than picking.
    public func onlyOne(at moment: Date) -> NearbyPhone? {
        let now = current(at: moment)
        return now.count == 1 ? now.first : nil
    }

    /// What to offer, in the words a banner shows.
    ///
    /// Nil when there is nothing to say, which is almost always: an app that says "nobody is
    /// sharing" every time it is opened is an app that has taught everybody to ignore that
    /// row by the second week.
    public func offer(at moment: Date) -> String? {
        let now = current(at: moment)
        guard let first = now.first else { return nil }
        guard now.count == 1 else { return "\(now.count) phones nearby are sharing a match" }
        return "\(first.shownName) is sharing a match"
    }
}
