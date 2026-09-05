// Cutting a message up and getting the same message back, under the conditions a radio
// actually produces.
//
// This is the only part of the Bluetooth link that can be tested without two phones in one
// room, so it is tested hard: duplicates, gaps, overlap, and the sizes a real connection
// offers rather than round numbers.
import Foundation
import Testing

@testable import VBPresentation

@Suite("A message survives being cut up for Bluetooth")
struct LinkFramingTests {
    /// What a real connection offers. iOS has handed out every one of these.
    private static let realChunkSizes = [20, 23, 27, 101, 155, 182, 185, 244, 512]

    private func message(ofSize size: Int) -> Data {
        Data((0..<size).map { UInt8($0 % 251) })
    }

    @Test("A message comes back exactly as it went, at every size a phone offers")
    func survivesEveryChunkSize() {
        for chunkSize in Self.realChunkSizes {
            for size in [0, 1, 19, 20, 21, 200, 4096, 40000] {
                let original = message(ofSize: size)
                let reader = FrameReader()
                var rebuilt: Data?
                for frame in LinkFraming.frames(for: original, messageId: 7, chunkSize: chunkSize) {
                    if let whole = reader.accept(frame) { rebuilt = whole }
                }
                #expect(rebuilt == original, "size \(size) at chunk \(chunkSize)")
            }
        }
    }

    @Test("Every piece fits inside what the connection will carry")
    func neverExceedsTheChunkSize() {
        for chunkSize in Self.realChunkSizes {
            let frames = LinkFraming.frames(for: message(ofSize: 5000), messageId: 1, chunkSize: chunkSize)
            #expect(!frames.isEmpty)
            for frame in frames {
                #expect(frame.count <= chunkSize, "a piece of \(frame.count) will not fit in \(chunkSize)")
            }
        }
    }

    @Test("An empty message still arrives, rather than never arriving")
    func sendsSomethingForNothing() {
        let frames = LinkFraming.frames(for: Data(), messageId: 3, chunkSize: 20)
        #expect(frames.count == 1)

        let reader = FrameReader()
        #expect(reader.accept(frames[0]) == Data())
    }

    @Test("A piece that arrives twice changes nothing")
    func toleratesDuplicates() {
        let original = message(ofSize: 500)
        let frames = LinkFraming.frames(for: original, messageId: 9, chunkSize: 60)
        let reader = FrameReader()

        var arrived: [Data] = []
        for frame in frames {
            if let whole = reader.accept(frame) { arrived.append(whole) }
            // The same piece again, immediately. A radio does this.
            if let whole = reader.accept(frame) { arrived.append(whole) }
        }
        // Exactly once, not twice: the piece that completed the message finished it, and
        // seeing that piece a second time must not deliver the same serves again.
        #expect(arrived == [original])
    }

    @Test("Pieces arriving out of order still rebuild the message in order")
    func toleratesReordering() {
        let original = message(ofSize: 900)
        let frames = LinkFraming.frames(for: original, messageId: 11, chunkSize: 40).reversed()
        let reader = FrameReader()

        var rebuilt: Data?
        for frame in frames {
            if let whole = reader.accept(frame) { rebuilt = whole }
        }
        #expect(rebuilt == original)
    }

    @Test("Two messages sent at once do not become one")
    func keepsOverlappingMessagesApart() {
        let first = message(ofSize: 300)
        let second = message(ofSize: 700)
        let firstFrames = LinkFraming.frames(for: first, messageId: 1, chunkSize: 50)
        let secondFrames = LinkFraming.frames(for: second, messageId: 2, chunkSize: 50)

        let reader = FrameReader()
        var arrived: [Data] = []
        // Interleaved, which is what happens when a serve is recorded while a catch-up is
        // still going out.
        for pair in 0..<max(firstFrames.count, secondFrames.count) {
            if pair < firstFrames.count, let whole = reader.accept(firstFrames[pair]) { arrived.append(whole) }
            if pair < secondFrames.count, let whole = reader.accept(secondFrames[pair]) { arrived.append(whole) }
        }
        #expect(arrived.count == 2)
        #expect(arrived.contains(first))
        #expect(arrived.contains(second))
    }

    @Test("A message that stops halfway is never mistaken for a whole one")
    func neverCompletesAGap() {
        let frames = LinkFraming.frames(for: message(ofSize: 400), messageId: 5, chunkSize: 40)
        #expect(frames.count > 2)

        let reader = FrameReader()
        // Everything except the last piece. The message must not appear.
        for frame in frames.dropLast() {
            #expect(reader.accept(frame) == nil)
        }
    }

    @Test("Half-built messages are not kept forever")
    func forgetsAbandonedMessages() {
        let reader = FrameReader()
        // Five messages started and none finished. The oldest must be let go rather than
        // held for the rest of the match.
        for messageId in UInt16(1)...UInt16(5) {
            let frames = LinkFraming.frames(for: message(ofSize: 400), messageId: messageId, chunkSize: 40)
            _ = reader.accept(frames[0])
        }

        // The first message's remaining pieces now complete nothing, because it was dropped.
        let first = LinkFraming.frames(for: message(ofSize: 400), messageId: 1, chunkSize: 40)
        var completed: Data?
        for frame in first.dropFirst() {
            if let whole = reader.accept(frame) { completed = whole }
        }
        #expect(completed == nil, "an abandoned message was still being held")
    }

    @Test("A dropped link takes its half-built messages with it")
    func resetForgetsEverything() {
        let original = message(ofSize: 400)
        let frames = LinkFraming.frames(for: original, messageId: 6, chunkSize: 40)
        let reader = FrameReader()
        _ = reader.accept(frames[0])

        // The connection went away. Pieces from it can never be completed by the one that
        // replaces it.
        reader.reset()

        var completed: Data?
        for frame in frames.dropFirst() {
            if let whole = reader.accept(frame) { completed = whole }
        }
        #expect(completed == nil)
    }

    @Test("Rubbish on the wire is refused rather than rebuilt")
    func refusesNonsense() {
        let reader = FrameReader()
        #expect(reader.accept(Data()) == nil, "nothing at all")
        #expect(reader.accept(Data([1, 2, 3])) == nil, "shorter than a header")
        // A header claiming zero pieces, and one claiming to be piece 9 of 2.
        #expect(reader.accept(Data([0, 1, 0, 0, 0, 0])) == nil)
        #expect(reader.accept(Data([0, 1, 0, 9, 0, 2])) == nil)
    }

    @Test("Pieces too small to hold anything are refused rather than sent")
    func refusesImpossibleChunkSizes() {
        for chunkSize in [0, 1, LinkFraming.headerSize] {
            #expect(LinkFraming.frames(for: message(ofSize: 10), messageId: 1, chunkSize: chunkSize).isEmpty)
        }
    }
}
