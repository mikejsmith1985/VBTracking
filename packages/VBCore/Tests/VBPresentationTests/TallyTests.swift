// Colour on the tally board means a person, and the rotate alert on the wrist.
//
// Both are decisions a view would otherwise make for itself, and neither can be looked at
// on this workstation — so both are settled here, where they can be measured.
import Foundation
import Testing

@testable import VBCore
@testable import VBPresentation

/// Three players serving in turn, twice round.
private func board() -> AppState {
    var events = roster(9) + [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))]
    for playerId in ["p1", "p2", "p3", "p1", "p2"] {
        events += turn(playerId, points: 1)
    }
    return replay(events)
}

@Suite("Grouping the tally board")
struct TallyRowTests {
    @Test("One row per player, in the order they first served")
    func onePerPlayer() {
        let rows = tallyRows(of: board().currentMatch)
        #expect(rows.map(\.playerId) == ["p1", "p2", "p3"])
        #expect(rows.map(\.playerIndex) == [0, 1, 2])
    }

    @Test("A player's turns are all on their own row")
    func turnsGatherOnTheRow() {
        let rows = tallyRows(of: board().currentMatch)
        #expect(rows[0].turns.count == 2, "p1 served twice")
        #expect(rows[2].turns.count == 1)
    }

    @Test("A row adds up its own turns")
    func rowTotals() {
        let rows = tallyRows(of: board().currentMatch)
        #expect(rows[0].figures.serves == 4, "two turns of one point and a closing serve")
        #expect(rows[0].figures.points == 2)
    }

    @Test("A player's place in the order does not move when they serve again")
    func placeIsStable() {
        var events = roster(9) + [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))]
        events += turn("p1", points: 0)
        let early = tallyRows(of: replay(events).currentMatch)

        events += turn("p2", points: 0) + turn("p1", points: 0)
        let later = tallyRows(of: replay(events).currentMatch)

        #expect(early[0].playerIndex == 0)
        #expect(later[0].playerIndex == 0, "a colour that moved mid-match would mean nothing")
        #expect(later[0].color == early[0].color)
    }

    @Test("A turn with no serves in it is not on the board")
    func openTurnIsNotARow() {
        let state = build(
            roster(3),
            [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))],
            [event(.selectServer(playerId: "p1"))]
        )
        #expect(tallyRows(of: state.currentMatch).isEmpty)
    }

    @Test("With no match there is no board")
    func noMatchNoRows() {
        #expect(tallyRows(of: nil).isEmpty)
    }
}

@Suite("What a colour on the board means")
struct TallyColorTests {
    @Test("Two players never share a colour")
    func playersAreDistinct() {
        let rows = tallyRows(of: board().currentMatch)
        let colors = Set(rows.map(\.color))
        #expect(colors.count == rows.count)
    }

    @Test("Every player on a full palette's worth is a different colour")
    func sixPlayersSixColours() {
        let colors = Set((0..<playerPalette.count).map { colorForPlayer($0) })
        #expect(colors.count == playerPalette.count)
    }

    @Test("A seventh player is not mistaken for the first")
    func theSeventhIsDarker() {
        #expect(colorForPlayer(6) != colorForPlayer(0), "the hue wraps, so the shade must not")
    }

    @Test("A player's own turns are told apart, but stay theirs")
    func turnsAreShadesOfOneHue() {
        let shades = (0..<turnShades.count).map { colorForTurn(playerIndex: 0, turnIndex: $0) }
        #expect(Set(shades).count == turnShades.count, "four turns, four shades")

        // Same hue throughout: what changes between a player's turns is lightness alone,
        // which is what keeps the colour reading as that person.
        for shade in shades {
            #expect(hue(of: shade).isApproximately(playerPalette[0].hue, within: 2))
        }
    }

    @Test("A turn's colour comes from who served it, not when")
    func colourFollowsThePlayer() {
        let match = board().currentMatch
        let rows = tallyRows(of: match)

        let firstOfP1 = rows[0].turns[0]
        let secondOfP1 = rows[0].turns[1]
        let onlyOfP3 = rows[2].turns[0]

        #expect(hue(of: color(ofTurn: firstOfP1, in: match))
            .isApproximately(hue(of: color(ofTurn: secondOfP1, in: match)), within: 2))
        #expect(!hue(of: color(ofTurn: onlyOfP3, in: match))
            .isApproximately(hue(of: color(ofTurn: firstOfP1, in: match)), within: 20))
    }

    @Test("The board's key names every player who has served, once")
    func keyCoversTheBoard() {
        let key = tallyKey(of: board().currentMatch)
        #expect(key.map(\.playerId) == ["p1", "p2", "p3"])
        #expect(Set(key.map(\.color)).count == 3)
    }

    @Test("Every colour stays inside the band that reads on the dark board")
    func everyColourIsLegible() {
        for player in 0..<12 {
            for turn in 0..<turnShades.count {
                let value = colorForTurn(playerIndex: player, turnIndex: turn)
                #expect(value.count == 7 && value.hasPrefix("#"), "\(value) is not a colour")
                #expect(lightness(of: value) >= 0.30, "\(value) would vanish into the board")
                #expect(lightness(of: value) <= 0.92, "\(value) would glare")
            }
        }
    }

    @Test("Hue, saturation and lightness turn into the hex the app draws in")
    func hslConverts() {
        #expect(hex(hue: 0, saturation: 1, lightness: 0.5) == "#ff0000")
        #expect(hex(hue: 120, saturation: 1, lightness: 0.5) == "#00ff00")
        #expect(hex(hue: 240, saturation: 1, lightness: 0.5) == "#0000ff")
        #expect(hex(hue: 0, saturation: 0, lightness: 1) == "#ffffff")
        #expect(hex(hue: 0, saturation: 0, lightness: 0) == "#000000")
        #expect(hex(hue: 400, saturation: 1, lightness: 0.5) == "#ffaa00", "a hue past the wheel wraps")
    }
}

