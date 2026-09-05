// The phone's half of the link to a second phone at the same match.
//
// The case it exists for: one person tracks, another coaches. The coach's watch pairs to the
// coach's phone and to nothing else, so the court cannot travel from the tracker's phone to
// the coach's wrist. It goes phone to phone here, and the coach's phone feeds her own watch
// by the link that already exists -- which is why the watch app needs no change at all.
//
// Nothing here is in the recording loop's way. Sharing that is switched off, or a phone that
// never answers, costs the person tracking nothing.
import Foundation
import VBCore
import VBPresentation

@MainActor
@Observable
final class PeerLink {
    private(set) var state: PeerLinkState = .off
    private(set) var role: PeerRole = .alone

    private let store: Store
    private let deviceName: String
    private var session: (any PeerSession)?

    init(store: Store, deviceName: String) {
        self.store = store
        self.deviceName = deviceName

        // Every accepted event offers itself to the other phone, so a serve reaches the
        // coach's wrist in the seconds she has to decide on a substitution.
        store.observe { [weak self] _ in
            self?.offerWhatIsNew()
        }
    }

    /// Whether sharing is switched on at all.
    var isSharing: Bool { state != .off }

    /// Starts sharing, or stops it. The one control the operator has.
    func toggleSharing() {
        if isSharing { return stopSharing() }

        let session = PeerConnectivitySession(displayName: deviceName, delegate: self)
        self.session = session
        session.start()
    }

    private func stopSharing() {
        session?.stop()
        session = nil
        state = .off
        // Back to recording. A phone that stops following is a phone on its own again, and
        // leaving it read-only would strand whoever put it down.
        role = .alone
    }

    /// Announces what this phone holds, so the other sends only the difference.
    ///
    /// Identifiers, never the log. A season is thousands of events, and putting the whole
    /// record on the air every few seconds to ask what is missing would be all cost.
    private func announceWhatIsHeld() {
        session?.send(LinkPayload.encode(held: PeerSync.identifiersHeld(store.heldEvents)))
    }

    /// Sends whatever the other phone has not said it holds.
    ///
    /// Called on every change, and the far side takes each event exactly once by identifier,
    /// so sending one twice costs a little radio and nothing else.
    private func offerWhatIsNew() {
        guard state.isLive, role != .following else { return }
        announceWhatIsHeld()
    }
}

extension PeerLink: PeerDelegate {
    func peerLinkChanged(_ newState: PeerLinkState) {
        state = newState
        // Each phone opens by saying what it has. Whichever is behind then receives the
        // difference, and neither has to be told in advance which of them is the tracker.
        if newState.isLive { announceWhatIsHeld() }
    }

    func received(fromPeer payload: [String: Any]) {
        // What they hold: send back what they are missing.
        if let held = LinkPayload.decodeHeld(payload) {
            let missing = PeerSync.eventsToSend(mine: store.heldEvents, theyHold: held)
            guard !missing.isEmpty else { return }
            session?.send(LinkPayload.encode(events: missing))
            return
        }

        // Events: take them, and stop recording on this phone.
        let arriving = LinkPayload.decodeEvents(payload)
        guard !arriving.isEmpty else { return }

        // Receiving a match makes this the following phone. Two phones both recording the
        // same game produce two logs of it that cannot be joined afterwards, so the second
        // one is never allowed to start.
        role = .following
        store.receive(peerEvents: arriving)
    }
}
