// The real connection.
//
// Everything difficult about the link is decided elsewhere — ordering, staleness, exactly-
// once delivery — so this file is only the wiring. That is deliberate: it is the one file
// in the app that cannot be tested anywhere but on a paired device.
import Foundation
import WatchConnectivity

/// `WCSession`, behind the protocol the rest of the app talks to.
public final class WatchConnectivitySession: NSObject, ConnectivitySession, @unchecked Sendable {
    private let session: WCSession
    private weak var delegate: (any ConnectivityDelegate)?

    /// Nil when this device has no counterpart — an iPad, or an iPhone with no watch paired.
    /// Nothing in the recording loop may wait on the link, so a missing one is ordinary.
    public init?(delegate: any ConnectivityDelegate) {
        guard WCSession.isSupported() else { return nil }
        self.session = WCSession.default
        self.delegate = delegate
        super.init()
        session.delegate = self
        session.activate()
    }

    public var isReachable: Bool { session.isReachable }

    /// The newest court. Sent twice on purpose while the watch is awake: the application
    /// context always arrives eventually, and the message arrives now.
    public func send(context: [String: Any]) {
        if session.isReachable {
            session.sendMessage(context, replyHandler: nil) { _ in
                // The context below is the guarantee; a failed message costs nothing.
            }
        }
        try? session.updateApplicationContext(context)
    }

    /// Queued, in order, and delivered even if the other app is not running.
    public func transfer(userInfo: [String: Any]) {
        session.transferUserInfo(userInfo)
    }
}

extension WatchConnectivitySession: WCSessionDelegate {
    public func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: (any Error)?
    ) {
        delegate?.reachabilityChanged(isReachable: session.isReachable)
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        delegate?.reachabilityChanged(isReachable: session.isReachable)
    }

    public func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        delegate?.received(context: context)
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        delegate?.received(context: message)
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        delegate?.received(userInfo: userInfo)
    }

    #if os(iOS)
        // Required on iOS, and both are the same thing here: the watch is gone for now, and
        // the phone carries on recording exactly as it would with no watch at all.
        public func sessionDidBecomeInactive(_ session: WCSession) {
            delegate?.reachabilityChanged(isReachable: false)
        }

        public func sessionDidDeactivate(_ session: WCSession) {
            session.activate()
        }
    #endif
}
