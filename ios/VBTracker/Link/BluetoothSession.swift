// The link between two phones, over Bluetooth Low Energy.
//
// This replaced Multipeer Connectivity, and the reason is the only one that mattered:
// Multipeer disconnects the moment iOS suspends the app. A coach with the phone in her
// pocket is a suspended app, so the match stopped arriving every time the screen locked --
// which made the lock screen court, the watch behind it, and the whole second phone useless
// to the one person it was built for.
//
// Core Bluetooth is allowed to keep going. With the two background modes declared, iOS wakes
// a suspended app to hand it a connection event or a new value, so a serve recorded on one
// phone reaches a locked phone in somebody's pocket -- and from there her own watch and her
// own lock screen, both of which could always work in the background and were only ever
// starved by this one hop.
//
// What it costs is that BLE carries a couple of hundred bytes at a time rather than whole
// messages, so everything is cut up and put back together by `LinkFraming`. That part is
// tested. This part cannot be tested anywhere but on two real phones in one room.
//
// It lives in the phone's own folder rather than in `Shared`, because `Shared` is compiled
// into the watch app too and a watch has no business advertising for phones.
import CoreBluetooth
import Foundation
import VBCore
import VBPresentation

/// Two phones talking over Bluetooth, behind the protocol the rest of the app talks to.
public final class BluetoothSession: NSObject, PeerSession, @unchecked Sendable {
    /// Both halves of the pair must agree on these. They are arbitrary and permanent: change
    /// one and an old build stops being able to find a new one.
    private enum Wire {
        // Computed, not stored. `CBUUID` is a class Core Bluetooth never declared Sendable,
        // and a stored static of a non-Sendable type is shared mutable state as far as
        // Swift 6 is concerned. Building one per use costs nothing, and it asserts nothing
        // about a framework type that only Apple can make true.
        static var service: CBUUID { CBUUID(string: "8A3C1B42-6F1E-4C7A-9D22-0F5B7E41C9A6") }
        static var channel: CBUUID { CBUUID(string: "8A3C1B43-6F1E-4C7A-9D22-0F5B7E41C9A6") }
        /// Handed back to iOS when it relaunches the app for a Bluetooth event, so the app
        /// takes up the connection it already had instead of starting over.
        static let restoreSending = "com.mikejsmith.vbtracker.peripheral"
        static let restoreReceiving = "com.mikejsmith.vbtracker.central"
        /// What BLE guarantees before anything is negotiated. Used only until the real
        /// figure is known, so the first message out is never too big to send.
        static let smallestChunk = 20
        /// Shown when the other phone has not said its name. iOS drops the name from an
        /// advertisement once that app is in the background, which is most of the time here.
        static let unnamedPeer = "the other phone"
    }

    /// Every radio callback lands here, and every piece of mutable state below is touched
    /// only on it. That is what makes the unchecked conformance true rather than hopeful.
    private let radio = DispatchQueue(label: "com.mikejsmith.vbtracker.bluetooth")

    private let displayName: String
    private let mode: PeerMode
    private weak var delegate: (any PeerDelegate)?
    private let reader = FrameReader()
    private var nextMessageId: UInt16 = 0

    // The sending half.
    private var peripheralManager: CBPeripheralManager?
    private var channel: CBMutableCharacteristic?
    private var subscribers: [CBCentral] = []
    /// Frames the radio would not take yet. BLE refuses when its queue is full and calls back
    /// when there is room, so a refused frame is kept rather than dropped -- a dropped frame
    /// is a serve that silently never happened on the other phone.
    private var waiting: [Data] = []

    // The receiving half.
    private var centralManager: CBCentralManager?
    private var peer: CBPeripheral?
    private var peerChannel: CBCharacteristic?

    public init(displayName: String, mode: PeerMode, delegate: any PeerDelegate) {
        self.displayName = displayName
        self.mode = mode
        self.delegate = delegate
        super.init()
    }

