// What each accepted event does to the state.
//
// Every function here takes a state and returns a new one. Nothing is mutated in place:
// undo replays the log from empty, so a state that could change after the fact would make
// undo report something that never happened.
import Foundation

// MARK: - Seasons

func withSeasonCreated(
    _ state: AppState,
    id: String,
    name: String,
    team: String,
    format: SeasonFormat
) -> AppState {
    var next = state
    next.seasons.append(
        Season(
            id: id,
            name: name.trimmed,
            team: team.trimmed,
            format: format,
            members: []
        )
    )
    next.activeSeasonId = state.activeSeasonId ?? id
    return next
}

func withSeasonRenamed(_ state: AppState, id: String, name: String, team: String?) -> AppState {
    mapSeason(state, id) { season in
        var next = season
        next.name = name.trimmed
        next.team = (team ?? season.team).trimmed
        return next
    }
}

/// A season always exists.
///
/// Requiring the operator to create one before adding a player would be ceremony; the first
/// is made for them, and can be renamed.
private func ensureSeason(_ state: AppState) -> AppState {
    if !state.seasons.isEmpty, state.activeSeasonId != nil { return state }
    return withSeasonCreated(
        state,
        id: "season-1",
        name: "Season 1",
        team: "My Team",
        format: .standard
    )
}

// MARK: - Roster

/// Adds a player to a season: the person is created when new, and given the number they
/// wear THIS season.
///
/// The number goes on the membership, never on the person — next season the same child may
/// wear a different one for a different team.
func withPlayerAdded(
    _ state: AppState,
    id: String,
    name: String,
    number: String,
    seasonId: String?
) -> AppState {
    var seeded = ensureSeason(state)
    let resolved = seasonIdFor(seeded, seasonId)

    if seeded.player(id: id) == nil {
        seeded.players.append(Player(id: id, name: name.trimmed))
    }

    return mapSeason(seeded, resolved) { season in
        var next = season
        next.members.append(SeasonMember(playerId: id, number: number.trimmed))
        return next
    }
}

/// Corrects the name career-wide, and the number for this season only.
func withPlayerEdited(
    _ state: AppState,
    id: String,
    name: String,
    number: String,
    seasonId: String?
) -> AppState {
    var next = state
    next.players = state.players.map { player in
        guard player.id == id else { return player }
        var edited = player
        edited.name = name.trimmed
        return edited
    }

    return mapSeason(next, seasonIdFor(state, seasonId)) { season in
        var edited = season
        edited.members = season.members.map { member in
            guard member.playerId == id else { return member }
            var updated = member
            updated.number = number.trimmed
            return updated
        }
        return edited
    }
}

/// The destructive removal kept from releases 001 and 002: it discards the player's
/// recorded turns, as its confirmation warned.
///
/// It is retained with its original meaning so that replaying an older log reproduces the
/// figures it produced then. Redefining it would change statistics for games already
/// played, which is the one thing a migration must never do. Release 003's roster screen
/// uses the non-destructive path instead.
func withPlayerRemoved(_ state: AppState, id: String, seasonId: String?) -> AppState {
    var next = state
    next.players = state.players.filter { $0.id != id }
    next.games = state.games.map { game in
        guard game.kind == .tracked else { return game }
        var edited = game
        edited.matches = game.matches.map { match in
            var updated = match
            updated.lineup = match.lineup?.map { $0 == id ? nil : $0 }
            updated.turns = renumber(match.turns.filter { $0.playerId != id })
            return updated
        }
        return edited
    }

    return mapSeason(next, seasonIdFor(state, seasonId)) { season in
        var edited = season
        edited.members = season.members.filter { $0.playerId != id }
        return edited
    }
}

/// Leaves the person, and everything they recorded, exactly where it is. Removing someone
/// from this year's squad says nothing about the serves they took last year.
func withMembershipRemoved(_ state: AppState, playerId: String, seasonId: String?) -> AppState {
    mapSeason(state, seasonIdFor(state, seasonId)) { season in
        var next = season
        next.members = season.members.filter { $0.playerId != playerId }
        return next
    }
}

// MARK: - Games

func withGameStarted(
    _ state: AppState,
    id: String,
    seasonId: String?,
    rotatesAtServeLimit: Bool
) -> AppState {
    var seeded = ensureSeason(state)
    let game = Game(
        id: id,
        seasonId: seasonIdFor(seeded, seasonId),
        kind: .tracked,
        matches: [Match(index: 0)],
        rotatesAtServeLimit: rotatesAtServeLimit
    )
    seeded.games.append(game)
    seeded.currentGameId = id
    return seeded
}

