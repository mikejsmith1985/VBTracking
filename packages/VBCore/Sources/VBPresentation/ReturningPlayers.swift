// Who could be brought back onto this season's roster.
//
// Taking somebody off a roster leaves the person and every serve they ever took exactly where
// they are -- a jersey number belongs to a season, a player does not. But adding a name back
// afterwards made a new person with a fresh career, so a player who left in October and
// returned in November had two records and neither of them was true.
//
// This is the list of people the app already knows who are not on this season's roster. They
// are named with the number they last wore and what they have served, because a squad list of
// bare names cannot be told apart -- two seasons of a club team is a lot of people, and the
// question being answered is "is this the same girl".
import Foundation
import VBCore

/// Somebody the app already knows, who is not on this season's roster.
public struct ReturningPlayer: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String

    /// The number they last wore, offered as a starting point. Nil when they have never had
    /// one -- and never forced, because a number belongs to the season being joined.
    public let lastNumber: String?

    /// Serves recorded in their whole career, which is what tells one name from another.
    public let serves: Int

    public init(id: String, name: String, lastNumber: String?, serves: Int) {
        self.id = id
        self.name = name
        self.lastNumber = lastNumber
        self.serves = serves
    }

    /// What to say under the name. Nil when there is nothing worth saying.
    public var history: String? {
        switch (lastNumber, serves) {
        case let (number?, 0): "Last wore \(number)"
        case let (number?, count): "Last wore \(number) · \(count) serves recorded"
        case (nil, 0): nil
        case let (nil, count): "\(count) serves recorded"
        }
    }
}

/// Everybody the app knows who is not on the active season's roster, by name.
///
/// Sorted by name rather than by when they left: this is read as a squad list, and somebody
/// looking for a particular girl looks alphabetically.
public func playersWhoCouldReturn(to state: AppState) -> [ReturningPlayer] {
    let onRoster = Set(state.roster.map(\.id))
    let servesByPlayer = servesRecorded(in: state)

    return state.players
        .filter { !onRoster.contains($0.id) }
        .map { player in
            ReturningPlayer(
                id: player.id,
                name: player.name,
                lastNumber: lastNumberWorn(by: player.id, in: state),
                serves: servesByPlayer[player.id] ?? 0
            )
        }
        .sorted { left, right in
            if left.name != right.name { return left.name < right.name }
            return left.id < right.id
        }
}

/// The number somebody last wore, across every season the app holds.
///
/// Offered rather than applied. A number belongs to the season being joined, and the one they
/// wore two years ago may be on somebody else's back now -- so this fills a field the
/// operator can change, and never decides anything by itself.
private func lastNumberWorn(by playerId: String, in state: AppState) -> String? {
    state.seasons
        .compactMap { season in season.members.first { $0.playerId == playerId }?.number }
        .last { !$0.isEmpty }
}

/// Serves recorded per player across every game, which is how one name is told from another.
private func servesRecorded(in state: AppState) -> [String: Int] {
    var counted: [String: Int] = [:]
    for game in state.games {
        for turn in game.allTurns where !turn.serves.isEmpty {
            counted[turn.playerId, default: 0] += turn.serves.count
        }
    }
    return counted
}