    /// Starts the one job this phone does.
    ///
    /// One advertiser and one scanner, exactly as before: two phones each doing both was a
    /// race that joined about one time in five.
    public func start() {
        radio.async { [self] in
            if mode.isAdvertising {
                peripheralManager = CBPeripheralManager(
                    delegate: self,
                    queue: radio,
                    options: [CBPeripheralManagerOptionRestoreIdentifierKey: Wire.restoreSending]
                )
            }
            if mode.isBrowsing {
                centralManager = CBCentralManager(
                    delegate: self,
                    queue: radio,
                    options: [CBCentralManagerOptionRestoreIdentifierKey: Wire.restoreReceiving]
                )
            }
            delegate?.peerLinkChanged(.looking)
        }
    }

    /// Stops both, and drops any phone already joined.
    public func stop() {
        radio.async { [self] in
            peripheralManager?.stopAdvertising()
            peripheralManager?.removeAllServices()
            if let peer { centralManager?.cancelPeripheralConnection(peer) }
            centralManager?.stopScan()

            peripheralManager = nil
            centralManager = nil
            channel = nil
            peerChannel = nil
            peer = nil
            subscribers = []
            waiting = []
            reader.reset()
            delegate?.peerLinkChanged(.off)
        }
    }

    /// Sends to whichever phone is joined. Does nothing when none is.
    public func send(_ payload: [String: Any]) {
        // Flattened here, on the caller's thread, and deliberately not inside the hop below:
        // a property list dictionary is not Sendable and may not cross to the radio queue.
        // `Data` is, so the message is made first and only the message travels.
        guard let message = LinkPayload.data(from: payload) else { return }
        radio.async { [self] in
            nextMessageId &+= 1
            let frames = LinkFraming.frames(for: message, messageId: nextMessageId, chunkSize: chunkSize())
            guard !frames.isEmpty else { return }
            waiting.append(contentsOf: frames)
            drain()
        }
    }

    /// The most this connection will carry in one piece, asked for rather than assumed.
    ///
    /// It differs by phone, by iOS version, and by what the two negotiated, so the smallest
    /// size BLE guarantees is the fallback and never the plan.
    private func chunkSize() -> Int {
        if mode.isAdvertising {
            return subscribers.map(\.maximumUpdateValueLength).min() ?? Wire.smallestChunk
        }
        guard let peer else { return Wire.smallestChunk }
        return max(Wire.smallestChunk, peer.maximumWriteValueLength(for: .withResponse))
    }

    /// Sends whatever is waiting, until the radio says stop.
    private func drain() {
        while let frame = waiting.first {
            guard passOn(frame) else { return }
            waiting.removeFirst()
        }
    }

    /// Hands one frame to the radio. False means it would not take it yet.
    private func passOn(_ frame: Data) -> Bool {
        if mode.isAdvertising {
            guard let channel, let peripheralManager, !subscribers.isEmpty else { return false }
            return peripheralManager.updateValue(frame, for: channel, onSubscribedCentrals: nil)
        }
        guard let peer, let peerChannel else { return false }
        peer.writeValue(frame, for: peerChannel, type: .withResponse)
        return true
    }

    /// One frame in. Delivers the payload on the frame that completes a message.
    private func take(_ frame: Data) {
        guard let message = reader.accept(frame),
            let payload = LinkPayload.payload(from: message)
        else {
            return
        }
        delegate?.received(fromPeer: payload)
    }

    /// The link came up or went away, said in one place so both halves agree on the words.
    ///
    /// Anything half-received is thrown away with the connection: pieces from a link that is
    /// gone can never be completed by the one that replaces it, and keeping them would let
    /// half of one message join half of another.
    private func announce(_ state: PeerLinkState) {
        if case .connected = state {} else { reader.reset() }
        delegate?.peerLinkChanged(state)
    }

    /// What the radio being unavailable means for the row on screen.
    ///
    /// Bluetooth switched off or refused is `off` -- the operator has to do something about
    /// it. Anything else is still looking, because it may yet come good on its own.
    private func stateWhenNotReady(_ state: CBManagerState) -> PeerLinkState {
        switch state {
        case .poweredOff, .unauthorized, .unsupported: .off
        default: .looking
        }
    }
}

// MARK: - Sending: this phone advertises, and the other one subscribes to it

extension BluetoothSession: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ manager: CBPeripheralManager) {
        guard manager.state == .poweredOn else {
            return announce(stateWhenNotReady(manager.state))
        }
        guard channel == nil else { return }

