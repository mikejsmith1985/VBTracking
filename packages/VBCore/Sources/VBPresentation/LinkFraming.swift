// Cutting a message into pieces small enough for Bluetooth, and putting it back together.
//
// Bluetooth Low Energy does not carry messages, it carries notifications of a couple of
// hundred bytes. A single recorded serve is usually smaller than that and sometimes is not,
// and the first thing a phone sends after joining is everything the other one is missing --
// which is never small. So a message is cut up here, sent piece by piece, and reassembled at
// the far end.
//
// It has to survive the ordinary indignities of a radio: pieces arriving twice, pieces that
// never arrive at all, and two messages overlapping because the second was sent before the
// first had finished. None of that is exotic; all of it happens in a gym.
//
// This is the only part of the Bluetooth link that can be tested anywhere but on two real
// phones, which is exactly why the rules live here and not in the session.
import Foundation

/// One piece of a message, with enough on the front to know where it belongs.
public enum LinkFraming {
    /// Six bytes: which message, which piece, and how many pieces there are.
    public static let headerSize = 6

    /// The most pieces a single message may be cut into.
    ///
    /// At the smallest chunk a phone has ever offered, that is comfortably a whole season.
    /// A number is needed because the count travels in two bytes, and a message that claimed
    /// more pieces than this is a corrupt one rather than a big one.
    public static let maximumChunks = 65535

    /// Cuts a message into pieces that fit.
    ///
    /// Returns nothing when the pieces would be too small to hold anything, or when the
    /// message is too big to describe -- both of which are programming errors rather than
    /// radio conditions, so they fail here rather than half-sending.
    public static func frames(for message: Data, messageId: UInt16, chunkSize: Int) -> [Data] {
        let room = chunkSize - headerSize
        guard room > 0 else { return [] }

        // An empty message is still a message: one piece carrying nothing says "this arrived
        // and there was nothing in it", where sending no pieces at all says nothing.
        let pieces = max(1, Int((Double(message.count) / Double(room)).rounded(.up)))
        guard pieces <= maximumChunks else { return [] }

        return (0..<pieces).map { index in
            let start = message.startIndex + index * room
            let end = min(start + room, message.endIndex)
            var frame = Data(capacity: headerSize + room)
            frame.append(bytes: messageId)
            frame.append(bytes: UInt16(index))
            frame.append(bytes: UInt16(pieces))
            frame.append(message[start..<end])
            return frame
        }
    }
}

/// Collects pieces until a whole message is there.
///
/// Not a value type: it is a thing that remembers, and every arrival changes what it holds.
public final class FrameReader {
    /// How many half-built messages to keep at once.
    ///
    /// A message whose pieces stop arriving is never completed and would otherwise sit in
    /// memory for the rest of the match. Keeping a few covers the overlap that actually
    /// happens -- a serve sent while a catch-up is still going out -- and the oldest
    /// unfinished one is dropped rather than kept forever.
    private static let messagesKeptAtOnce = 4

    private var partial: [UInt16: [UInt16: Data]] = [:]
    private var arrivalOrder: [UInt16] = []

    public init() {}

    /// Takes one piece. Returns the whole message on the piece that completes it.
    public func accept(_ frame: Data) -> Data? {
        guard frame.count >= LinkFraming.headerSize else { return nil }
        let messageId = frame.uint16(at: 0)
        let index = frame.uint16(at: 2)
        let count = frame.uint16(at: 4)
        guard count > 0, index < count else { return nil }

        let body = Data(frame.dropFirst(LinkFraming.headerSize))
        var pieces = partial[messageId] ?? [:]
        pieces[index] = body
        partial[messageId] = pieces
        remember(messageId)

        guard pieces.count == Int(count) else { return nil }
        forget(messageId)
        return (0..<count).reduce(into: Data()) { whole, next in
            whole.append(pieces[next] ?? Data())
        }
    }

    /// Throws away everything half-built.
    ///
    /// Called when the link drops: pieces from a connection that is gone can never be
    /// completed by the connection that replaces it, and keeping them would let half of one
    /// match's message join half of another's.
    public func reset() {
        partial = [:]
        arrivalOrder = []
    }

    private func remember(_ messageId: UInt16) {
        arrivalOrder.removeAll { $0 == messageId }
        arrivalOrder.append(messageId)
        while arrivalOrder.count > Self.messagesKeptAtOnce {
            partial[arrivalOrder.removeFirst()] = nil
        }
    }

    private func forget(_ messageId: UInt16) {
        partial[messageId] = nil
        arrivalOrder.removeAll { $0 == messageId }
    }
}

extension Data {
    /// Appends a number most significant byte first, so both phones read it the same way
    /// whatever they are.
    fileprivate mutating func append(bytes value: UInt16) {
        append(UInt8(value >> 8))
        append(UInt8(value & 0xFF))
    }

    /// Reads a two-byte number at an offset counted from the start of the data.
    fileprivate func uint16(at offset: Int) -> UInt16 {
        let first = self[startIndex + offset]
        let second = self[startIndex + offset + 1]
        return UInt16(first) << 8 | UInt16(second)
    }
}
