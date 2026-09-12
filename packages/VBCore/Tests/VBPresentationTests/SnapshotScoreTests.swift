// The rally score travelling to the wrist.
//
// A watch and a phone are two installs that can be a version apart, and the cost of getting
// that wrong here is the whole court rather than one line of it -- so the field added for the
// score is read the way every other added field is, and a court from a phone that has never
// heard of a score still arrives.
import Foundation
import Testing

@testable import VBPresentation

@Suite("The score on the wrist")
struct SnapshotScoreTests {
    private func snapshot(score: Scoreboard?) -> CourtSnapshot {
        CourtSnapshot(
            sequence: 1,
            capturedAt: Date(timeIntervalSince1970: 1_757_000_000),
            scopeLabel: "Match 1 of 3",
            hasOrder: true,
            slots: [],
            score: score
        )
    }

    private func roundTripped(_ snapshot: CourtSnapshot) throws -> CourtSnapshot {
        let data = try JSONEncoder().encode(snapshot)
        return try JSONDecoder().decode(CourtSnapshot.self, from: data)
    }

    @Test("A score sent is the score that arrives")
    func survivesTheTrip() throws {
        let sent = snapshot(score: Scoreboard(us: 14, them: 12))
        #expect(try roundTripped(sent).score == Scoreboard(us: 14, them: 12))
    }

    @Test("No score is carried as no score, not as nil-nil")
    func carriesAbsence() throws {
        // Nought-nought is a scoreline. A match nobody is scoring has none, and the wrist
        // must show nothing rather than claim the opposition have not scored.
        #expect(try roundTripped(snapshot(score: nil)).score == nil)
    }

    @Test("A court from a phone that never heard of a score still arrives")
    func readsAnOlderCourt() throws {
        // The field is decoded with decodeIfPresent for this reason: the synthesised decoder
        // throws on a missing key, and a throw here costs the whole screen.
        let older = """
            {
              "sequence": 4,
              "capturedAt": 757000000,
              "scopeLabel": "Match 2 of 3",
              "hasOrder": true,
              "slots": []
            }
            """
        let arrived = try JSONDecoder().decode(CourtSnapshot.self, from: Data(older.utf8))
        #expect(arrived.scopeLabel == "Match 2 of 3", "the court came through")
        #expect(arrived.score == nil, "and simply has no score")
    }

    @Test("The score is part of what makes a court different")
    func changesTheIdentity() {
        // The wrist leaves an unchanged court alone by comparing them, so a court whose only
        // change is the score has to count as changed -- or the score would freeze on the
        // wrist between serves.
        #expect(snapshot(score: Scoreboard(us: 1, them: 0)) != snapshot(score: Scoreboard(us: 1, them: 1)))
        #expect(snapshot(score: nil) != snapshot(score: Scoreboard(us: 0, them: 0)))
    }
}
