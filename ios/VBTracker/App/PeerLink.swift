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

    /// The phone named in an AirDropped invitation, and what to call it. Nil when the
    /// operator switched receiving on by hand and any phone will do.
    private var expectedSender: String?
    private var invitedBy: String?

    /// Whether the phone on the other end has said who it is and turned out to be the right
    /// one. Nothing is taken into the log before it has.
    private var isPeerVouchedFor = false

    /// This phone's own code, kept so that a phone restarting halfway through a match is
    /// still the phone the other one was told about.
    ///
    /// `UserDefaults` rather than the log: this is a fact about a device, not about a season,
    /// and it must not travel in a backup to become a second phone claiming the same name.
    private static var thisPhonesCode: String {
        let key = "peer.senderCode"
        if let kept = UserDefaults.standard.string(forKey: key), !kept.isEmpty { return kept }
        let made = UUID().uuidString
        UserDefaults.standard.set(made, forKey: key)
        return made
    }

    init(store: Store, deviceName: String) {
        self.store = store
        self.deviceName = deviceName

        // Every accepted event offers itself to the other phone, so a serve reaches the
        // coach's wrist in the seconds she has to decide on a substitution.
        store.observe { [weak self] _ in
            self?.offerWhatIsNew()
        }
    }

    /// Whether sharing is switched on at all. Listening is not sharing.
    var isSharing: Bool { mode.isSharing }

    /// Phones nearby that are sharing a match, freshest sightings only.
    private(set) var nearby = NearbyPhones()

    /// What to offer on screen, or nil when there is nothing worth saying.
    func nearbyOffer(at moment: Date = Date()) -> String? {
        guard mode == .listening else { return nil }
        return nearby.offer(at: moment)
    }

    /// The phones to list, when the operator opens the offer.
    func nearbyPhones(at moment: Date = Date()) -> [NearbyPhone] {
        guard mode == .listening else { return [] }
        return nearby.current(at: moment)
    }

    /// Quietly notices whether anybody nearby is sharing. Nothing is joined and nothing is
    /// sent; all it produces is a name to offer.
    ///
    /// This is what replaced AirDropping a file to answer "which phone". A phone sharing a
    /// match is already saying its name into the room.
    func listen() {
        guard mode == .off else { return }
        start(in: .listening)
    }

    /// Stops listening, without disturbing a phone that is actually sharing.
    func stopListening() {
        guard mode == .listening else { return }
        stop()
    }

    /// Joins the phone the operator picked out of what is nearby.
    func watch(_ phone: NearbyPhone) {
        invitedBy = phone.shownName
        start(in: .receiving, joining: UUID(uuidString: phone.id))
    }

    /// Offers this phone's match to another one.
    func startSending() { start(in: .sending) }

    /// Watches a match another phone is sending.
    ///
    /// `expecting` comes out of an AirDropped invitation and names one phone. Without it --
    /// the operator simply tapped "receive" -- whoever answers is taken, which is how this
    /// worked before and is worth keeping for when AirDrop is not to hand.
    func startReceiving(expecting invitedCode: String? = nil) {
        expectedSender = invitedCode
        start(in: .receiving)
    }

    /// An invitation arrived by AirDrop. Start watching that phone, whatever was happening
    /// before -- tapping the invitation is the clearest statement of intent there is.
    func accept(_ invitation: MatchInvitation) {
        invitedBy = invitation.senderName
        startReceiving(expecting: invitation.senderCode)
    }

    /// The invitation to put in a season file, so the phone it lands on knows to listen and
    /// knows which phone to listen to.
    func invitation() -> MatchInvitation {
        MatchInvitation(senderCode: Self.thisPhonesCode, senderName: deviceName)
    }

    /// What this phone is waiting for, in words, while nothing has answered yet.
    var waitingLabel: String {
        guard mode == .receiving else { return mode.waitingLabel }
        return Introductions.waitingLabel(expecting: expectedSender, from: invitedBy)
    }

    /// Starts the job again if it is not running.
    ///
    /// Nothing is stopped when the app leaves the screen, and that is the whole point of the
    /// Bluetooth link: iOS wakes a suspended app for a connection event, so a match keeps
    /// arriving at a phone that is locked in somebody's pocket. This is only a safety net for
    /// the case where the radio was never started -- being switched on while the app was
    /// away, say.
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
        expectedSender = nil
        invitedBy = nil
        isPeerVouchedFor = false
        nearby.forgetAll()
    }

    private func start(in wanted: PeerMode, joining chosen: UUID? = nil) {
        stop()
        mode = wanted

        let session = BluetoothSession(
            displayName: deviceName,
            mode: wanted,
            wantedPeer: chosen,
            delegate: self
        )
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

    nonisolated func noticedNearby(id: String, name: String) {
        Task { @MainActor in self.nearby.noticed(id: id, name: name, at: Date()) }
    }

    nonisolated func received(fromPeer payload: [String: Any]) {
        if let introduction = LinkPayload.decodeIntroduction(payload) {
            Task { @MainActor in self.consider(introduction) }
            return
        }

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
            isPeerVouchedFor = false
            return
        }
        if mode == .sending { introduceThisPhone() }
        if mode == .receiving { announceWhatIsHeld() }
    }

    /// Says who this phone is, so a receiver holding an invitation can tell whether this is
    /// the match it was invited to or somebody else's at the next court.
    private func introduceThisPhone() {
        session?.send(LinkPayload.encode(introducing: Introduction(
            senderCode: Self.thisPhonesCode,
            senderName: deviceName
        )))
    }

    /// A phone said who it is. Keep listening, or hang up on a stranger.
    fileprivate func consider(_ introduction: Introduction) {
        guard mode == .receiving else { return }
        let greeting = Introductions.consider(introduction, expecting: expectedSender)
        guard greeting.isWelcome else {
            // Somebody else's match. Everything it sent before introducing itself is
            // dropped, because a stranger's serves must never reach this phone's log.
            isPeerVouchedFor = false
            store.say("That was another match nearby. Still looking.")
            return stop(keeping: .receiving, expecting: expectedSender)
        }
        isPeerVouchedFor = true
        invitedBy = greeting.peerName
        state = .connected(peerName: greeting.peerName ?? "the other phone")
        announceWhatIsHeld()
    }

    /// Drops the connection and starts looking again, keeping what this phone was told to
    /// look for. Used when the phone that answered turned out to be the wrong one.
    private func stop(keeping wanted: PeerMode, expecting invitedCode: String?) {
        stop()
        expectedSender = invitedCode
        start(in: wanted)
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
        guard mode == .receiving, isPeerVouchedFor else { return }
        peerHolds.formUnion(PeerSync.identifiersHeld(arriving))
        store.receive(peerEvents: arriving)
    }
}