// MARK: - Reading a hex back

private func channels(of hex: String) -> (Double, Double, Double) {
    let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    let value = UInt64(digits, radix: 16) ?? 0
    return (
        Double((value >> 16) & 0xff) / 255,
        Double((value >> 8) & 0xff) / 255,
        Double(value & 0xff) / 255
    )
}

private func lightness(of hex: String) -> Double {
    let (red, green, blue) = channels(of: hex)
    return (max(red, green, blue) + min(red, green, blue)) / 2
}

private func hue(of hex: String) -> Double {
    let (red, green, blue) = channels(of: hex)
    let high = max(red, green, blue)
    let low = min(red, green, blue)
    let span = high - low
    guard span > 0 else { return 0 }

    let raw: Double =
        if high == red { 60 * (((green - blue) / span).truncatingRemainder(dividingBy: 6)) }
        else if high == green { 60 * ((blue - red) / span + 2) }
        else { 60 * ((red - green) / span + 4) }

    return (raw + 360).truncatingRemainder(dividingBy: 360)
}

extension Double {
    /// Hues that came back through eight bits per channel do not land exactly.
    fileprivate func isApproximately(_ other: Double, within tolerance: Double) -> Bool {
        let gap = abs(self - other)
        return min(gap, 360 - gap) <= tolerance
    }
}

// MARK: - The rule, on the wrist

@Suite("The five-serve rule as the wrist hears it")
struct ServeLimitNoticeTests {
    /// A match where `p1` has just taken their five, with `p2` next in the order.
    private func atTheLimit() -> AppState {
        var events = roster(9) + [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))]
        events += [event(.setLineup(playerIds: (1...6).map { "p\($0)" }))]
        events += [event(.selectServer(playerId: "p1"))]
        events += (0..<serveLimit).map { _ in event(.recordServe(outcome: .inPoint)) }
        return replay(events)
    }

    @Test("It is raised on the fifth serve, naming who finished and who is next")
    func raisedAtTheLimit() throws {
        let notice = try #require(ServeLimitNotice.raised(by: atTheLimit()))
        #expect(notice.finishedNumber == "1")
        #expect(notice.nextNumber == "2")
        #expect(notice.raisedAtServeCount == serveLimit)
    }

    @Test("It is not raised before the fifth")
    func silentBeforeTheLimit() {
        var events = roster(9) + [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))]
        events += [event(.setLineup(playerIds: (1...6).map { "p\($0)" }))]
        events += [event(.selectServer(playerId: "p1"))]
        events += (0..<(serveLimit - 1)).map { _ in event(.recordServe(outcome: .inPoint)) }

        #expect(ServeLimitNotice.raised(by: replay(events)) == nil)
    }

    @Test("It clears itself the moment the next serve is recorded")
    func clearsWhenPlayMovesOn() {
        let after = apply(atTheLimit(), .recordServe(outcome: .out))
        #expect(ServeLimitNotice.raised(by: after) == nil, "a notice that outlived the rally would be a lie")
    }

    @Test("Without an order it asks for a server rather than naming one")
    func noOrderNamesNobody() throws {
        var events = roster(3) + [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: false))]
        events += [event(.selectServer(playerId: "p1"))]
        events += (0..<serveLimit).map { _ in event(.recordServe(outcome: .inPoint)) }

        let notice = try #require(ServeLimitNotice.raised(by: replay(events)))
        #expect(notice.finishedNumber == "1")
        #expect(notice.nextNumber == nil, "the same player still holds the ball")
    }

    @Test("Two raisings sit at different counts, so the wrist can tell them apart")
    func raisingsAreDistinguishable() throws {
        let first = try #require(ServeLimitNotice.raised(by: atTheLimit()))

        var state = atTheLimit()
        for _ in 0..<serveLimit { state = apply(state, .recordServe(outcome: .inPoint)) }
        let second = try #require(ServeLimitNotice.raised(by: state))

        #expect(second.finishedNumber == "2", "the rotation moved the ball on")
        #expect(second.raisedAtServeCount != first.raisedAtServeCount)
    }

    @Test("It travels with the court, and survives the trip")
    func travelsInTheSnapshot() throws {
        let state = atTheLimit()
        let court = try #require(state.courtView())
        let snapshot = CourtSnapshot(
            court: court,
            sequence: 1,
            capturedAt: Date(),
            serveLimit: ServeLimitNotice.raised(by: state)
        )

        let data = try JSONEncoder().encode(snapshot)
        let read = try JSONDecoder().decode(CourtSnapshot.self, from: data)
        #expect(read.serveLimit == snapshot.serveLimit)
        #expect(read.serveLimit?.finishedNumber == "1")
    }

    @Test("A court sent with nothing raised carries nothing")
    func absentWhenNotRaised() throws {
        let quiet = build(roster(9), [event(.startGame(id: "g1", seasonId: nil, rotatesAtServeLimit: true))])
        let court = try #require(quiet.courtView())
        let snapshot = CourtSnapshot(court: court, sequence: 1, capturedAt: Date(), serveLimit: ServeLimitNotice.raised(by: quiet))

        #expect(snapshot.serveLimit == nil)

        // And an older watch reading a snapshot that predates the field is not broken by it.
        let legacy = #"{"sequence":1,"capturedAt":0,"scopeLabel":"Match 1","hasOrder":false,"slots":[]}"#
        let read = try JSONDecoder().decode(CourtSnapshot.self, from: Data(legacy.utf8))
        #expect(read.serveLimit == nil)
    }
}

