// Correcting a game copied from paper, after the fact.
//
// A sheet transcribed in a hurry has numbers in the wrong row, and the season it belongs to
// is real. The rulebook has always carried the event; nothing had ever exercised what it
// does to the record, and the phone had no way to send it at all.
import Testing

@testable import VBCore

@Suite("Correcting a game copied from paper")
struct PaperEditTests {
    /// Two players and one paper game, transcribed wrongly.
    private var transcribed: AppState {
        build(
            roster(2),
            [
                event(
                    .addHistoricalGame(
                        id: "h1",
                        seasonId: nil,
                        context: GameContext(date: "2026-09-01", opponent: "Northside"),
                        entries: [
                            RawHistoricalEntry(playerId: "p1", servesIn: 3, servesOut: 9),
                            RawHistoricalEntry(playerId: "p2", servesIn: 4, servesOut: 2),
                        ],
                        notes: GameNotes(wentWell: "Good talk"),
                        result: .value(.lost)
                    )
                )
            ]
        )
    }

    private func corrected(_ state: AppState) -> AppState {
        apply(
            state,
            .editHistoricalGame(
                id: "h1",
                context: GameContext(date: "2026-09-01", opponent: "Northside Hawks"),
                entries: [
                    RawHistoricalEntry(playerId: "p1", servesIn: 9, servesOut: 3),
                    RawHistoricalEntry(playerId: "p2", servesIn: 4, servesOut: 2),
                ],
                notes: GameNotes(wentWell: "Good talk", needsWork: "Serve deep"),
                result: .value(.won)
            )
        )
    }

    @Test("The figures become what was actually on the sheet")
    func replacesTheFigures() {
        let game = corrected(transcribed).game(id: "h1")
        let entry = game?.entries.first { $0.playerId == "p1" }
        #expect(entry?.servesIn == 9)
        #expect(entry?.servesOut == 3)
    }

    @Test("A player left alone keeps what they had")
    func leavesTheRestAlone() {
        let entry = corrected(transcribed).game(id: "h1")?.entries.first { $0.playerId == "p2" }
        #expect(entry?.servesIn == 4)
        #expect(entry?.servesOut == 2)
    }

    @Test("The game keeps its identity and its season")
    func staysTheSameGame() {
        let before = transcribed.game(id: "h1")
        let after = corrected(transcribed).game(id: "h1")
        #expect(after?.id == before?.id)
        #expect(after?.seasonId == before?.seasonId)
        #expect(after?.kind == .historical)
        #expect(corrected(transcribed).games.count == 1, "correcting is not adding")
    }

    @Test("Everything else on the sheet is corrected with it")
    func carriesContextNotesAndResult() {
        let game = corrected(transcribed).game(id: "h1")
        #expect(game?.context.opponent == "Northside Hawks")
        #expect(game?.notes.needsWork == "Serve deep")
        #expect(game?.result == .won)
    }

    @Test("A game that is not there cannot be corrected")
    func refusesAGameThatIsGone() {
        let reason = refusal(
            transcribed,
            .editHistoricalGame(
                id: "nope",
                context: GameContext(),
                entries: [RawHistoricalEntry(playerId: "p1", servesIn: 1, servesOut: 0)],
                notes: GameNotes(),
                result: .absent
            )
        )
        #expect(reason == "That game no longer exists.")
    }

    @Test("A count that is not a whole number is refused rather than guessed at")
    func refusesAnEmptyCount() {
        let reason = refusal(
            transcribed,
            .editHistoricalGame(
                id: "h1",
                context: GameContext(),
                entries: [RawHistoricalEntry(playerId: "p1", servesIn: nil, servesOut: 3)],
                notes: GameNotes(),
                result: .absent
            )
        )
        #expect(reason != nil)
    }

    @Test("A refused correction leaves the sheet exactly as it was")
    func refusalChangesNothing() {
        let before = transcribed
        let after = apply(
            before,
            .editHistoricalGame(
                id: "h1",
                context: GameContext(),
                entries: [RawHistoricalEntry(playerId: "p1", servesIn: -1, servesOut: 0)],
                notes: GameNotes(),
                result: .absent
            )
        )
        #expect(after.game(id: "h1")?.entries == before.game(id: "h1")?.entries)
    }
}
