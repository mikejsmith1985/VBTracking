// Questions the rest of the app asks of a replayed state.
//
// Every one of these is derived on read. None of it is stored, which is why an undo cannot
// leave a total disagreeing with the serves underneath it.
import Foundation

extension State {
    /// The season new games belong to, or nil.
    public var activeSeason: Season? {
        season(id: activeSeasonId)
    }

    /// A season by id, or nil.
    public func season(id: String?) -> Season? {
        guard let id else { return nil }
        return seasons.first { $0.id == id }
    }

    /// A career player by id, or nil.
    public func player(id: String) -> Player? {
        players.first { $0.id == id }
    }

    /// A season's roster: player id, name, and the number worn THAT season.
    public func members(ofSeason seasonId: String?) -> [RosterEntry] {
        guard let season = season(id: seasonId) else { return [] }
        return season.members.compactMap { member in
            guard let player = player(id: member.playerId) else { return nil }
            return RosterEntry(id: player.id, name: player.name, number: member.number)
        }
    }

    /// The number a player wore in a given season, or nil. A number never lives on a person.
    public func number(inSeason seasonId: String?, playerId: String) -> String? {
        season(id: seasonId)?.members.first { $0.playerId == playerId }?.number
    }

    /// A player on the ACTIVE season's roster, or nil. Carries that season's number.
    public func rosterEntry(id: String) -> RosterEntry? {
        roster.first { $0.id == id }
    }

    /// A game by id, or nil.
    public func game(id: String?) -> Game? {
        guard let id else { return nil }
        return games.first { $0.id == id }
    }

    /// Every game recorded in a season.
    public func games(inSeason seasonId: String) -> [Game] {
        games.filter { $0.seasonId == seasonId }
    }

    /// Every game a player appears in, across every season.
    public func games(forPlayer playerId: String) -> [Game] {
        games.filter { $0.involves(playerId: playerId) }
    }

    /// Every season a player has been a member of.
    public func seasons(forPlayer playerId: String) -> [Season] {
        seasons.filter { season in season.members.contains { $0.playerId == playerId } }
    }

    /// The game currently being played, or nil.
    public var currentGame: Game? {
        game(id: currentGameId)
    }

    /// The match in progress within the current game, or nil. Games from paper have none.
    public var currentMatch: Match? {
        guard let game = currentGame, game.kind == .tracked else { return nil }
        return game.matches.first { $0.status == .inProgress }
    }

    /// The six on court for the match in progress, as it stands now, or nil.
    public var currentLineup: [String?]? {
        currentMatch?.lineup
    }

    /// True when the current game is over: every match it holds has ended.
    ///
    /// Not "three matches have ended" — a game stopped early has fewer, and it is still over.
    public var isGameComplete: Bool {
        guard let game = currentGame, game.kind == .tracked else { return false }
        return !game.matches.isEmpty && game.matches.allSatisfy { $0.status == .ended }
    }

    /// Who is serving right now, derived from the open turn rather than stored.
    ///
    /// Deriving it removes any chance of an active-server pointer disagreeing with the turn
    /// list after an undo.
    public var activeServerId: String? {
        currentMatch?.openTurn?.playerId
    }
}

extension Game {
    /// True when the player took any part in the game — served, or was on court.
    public func involves(playerId: String) -> Bool {
        if kind == .historical {
            return entries.contains { $0.playerId == playerId }
        }
        return matches.contains { match in match.turns.contains { $0.playerId == playerId } }
    }
}

extension Match {
    /// Where a player stands in the serving order, or nil when they are not in it.
    public func lineupPosition(of playerId: String) -> Int? {
        guard let lineup else { return nil }
        return lineup.firstIndex(of: playerId)
    }

    /// The lineup position due to serve next, or nil when the order cannot say.
    ///
    /// One past the most recent turn that occupied a position. An off-lineup turn occupies
    /// the position that was due, so it counts here too — which is what stops the order
    /// lagging by one after a substitution nobody entered.
    public var nextRotationPosition: Int? {
        guard lineup != nil, let last = lastKnownPosition else { return nil }
        return (last + 1) % lineupSize
    }

    /// Who the rotation says serves next, or nil when it cannot say.
    public var nextRotationPlayerId: String? {
        guard let position = nextRotationPosition, let lineup else { return nil }
        return position < lineup.count ? lineup[position] : nil
    }

    /// The most recent turn that consumed a rotation position.
    var lastKnownPosition: Int? {
        for turn in turns.reversed() {
            if let position = turn.lineupPosition { return position }
        }
        return nil
    }

    /// Turns that actually happened. A turn opened by a selection or by the rotation holds
    /// no serves until one is recorded, and counting it would credit a turn not taken.
    var playedTurns: [Turn] {
        turns.filter { !$0.serves.isEmpty }
    }
}