// MARK: - The coach's own choice

@Suite("What the coach has turned off")
struct WatchPreferenceTests {
    private let notice = ServeLimitNotice(finishedNumber: "5", nextNumber: "7", raisedAtServeCount: 5)

    @Test("A coach who has chosen nothing still gets the rule they asked for")
    func defaultsAreOn() {
        let preferences = WatchPreferences()
        #expect(preferences.isRotateAlertOn)
        #expect(preferences.isRotateBuzzOn)
        #expect(preferences.shouldShow(notice))
        #expect(preferences.shouldBuzz)
    }

    @Test("Turning the alert off shows nothing at all")
    func alertOffShowsNothing() {
        let preferences = WatchPreferences(isRotateAlertOn: false)
        #expect(preferences.shouldShow(notice) == false)
    }

    @Test("Silencing it keeps the reminder and drops the buzzing")
    func buzzOffKeepsTheAlert() {
        let preferences = WatchPreferences(isRotateAlertOn: true, isRotateBuzzOn: false)
        #expect(preferences.shouldShow(notice))
        #expect(preferences.shouldBuzz == false)
    }

    @Test("There is no state where an invisible alert vibrates")
    func noBuzzWithoutAnAlert() {
        let preferences = WatchPreferences(isRotateAlertOn: false, isRotateBuzzOn: true)
        #expect(preferences.shouldShow(notice) == false)
        #expect(preferences.shouldBuzz == false, "a buzz with nothing on screen explains itself to nobody")
    }

    @Test("Nothing is shown when the rule has not fired, whatever the settings say")
    func nothingToShowWithoutANotice() {
        #expect(WatchPreferences().shouldShow(nil) == false)
    }

    @Test("The page says what has been turned off, in words")
    func summaryReadsBack() {
        #expect(WatchPreferences().summary.contains("buzzes"))
        #expect(WatchPreferences(isRotateAlertOn: true, isRotateBuzzOn: false).summary.contains("silently"))
        #expect(WatchPreferences(isRotateAlertOn: false).summary.contains("will not"))
    }

    @Test("A choice survives being written down and read back")
    func roundTrips() throws {
        let chosen = WatchPreferences(isRotateAlertOn: true, isRotateBuzzOn: false)
        let read = try JSONDecoder().decode(WatchPreferences.self, from: JSONEncoder().encode(chosen))
        #expect(read == chosen)
    }
}

@Suite("Reading a choice back out of storage")
struct PreferenceStorageTests {
    @Test("A key that was never written means the default, not off")
    func absenceIsTheDefault() {
        let preferences = WatchPreferences(storedRotateAlert: nil, storedRotateBuzz: nil)
        #expect(preferences.isRotateAlertOn, "a coach who never opened settings chose nothing")
        #expect(preferences.isRotateBuzzOn)
    }

    @Test("A choice that was written is honoured, including a false one")
    func storedChoicesAreKept() {
        let preferences = WatchPreferences(storedRotateAlert: false, storedRotateBuzz: true)
        #expect(preferences.isRotateAlertOn == false)
        #expect(preferences.isRotateBuzzOn)
    }

    @Test("Something stored that is not a choice is treated as no choice")
    func rubbishReadsAsTheDefault() {
        let preferences = WatchPreferences(storedRotateAlert: "yes", storedRotateBuzz: 0)
        #expect(preferences.isRotateAlertOn)
        #expect(preferences.isRotateBuzzOn)
    }
}