func withGameDiscarded(_ state: AppState, id: String) -> AppState {
    var next = state
    next.games = state.games.filter { $0.id != id }
    if state.currentGameId == id { next.currentGameId = nil }
    return next
}

/// A game copied from paper: per player, serves in and serves out, at game level.
///
/// It holds no matches and no turns, because that detail was never written down.
/// Synthesising them would report turn counts that never happened.
func withHistoricalGameAdded(
    _ state: AppState,
    id: String,
    seasonId: String?,
    context: GameContext,
    entries: [RawHistoricalEntry],
    notes: GameNotes,
    result: ResultField
) -> AppState {
    var seeded = ensureSeason(state)
    seeded.games.append(
        Game(
            id: id,
            seasonId: seasonIdFor(seeded, seasonId),
            kind: .historical,
            context: context,
            notes: notes,
            entries: entries.compactMap(\.checked),
            recordedResult: result.recorded
        )
    )
    return seeded
}

func withHistoricalGameEdited(
    _ state: AppState,
    id: String,
    context: GameContext,
    entries: [RawHistoricalEntry],
    notes: GameNotes,
    result: ResultField
) -> AppState {
    mapGame(state, id) { game in
        var next = game
        next.context = context
        next.notes = notes
        next.entries = entries.compactMap(\.checked)
        if case let .value(value) = result { next.recordedResult = value }
        return next
    }
}

// MARK: - Ending

func withMatchEnded(_ state: AppState, result: MatchResult) -> AppState {
    guard let game = state.currentGame, let ending = state.currentMatch else { return state }

    var ended = ending
    ended.status = .ended
    ended.result = result
    ended.turns = closeOpenTurn(ending.turns)

    var matches = game.matches.map { $0.index == ended.index ? ended : $0 }
    // The next match starts from this one's lineup: with nine on a roster the six on court
    // are usually close, and editing beats rebuilding.
    if ended.index < matchesPerGame - 1 {
        matches.append(Match(index: ended.index + 1, lineup: ended.lineup))
    }

    return mapGame(state, game.id) { each in
        var next = each
        next.matches = matches
        return next
    }
}

/// Ends the game where it stands.
///
/// The match in progress is closed and keeps every serve it holds; no further match opens,
/// because none was played.
func withGameEnded(_ state: AppState, result: MatchResult) -> AppState {
    guard let game = state.currentGame, let ending = state.currentMatch else { return state }

    var ended = ending
    ended.status = .ended
    ended.result = result
    ended.turns = closeOpenTurn(ending.turns)

    return mapGame(state, game.id) { each in
        var next = each
        next.matches = each.matches.map { $0.index == ended.index ? ended : $0 }
        return next
    }
}

// MARK: - The match in progress

/// Puts one player at one place in the serving order, before a serve has been taken.
///
/// A player already standing somewhere else moves rather than appears twice: the operator
/// who taps a player into the service corner has decided they serve first, and leaving a
/// copy of them at their old place would build a rotation of five real people and a ghost.
func withPlayerPlaced(_ state: AppState, playerId: String, lineupIndex: Int) -> AppState {
    updateCurrentMatch(state) { match, _ in
        guard (0..<lineupSize).contains(lineupIndex) else { return match }

        // A match with no order yet gets an empty one to place into, rather than refusing
        // the first tap for want of the thing that tap is creating.
        var lineup = match.lineup ?? Array(repeating: nil, count: lineupSize)
        while lineup.count < lineupSize { lineup.append(nil) }

        lineup = lineup.map { $0 == playerId ? nil : $0 }
        lineup[lineupIndex] = playerId

        var next = match
        next.lineup = lineup
        return next
    }
}

func withSubstitution(_ state: AppState, outPlayerId: String, inPlayerId: String) -> AppState {
    updateCurrentMatch(state) { match, _ in
        guard let lineup = match.lineup, let position = lineup.firstIndex(of: outPlayerId) else {
            return match
        }

        var next = match
        next.lineup = lineup.enumerated().map { index, playerId in
            index == position ? inPlayerId : playerId
        }
        next.substitutions.append(
            Substitution(
                outPlayerId: outPlayerId,
                inPlayerId: inPlayerId,
                position: position,
                afterTurnOrdinal: match.playedTurns.count - 1
            )
        )

        guard let open = match.openTurn, open.playerId == outPlayerId else { return next }

        // The outgoing player was serving. Their turn is closed with the serves they
        // actually took -- reassigning those to the incoming player would credit serves
        // never made -- and a fresh turn opens for whoever came on, at the same position.
        let closed = closeOpenTurn(match.turns)
        next.turns = closed + [
            newTurn(playerId: inPlayerId, ordinal: closed.count, lineup: next.lineup)
        ]
        return next
    }
}

