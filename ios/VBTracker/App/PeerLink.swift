// The phone's half of the link to a second phone at the same match.
//
// The case it exists for: one person tracks, another coaches. The coach's watch pairs to the
// coach's phone and to nothing else, so the court cannot travel from the tracker's phone to
// the coach's wrist. It goes phone to phone here, and the coach's phone feeds her own watch
// by the link that already exists -- which is why the watch app needs no change at all.
//
// The operator says which way the match travels before any radio is touched. Everything
// about this phone's behaviour follows from that one choice: which radio job it does, whether
// it may record, and what it sends. Nothing is inferred, so nothing can be inferred wrongly.
import Foundation
import VBCore
import VBPresentation

@MainActor
@Observable
final class PeerLink {
    private(set) var mode: PeerMode = .off
    private(set) var state: PeerLinkState = .off

    /// What this phone may do. Decided by the mode alone.
    var role: PeerRole { mode.role }

    private let store: Store
    private let deviceName: String
    private var session: (any PeerSession)?

    /// What the other phone is known to hold: what it announced, plus everything sent to it
    /// since. Only the difference travels, so a serve is one small message rather than a
    /// season.
    private var peerHolds: Set<String> = []

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
    var isSharing: Bool { mode != .off }

    /// Offers this phone's match to another one.
    func startSending() { start(in: .sending) }

    /// Watches a match another phone is sending.
    func startReceiving() { start(in: .receiving) }

    /// Puts the radio away while the app is not on screen, and picks it up again after.
    ///
    /// Nothing survives a suspension, so the choice is between a link that is known to be
    /// gone and a link that merely looks alive. The row said "connected" for as long as the
    /// phone was locked, and the figures behind it were as old as the lock.
    func appWentAway() {
        guard mode != .off else { return }
        session?.stop()
        session = nil
        state = .looking
        peerHolds = []
    }

    /// Starts the same job again after the app comes back.
    func appCameBack() {
        guard mode != .off, session == nil else { return }
        start(in: mode)
    }

    /// Stops sharing, whichever way it was going.
    ///
    /// The only way out of a role, deliberately: a game thrown away and another started is
    /// still the same two people at the same match, and sharing lasts until somebody says
    /// otherwise.
    func stop() {
        session?.stop()
        session = nil
        mode = .off
        state = .off
        peerHolds = []
    }

    private func start(in wanted: PeerMode) {
        stop()
        mode = wanted

        let session = PeerConnectivitySession(displayName: deviceName, mode: wanted, delegate: self)
        self.session = session
        session.start()
    }

    /// Announces what this phone holds, so the other sends only the difference.
    ///
    /// Identifiers, never the log. A season is thousands of events, and putting the whole
    /// record on the air every few seconds to ask what is missing would be all cost.
    private func announceWhatIsHeld() {
        session?.send(LinkPayload.encode(held: PeerSync.identifiersHeld(store.heldEvents)))
    }

    /// Sends whatever the other phone is not known to hold.
    ///
    /// Called on every change, which is what makes this live: a serve recorded here is on the
    /// coach's wrist in the seconds she has to decide on a substitution.
    private func offerWhatIsNew() {
        guard mode == .sending, state.isLive else { return }
        push()
    }

    /// Sends the difference and remembers having sent it.
    ///
    /// Delivery is reliable, so an event sent is an event arrived or a connection dropped --
    /// and a drop clears what is remembered, so reconnecting starts the conversation again
    /// rather than trusting a record of a link that is gone.
    private func push() {
        let missing = PeerSync.eventsToSend(mine: store.heldEvents, theyHold: peerHolds)
        guard !missing.isEmpty else { return }
        session?.send(LinkPayload.encode(events: missing))
        peerHolds.formUnion(PeerSync.identifiersHeld(missing))
    }
}

// The radio calls back on its own queue, so every arrival is decoded where it lands and then
// hops to the main actor carrying only values that can safely cross. `[String: Any]` cannot,
// which is why nothing here passes the payload itself inward.
extension PeerLink: PeerDelegate {
    nonisolated func peerLinkChanged(_ newState: PeerLinkState) {
        Task { @MainActor in self.linkChanged(to: newState) }
    }

    nonisolated func received(fromPeer payload: [String: Any]) {
        if let held = LinkPayload.decodeHeld(payload) {
            Task { @MainActor in self.sendWhatTheyLack(held) }
            return
        }

        let arriving = LinkPayload.decodeEvents(payload)
        guard !arriving.isEmpty else { return }
        Task { @MainActor in self.take(arriving) }
    }
}

@MainActor
extension PeerLink {
    /// The link came up or went away.
    ///
    /// The receiver opens by saying what it already holds, and the sender answers with the
    /// difference. Only the receiver announces: two phones announcing at once was two phones
    /// each answering the other's announcement, for no gain.
    fileprivate func linkChanged(to newState: PeerLinkState) {
        state = newState
        guard newState.isLive else {
            // A link that went away takes what was known about the far side with it.
            peerHolds = []
            return
        }
        if mode == .receiving { announceWhatIsHeld() }
    }

    /// Answers an announcement with the events the other phone has not got.
    fileprivate func sendWhatTheyLack(_ theyHold: [String]) {
        guard mode == .sending else { return }
        peerHolds = Set(theyHold)
        push()
    }

    /// Takes a match the other phone is sending.
    ///
    /// Only a receiver takes anything. A sender that accepted events would be a second
    /// opinion about what happened on court, and the two could not be told apart afterwards.
    fileprivate func take(_ arriving: [RawEvent]) {
        guard mode == .receiving else { return }
        peerHolds.formUnion(PeerSync.identifiersHeld(arriving))
        store.receive(peerEvents: arriving)
    }
}
