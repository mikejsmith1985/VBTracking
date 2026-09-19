// The rally score, which is half derived and half recorded.
//
// The half that is derived is the half that was always right: our own serves already say who
// won every rally we served. The half that is recorded is the one nobody was writing down --
// the rallies played while the other team had the ball.
import Testing
import VBCore

@testable import VBPresentation

@Suite("The score of a rally-scored match")
struct MatchScoreTests {
    /// A turn of serves by one player, as the reducer would leave it.
    private func turn(_ outcomes: [Outcome]) -> Turn {
        Turn(
            playerId: "p1",
            ordinal: 1,
            colorIndex: 0,
            serves: outcomes.map { Serve(outcome: $0) },
            isOpen: false
        )
    }

    private func match(_ turns: [Turn], rallies: [Bool]) -> Match {
        Match(index: 0, turns: turns, opponentServeRallies: rallies)
    }

    @Test("Nothing recorded from the other team's serves means no score at all")
    func staysSilentUntilSomebodyKeepsIt() {
        // Our half alone would say the opposition scored nothing, which is a lie with a
        // number on it. A dash is the honest answer, same as any figure never recorded.
        let onlyOurServes = match([turn([.inPoint, .inPoint, .out])], rallies: [])
        #expect(onlyOurServes.rallyScore == nil)
    }

    @Test("Our serves decide every rally we served")
    func readsOurOwnServes() {
        // Three points to us, and the two that ended our turns are points to them: under
        // rally scoring the side that wins the rally takes the point whoever served.
        let serving = match([turn([.inPoint, .inPoint, .out]), turn([.inPoint, .inNoPoint])], rallies: [false])
        let score = serving.rallyScore
        #expect(score?.us == 3)
        #expect(score?.them == 3, "two lost serves plus one rally they won on their own serve")
    }

    @Test("Rallies on their serve go to whoever won them")
    func countsTheirServeRallies() {
        let theyScoredThreeWeSidedOut = match([], rallies: [false, false, false, true])
        #expect(theyScoredThreeWeSidedOut.rallyScore == Scoreboard(us: 1, them: 3))
    }

    @Test("A whole game adds up")
    func addsUpAcrossBoth() {
        // Two serve turns and a spell of receiving in between.
        let game = match(
            [turn([.inPoint, .inPoint, .inNoPoint]), turn([.inPoint, .out])],
            rallies: [false, false, true, false, true]
        )
        // Ours: three serves that scored, plus two rallies won receiving.
        // Theirs: two serves that ended a turn, plus three rallies won serving.
        #expect(game.rallyScore == Scoreboard(us: 5, them: 5))
    }

    @Test("Every rally belongs to exactly one side")
    func losesNoRally() {
        let game = match(
            [turn([.inPoint, .out]), turn([.inPoint, .inPoint, .inNoPoint])],
            rallies: [true, false, false]
        )
        guard let score = game.rallyScore else { return #expect(Bool(false), "there is a score here") }

        // Five serves and three rallies received is eight rallies, and eight points.
        #expect(score.us + score.them == 8, "a rally that scored for nobody would be a bug")
    }

    @Test("A correction moves the score with it")
    func followsACorrection() {
        let before = match([turn([.inPoint, .inPoint])], rallies: [true])
        // The operator corrects the second serve: it landed in but won nothing.
        let after = match([turn([.inPoint, .inNoPoint])], rallies: [true])

        #expect(before.rallyScore == Scoreboard(us: 3, them: 0))
        #expect(after.rallyScore == Scoreboard(us: 2, them: 1), "the point changed hands, not vanished")
    }
}

@Suite("The score after the whistle")
struct ScoreLabelTests {
    private func turn(_ outcomes: [Outcome]) -> Turn {
        Turn(playerId: "p1", ordinal: 1, colorIndex: 0, serves: outcomes.map { Serve(outcome: $0) }, isOpen: false)
    }

    private func match(_ index: Int, _ outcomes: [Outcome], rallies: [Bool]) -> Match {
        Match(index: index, turns: [turn(outcomes)], opponentServeRallies: rallies)
    }

    @Test("A finished match says the score, not a count of points on serve")
    func labelsTheScore() {
        // The bug this exists for: the score was on screen while a match was being played
        // and nowhere at all afterwards, because every heading printed points on serve.
        let played = match(0, [.inPoint, .inPoint, .out], rallies: [false, true])
        #expect(played.scoreLabel == "3\u{2013}2")
    }

    @Test("A match nobody scored still says something")
    func fallsBackToPointsOnServe() {
        // Old games, and games tracked only for serve figures, have no rally score. Saying
        // nothing would be worse than saying what is known.
        let unscored = match(0, [.inPoint, .inPoint, .out], rallies: [])
        #expect(unscored.scoreLabel == "2 pts")
    }

    @Test("A game gives every match's score, in order")
    func linesUpTheMatches() {
        var game = Game(id: "g1", seasonId: "s1", kind: .tracked)
        game.matches = [
            match(0, [.inPoint, .inPoint, .out], rallies: [false]),
            match(1, [.inPoint, .out], rallies: [true, false, false]),
        ]
        // Match by match, never added together: a game is decided set by set, and one
        // number would describe a game nobody played.
        #expect(game.scoreLine == "2\u{2013}2 \u{00B7} 2\u{2013}3")
    }

    @Test("A game nobody scored has no score line at all")
    func staysSilentWithoutAScore() {
        var game = Game(id: "g1", seasonId: "s1", kind: .tracked)
        game.matches = [match(0, [.inPoint, .out], rallies: [])]
        #expect(game.scoreLine == nil)
    }
}