func withServerSelected(_ state: AppState, playerId: String) -> AppState {
    updateCurrentMatch(state) { match, _ in
        let pending = pendingPosition(for: match)
        let closed = closeOpenTurn(match.turns)
        var next = match
        next.turns = closed + [
            newTurn(
                playerId: playerId,
                ordinal: closed.count,
                lineup: match.lineup,
                pendingPosition: pending
            )
        ]
        return next
    }
}

func withServeRecorded(_ state: AppState, outcome: Outcome) -> AppState {
    updateCurrentMatch(state) { match, game in
        var next = match
        next.turns = match.turns.map { turn in
            guard turn.isOpen else { return turn }
            var updated = turn
            updated.serves.append(Serve(outcome: outcome))
            updated.isOpen = outcome == .inPoint
            return updated
        }
        return advanceRotation(closeAtServeLimit(next, rotates: game.rotatesAtServeLimit))
    }
}

/// Ends a turn once the server has taken their five, even when the fifth won the point.
///
/// Without this a server on a run never rotates: the turn only closed on a serve that lost
/// the rally, so five straight points left them serving forever while the order stood still.
///
/// It ends the turn; it does not discard anything. A referee who miscounts and lets someone
/// serve a sixth time is recorded by choosing that player again — a second turn, every serve
/// kept. Only where a lineup exists: with manual selection there is no next server to move
/// to, and the operator is already deciding.
private func closeAtServeLimit(_ match: Match, rotates: Bool) -> Match {
    guard rotates, match.lineup != nil else { return match }
    guard let open = match.openTurn, open.serves.count >= serveLimit else { return match }

    var next = match
    next.turns = match.turns.map { turn in
        guard turn.isOpen else { return turn }
        var updated = turn
        updated.isOpen = false
        return updated
    }
    return next
}

/// Hands the serve to the next player in the order when a turn has just closed.
///
/// This happens inside the serve transition rather than as an event of its own, and that is
/// the whole trick: popping the serve removes the advance along with it, so one undo
/// reverses one operator action.
private func advanceRotation(_ match: Match) -> Match {
    guard let lineup = match.lineup else { return match }
    if match.openTurn != nil { return match }
    guard let position = match.nextRotationPosition, position < lineup.count else { return match }
    // The slot was emptied by a roster removal.
    guard let playerId = lineup[position] else { return match }

    var next = match
    next.turns.append(newTurn(playerId: playerId, ordinal: match.turns.count, lineup: lineup))
    return next
}

// MARK: - Corrections

func withTurnServesSet(
    _ state: AppState,
    gameId: String,
    matchIndex: Int,
    ordinal: Int,
    outcomes: [String]
) -> AppState {
    let serves = outcomes.compactMap(Outcome.init(rawValue:)).map(Serve.init(outcome:))
    return mapTurn(state, gameId: gameId, matchIndex: matchIndex, ordinal: ordinal) { turn in
        var next = turn
        next.serves = serves
        // A turn still in progress ends if its last serve no longer wins the rally, because
        // that is what ends a turn. It is never reopened: the serves after it in the match
        // already happened, and handing the ball back now would rewrite them.
        next.isOpen = turn.isOpen && serves.last?.outcome == .inPoint
        return next
    }
}

/// The turn keeps its place in the order. Only who took it changes — a serve recorded
/// against the wrong player is still a serve that happened, at that point in the match.
func withTurnReassigned(
    _ state: AppState,
    gameId: String,
    matchIndex: Int,
    ordinal: Int,
    playerId: String
) -> AppState {
    mapTurn(state, gameId: gameId, matchIndex: matchIndex, ordinal: ordinal) { turn in
        var next = turn
        next.playerId = playerId
        next.isOffLineup = turn.lineupSnapshot.map { !$0.contains(playerId) } ?? false
        return next
    }
}