        // Writeable as well as notifying, because the receiver opens by saying what it
        // already holds -- without a way back it would have to be sent the whole season.
        let channel = CBMutableCharacteristic(
            type: Wire.channel,
            properties: [.notify, .write],
            value: nil,
            permissions: [.writeable]
        )
        let service = CBMutableService(type: Wire.service, primary: true)
        service.characteristics = [channel]
        manager.add(service)
        self.channel = channel

        // The name is advertised for the other phone to show, but iOS drops it from the
        // advertisement once this app is in the background. The service UUID survives, and it
        // is the only part that has to.
        manager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Wire.service],
            CBAdvertisementDataLocalNameKey: displayName,
        ])
    }

    public func peripheralManager(_ manager: CBPeripheralManager, willRestoreState state: [String: Any]) {
        // Relaunched by iOS for a Bluetooth event. Take back the service that is already
        // published rather than adding a second one beside it.
        let services = state[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] ?? []
        channel =
            services
            .flatMap { $0.characteristics ?? [] }
            .compactMap { $0 as? CBMutableCharacteristic }
            .first { $0.uuid == Wire.channel }
    }

    public func peripheralManager(
        _ manager: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        subscribers.append(central)
        announce(.connected(peerName: Wire.unnamedPeer))
        drain()
    }

    public func peripheralManager(
        _ manager: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        subscribers.removeAll { $0.identifier == central.identifier }
        guard subscribers.isEmpty else { return }
        waiting = []
        announce(.looking)
    }

    /// The radio has room again for what it refused.
    public func peripheralManagerIsReady(toUpdateSubscribers manager: CBPeripheralManager) {
        drain()
    }

    public func peripheralManager(_ manager: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard let value = request.value else { continue }
            take(value)
        }
        // Answered even though nothing here needs an answer: an unanswered write leaves the
        // other phone waiting on it, and it stops sending anything more.
        guard let first = requests.first else { return }
        manager.respond(to: first, withResult: .success)
    }
}

// MARK: - Receiving: this phone looks for the other one and subscribes

extension BluetoothSession: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ manager: CBCentralManager) {
        guard manager.state == .poweredOn else {
            return announce(stateWhenNotReady(manager.state))
        }
        look(with: manager)
    }

    public func centralManager(_ manager: CBCentralManager, willRestoreState state: [String: Any]) {
        let restored = state[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
        guard let first = restored.first else { return }
        peer = first
        first.delegate = self
    }

    public func centralManager(
        _ manager: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: NSNumber
    ) {
        guard peer == nil else { return }
        // Held onto deliberately: Core Bluetooth lets go of a peripheral nobody is keeping,
        // and the connection dies with it before it is ever made.
        peer = peripheral
        peripheral.delegate = self
        manager.stopScan()
        manager.connect(peripheral, options: nil)
    }

    public func centralManager(_ manager: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Wire.service])
    }

    public func centralManager(
        _ manager: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        lostThePeer(manager)
    }

    public func centralManager(
        _ manager: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        lostThePeer(manager)
    }

    /// Back to looking. The other phone may simply have gone to the far end of the gym.
    private func lostThePeer(_ manager: CBCentralManager) {
        peer = nil
        peerChannel = nil
        waiting = []
        announce(.looking)
        look(with: manager)
    }

    /// Scans, filtered by service.
    ///
    /// The filter is not an optimisation. A scan for everything returns nothing at all once
    /// the app is in the background, which is the one condition this whole file exists for.
    private func look(with manager: CBCentralManager) {
        guard manager.state == .poweredOn else { return }
        manager.scanForPeripherals(withServices: [Wire.service], options: nil)
    }
}

extension BluetoothSession: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Wire.service }) else { return }
        peripheral.discoverCharacteristics([Wire.channel], for: service)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard let found = service.characteristics?.first(where: { $0.uuid == Wire.channel }) else { return }
        peerChannel = found
        peripheral.setNotifyValue(true, for: found)
        announce(.connected(peerName: peripheral.name ?? Wire.unnamedPeer))
        drain()
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let value = characteristic.value else { return }
        take(value)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        drain()
    }
}
