// The real connection between two phones in the same room.
//
// Everything difficult about the link is decided elsewhere -- who may record, what travels,
// what happens to what arrives -- so this file is only the wiring. That is deliberate: it is
// one of the two files in the app that cannot be tested anywhere but on real hardware.
//
// Multipeer Connectivity is Bluetooth and peer-to-peer Wi-Fi between devices in the same
// room. No router, no internet, no account, and nothing that works at a distance. It is the
// only reason a season can reach a second phone in a gym with no signal.
import Foundation
import MultipeerConnectivity
import VBPresentation

/// `MCSession`, behind the protocol the rest of the app talks to.
public final class PeerConnectivitySession: NSObject, PeerSession, @unchecked Sendable {
    /// Both halves of the pair must agree on this, and Apple caps it at fifteen characters
    /// of lowercase letters, digits and hyphens.
    private static let serviceType = "vb-serve"

    /// One peer at a time. The case this exists for is two people at one match; a third
    /// phone joining would be a third opinion about what happened on court.
    private static let maximumPeers = 1

    private let identity: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private weak var delegate: (any PeerDelegate)?

    /// `displayName` is what the other phone shows the operator, so it is the device's own
    /// name -- "Mike's iPhone" -- rather than an identifier nobody could match to a person.
    public init(displayName: String, delegate: any PeerDelegate) {
        self.identity = MCPeerID(displayName: displayName)
        // Encrypted because it costs nothing here and a season is a list of children's names.
        self.session = MCSession(peer: identity, securityIdentity: nil, encryptionPreference: .required)
        self.delegate = delegate
        super.init()
        session.delegate = self
    }

    /// Starts looking, and starts being findable.
    ///
    /// Both at once, because either phone may be the one that starts sharing first and
    /// neither operator should have to know which of them is "the host".
    public func start() {
        let advertiser = MCNearbyServiceAdvertiser(
            peer: identity, discoveryInfo: nil, serviceType: Self.serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser

        let browser = MCNearbyServiceBrowser(peer: identity, serviceType: Self.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser

        delegate?.peerLinkChanged(.looking)
    }

    /// Stops both, and drops any phone already joined.
    public func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        session.disconnect()
        delegate?.peerLinkChanged(.off)
    }

    /// Sends to whichever phone is joined. Does nothing when none is.
    ///
    /// `.reliable` because these are recorded serves, not a picture of the court: one that
    /// arrives late is still wanted, and one that never arrives is a serve nobody has.
    public func send(_ payload: [String: Any]) {
        guard !session.connectedPeers.isEmpty, let data = LinkPayload.data(from: payload) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }
}

extension PeerConnectivitySession: MCSessionDelegate {
    public func session(_ session: MCSession, peer: MCPeerID, didChange state: MCSessionState) {
        let announced: PeerLinkState =
            switch state {
            case .connected: .connected(peerName: peer.displayName)
            // Still looking rather than off: the operator has not stopped sharing, so the
            // phone keeps trying and the row must not say the link was put away.
            case .connecting, .notConnected: .looking
            @unknown default: .looking
            }
        delegate?.peerLinkChanged(announced)
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peer: MCPeerID) {
        guard let payload = LinkPayload.payload(from: data) else { return }
        delegate?.received(fromPeer: payload)
    }

    // Streams and resources are never used: everything here is one small payload at a time.
    public func session(_ session: MCSession, didReceive stream: InputStream, withName name: String, fromPeer peer: MCPeerID) {}
    public func session(_ session: MCSession, didStartReceivingResourceWithName name: String, fromPeer peer: MCPeerID, with progress: Progress) {}
    public func session(_ session: MCSession, didFinishReceivingResourceWithName name: String, fromPeer peer: MCPeerID, at url: URL?, withError error: Error?) {}
}

extension PeerConnectivitySession: MCNearbyServiceAdvertiserDelegate {
    /// Accepted without asking, because sharing was already switched on by hand.
    ///
    /// Turning sharing on IS the consent: a second prompt a moment later asks the same
    /// question again, and a coach at the side of a court would learn to dismiss it.
    public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peer: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        let hasRoom = session.connectedPeers.count < Self.maximumPeers
        invitationHandler(hasRoom, hasRoom ? session : nil)
    }
}

extension PeerConnectivitySession: MCNearbyServiceBrowserDelegate {
    public func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peer: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        guard session.connectedPeers.count < Self.maximumPeers else { return }
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 20)
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peer: MCPeerID) {
        delegate?.peerLinkChanged(.looking)
    }
}