/// The added turn takes no rotation position: it is a record of something that happened,
/// and giving it a position would move who the app thinks serves next in a match still
/// being played. It copies the lineup that was on court around it, so time on court still
/// counts for the players who were standing there.
func withTurnInserted(
    _ state: AppState,
    gameId: String,
    matchIndex: Int,
    afterOrdinal: Int,
    playerId: String
) -> AppState {
    mapMatch(state, gameId: gameId, matchIndex: matchIndex) { match in
        let neighbour = match.turns.indices.contains(afterOrdinal)
            ? match.turns[afterOrdinal]
            : match.turns.first

        let added = Turn(
            playerId: playerId,
            ordinal: afterOrdinal + 1,
            colorIndex: 0,
            lineupPosition: nil,
            isOffLineup: false,
            lineupSnapshot: neighbour?.lineupSnapshot,
            serves: [Serve(outcome: .out)],
            isOpen: false
        )

        var turns = match.turns
        turns.insert(added, at: min(afterOrdinal + 1, turns.count))

        var next = match
        next.turns = renumber(turns)
        return next
    }
}

// MARK: - Turn helpers

/// A turn records the position it was served from and who was on court at the time.
///
/// A server who is not in the lineup still occupies the position that was due: tapping
/// someone off-lineup nearly always means a substitution has not been entered yet, and
/// leaving the position unconsumed would make the order lag by one for the rest of the
/// match.
func newTurn(
    playerId: String,
    ordinal: Int,
    lineup: [String?]?,
    pendingPosition: Int? = nil
) -> Turn {
    guard let lineup else {
        return Turn(playerId: playerId, ordinal: ordinal, colorIndex: colorIndexForTurn(ordinal))
    }

    let position = lineup.firstIndex(of: playerId)
    return Turn(
        playerId: playerId,
        ordinal: ordinal,
        colorIndex: colorIndexForTurn(ordinal),
        lineupPosition: position ?? pendingPosition,
        isOffLineup: position == nil,
        lineupSnapshot: lineup.map { $0 ?? "" }
    )
}

/// The rotation position a newly chosen server takes over.
///
/// When the rotation has already opened a turn, that turn's position is the one being
/// replaced — not the one after it.
private func pendingPosition(for match: Match) -> Int? {
    if let open = match.openTurn, let position = open.lineupPosition { return position }
    return match.nextRotationPosition
}

/// Closes the open turn, discarding it entirely when it recorded no serves.
func closeOpenTurn(_ turns: [Turn]) -> [Turn] {
    turns
        .filter { !($0.isOpen && $0.serves.isEmpty) }
        .map { turn in
            guard turn.isOpen else { return turn }
            var next = turn
            next.isOpen = false
            return next
        }
}

/// Renumbers turns contiguously, so a deletion or an insertion leaves no gap and no
/// duplicate — and so a turn's colour still follows its place in the match.
func renumber(_ turns: [Turn]) -> [Turn] {
    turns.enumerated().map { index, turn in
        var next = turn
        next.ordinal = index
        next.colorIndex = colorIndexForTurn(index)
        return next
    }
}

// MARK: - Mapping helpers

func mapSeason(_ state: AppState, _ seasonId: String, _ transform: (Season) -> Season) -> AppState {
    var next = state
    next.seasons = state.seasons.map { $0.id == seasonId ? transform($0) : $0 }
    return next
}

func mapGame(_ state: AppState, _ gameId: String, _ transform: (Game) -> Game) -> AppState {
    var next = state
    next.games = state.games.map { $0.id == gameId ? transform($0) : $0 }
    return next
}

func mapMatch(
    _ state: AppState,
    gameId: String,
    matchIndex: Int,
    _ transform: (Match) -> Match
) -> AppState {
    mapGame(state, gameId) { game in
        var next = game
        next.matches = game.matches.map { $0.index == matchIndex ? transform($0) : $0 }
        return next
    }
}

func mapTurn(
    _ state: AppState,
    gameId: String,
    matchIndex: Int,
    ordinal: Int,
    _ transform: (Turn) -> Turn
) -> AppState {
    mapMatch(state, gameId: gameId, matchIndex: matchIndex) { match in
        var next = match
        next.turns = match.turns.map { $0.ordinal == ordinal ? transform($0) : $0 }
        return next
    }
}

func updateCurrentMatch(_ state: AppState, _ transform: (Match, Game) -> Match) -> AppState {
    guard let game = state.currentGame else { return state }
    return mapGame(state, game.id) { each in
        var next = each
        next.matches = each.matches.map { match in
            match.status == .inProgress ? transform(match, each) : match
        }
        return next
    }
}

/// `roster` is the ACTIVE season's members with their names and that season's numbers.
///
/// Recomputed on every change and never stored — a number resolved through a season is the
/// whole point of release 003, and a cached copy is how it would drift.
func withActiveRoster(_ state: AppState) -> AppState {
    var next = state
    next.roster = state.members(ofSeason: state.activeSeasonId)
    return next
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
