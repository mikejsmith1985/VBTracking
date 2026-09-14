// What a paper sheet looks like when it is opened for correcting.
//
// The rule that matters here is the oldest one in the project: a figure nobody wrote down is
// a dash, never a nought. On a sheet being corrected that has teeth, because a player who was
// not on it must show up with an empty box to type into -- not with a zero that says they
// served and missed.
import Testing
import VBCore

@testable import VBPresentation

@Suite("A paper sheet opened for correcting")
struct PaperSheetTests {
    private let squad = [
        RosterEntry(id: "p1", name: "Avery", number: "4"),
        RosterEntry(id: "p2", name: "Riley", number: "5"),
        RosterEntry(id: "p3", name: "Jordan", number: "7"),
    ]

    private var recorded: [HistoricalEntry] {
        [
            HistoricalEntry(playerId: "p1", servesIn: 9, servesOut: 3),
            HistoricalEntry(playerId: "p2", servesIn: 0, servesOut: 4),
        ]
    }

    @Test("Every player on the season's roster gets a row")
    func offersARowPerPlayer() {
        let rows = PaperSheet.rows(roster: squad, entries: recorded)
        #expect(rows.map(\.playerId) == ["p1", "p2", "p3"])
    }

    @Test("A player who was on the sheet shows what the sheet said")
    func carriesTheRecordedFigures() {
        let row = PaperSheet.rows(roster: squad, entries: recorded).first { $0.playerId == "p1" }
        #expect(row?.servesIn == 9)
        #expect(row?.servesOut == 3)
    }

    @Test("A recorded nought is a nought, because somebody wrote it down")
    func keepsARecordedZero() {
        let row = PaperSheet.rows(roster: squad, entries: recorded).first { $0.playerId == "p2" }
        #expect(row?.servesIn == 0, "nought serves in is a figure, not an absence")
    }

    @Test("A player who was never on the sheet has no figures at all")
    func leavesAnAbsentPlayerBlank() {
        let row = PaperSheet.rows(roster: squad, entries: recorded).first { $0.playerId == "p3" }
        #expect(row?.servesIn == nil, "nought here would say they served and missed")
        #expect(row?.servesOut == nil)
    }

    @Test("A sheet nobody has touched carries nothing to save")
    func sendsNothingWhenUnchanged() {
        let rows = PaperSheet.rows(roster: squad, entries: recorded)
        #expect(PaperSheet.hasChanges(rows, against: recorded) == false)
    }

    @Test("A corrected figure is a change worth saving")
    func noticesACorrection() {
        var rows = PaperSheet.rows(roster: squad, entries: recorded)
        rows[0].servesIn = 11
        #expect(PaperSheet.hasChanges(rows, against: recorded))
    }

    @Test("Only players with both counts filled in are sent")
    func sendsOnlyCompleteRows() {
        var rows = PaperSheet.rows(roster: squad, entries: recorded)
        rows[2].servesIn = 6
        // servesOut is still blank, so the row is half-typed and must not be saved as a nought.
        #expect(PaperSheet.entries(from: rows).map(\.playerId) == ["p1", "p2"])
    }

    @Test("A player filled in completely joins the sheet")
    func addsAPlayerWhoWasMissed() {
        var rows = PaperSheet.rows(roster: squad, entries: recorded)
        rows[2].servesIn = 6
        rows[2].servesOut = 2
        let entries = PaperSheet.entries(from: rows)
        #expect(entries.map(\.playerId) == ["p1", "p2", "p3"])
        #expect(entries.last?.servesIn == 6)
    }
}
