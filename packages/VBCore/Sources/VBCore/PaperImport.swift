// Reading a batch of games copied from paper.
//
// Kept apart from the backup reader on purpose: that one REPLACES everything and carries an
// event log; this one ADDS games and carries figures. Different verbs, different shapes.
//
// All or nothing. A partial import leaves the operator unable to tell what landed.
import Foundation

/// Marks a file as one of ours, so an unrelated JSON file is refused rather than read.
public let paperImportMarker = "vbtracking"
public let paperImportKind = "historical-games"

/// What came back from reading a batch.
public enum PaperImportResult: Equatable, Sendable {
    case ready([Event.Kind])
    case refused(String)

    public var events: [Event.Kind]? {
        if case let .ready(events) = self { return events }
        return nil
    }

    public var reason: String? {
        if case let .refused(reason) = self { return reason }
        return nil
    }
}

/// Parses a batch into events ready to record. Never throws; every failure is a reason.
public func parsePaperGames(
    _ text: String,
    season: Season?,
    members: [RosterEntry],
    makeId: () -> String
) -> PaperImportResult {
    guard let data = text.data(using: .utf8),
        let decoded = try? JSONDecoder().decode(JSONValue.self, from: data),
        let file = decoded.objectValue
    else {
        return .refused("That file is not readable. It may be damaged or incomplete.")
    }

    guard file["app"]?.stringValue == paperImportMarker,
        file["kind"]?.stringValue == paperImportKind
    else {
        return .refused("That file is not a Serve Tracker game import.")
    }
    guard let games = file["games"]?.arrayValue, !games.isEmpty else {
        return .refused("That file holds no games.")
    }
    guard let season else {
        return .refused("Create a season before importing games into it.")
    }

    let resolver = NameResolver(fileSeason: file["season"]?.objectValue, members: members)
    var events: [Event.Kind] = []

    for (index, game) in games.enumerated() {
        switch build(game.objectValue ?? [:], at: index, resolver: resolver, season: season, members: members, makeId: makeId) {
        case let .refused(reason): return .refused(reason)
        case let .ready(built): events += built
        }
    }
    return .ready(events)
}

// MARK: - One game

private func build(
    _ game: [String: JSONValue],
    at index: Int,
    resolver: NameResolver,
    season: Season,
    members: [RosterEntry],
    makeId: () -> String
) -> PaperImportResult {
    let where_ = game["opponent"]?.stringValue.map { "the game against \($0)" } ?? "game \(index + 1)"

    guard let serves = game["serves"]?.arrayValue, !serves.isEmpty else {
        return .refused("\(capitalised(where_)) has no serve figures.")
    }
    if let result = game["result"], !result.isNull, MatchResult(rawValue: result.stringValue ?? "") == nil {
        return .refused("\(capitalised(where_)) has an unrecognised result.")
    }

    var entries: [RawHistoricalEntry] = []
    for row in serves.compactMap(\.objectValue) {
        let name = row["name"]?.stringValue ?? ""

        switch resolver.resolve(name) {
        case let .ambiguous(first):
            return .refused(
                "More than one player on the \(season.name) roster is called \"\(first)\", so "
                    + "\"\(name)\" is ambiguous. Give those players full names and try again. "
                    + "Nothing was imported."
            )
        case .unknown:
            return .refused(
                "\"\(name)\" does not match anyone on the \(season.name) roster "
                    + "(\(rosterNames(members))). Nothing was imported."
            )
        case let .found(playerId):
            guard let servesIn = row["in"]?.intValue, let servesOut = row["out"]?.intValue,
                servesIn >= 0, servesOut >= 0
            else {
                return .refused(
                    "\(capitalised(where_)) has a serve count that is not a whole number of zero or more."
                )
            }
            entries.append(RawHistoricalEntry(playerId: playerId, servesIn: servesIn, servesOut: servesOut))
        }
    }

    let context = GameContext(
        date: game["date"]?.stringValue,
        opponent: game["opponent"]?.stringValue ?? "",
        location: game["location"]?.stringValue ?? "",
        court: game["court"]?.stringValue ?? ""
    )
    // A file may carry the two lists separately, as the sheets keep them, or one blob.
    let notes = GameNotes(
        wentWell: game["wentWell"]?.stringValue ?? "",
        needsWork: game["needsWork"]?.stringValue ?? "",
        notes: game["notes"]?.stringValue ?? ""
    )
    let result = MatchResult(rawValue: game["result"]?.stringValue ?? "") ?? .undecided

    return .ready([
        .addHistoricalGame(
            id: makeId(),
            seasonId: season.id,
            context: context,
            entries: entries,
            notes: notes,
            result: .value(result)
        )
    ])
}

// MARK: - Matching a name to a player

/// Matches a name in the file to a player on the roster, by three routes in order of
/// confidence.
///
/// Both sides were typed by a person — the roster on a phone before a match, the file from
/// handwriting afterwards — so demanding they agree character for character is a rule the
/// data cannot keep. "Layna" and "Layna Blankenship" are the same child, and refusing the
/// whole import over that helps nobody.
///
/// Ambiguity is still refused: if two players answer to one first name, guessing would put
/// a serve against the wrong child, which is worse than asking.
struct NameResolver {
    enum Match: Equatable {
        case found(String)
        case ambiguous(String)
        case unknown
    }

    private var byFullName: [String: String] = [:]
    private var byNumber: [String: String?] = [:]
    private var byFirstName: [String: String?] = [:]
    private var fileNameToNumber: [String: String] = [:]

    init(fileSeason: [String: JSONValue]?, members: [RosterEntry]) {
        for member in members {
            byFullName[normalised(member.name)] = member.id

            let number = member.number.trimmingCharacters(in: .whitespaces)
            if !number.isEmpty {
                // A nil value marks a name or number that more than one player answers to.
                byNumber[number] = byNumber.keys.contains(number) ? String?.none : member.id
            }

            let first = firstName(member.name)
            if !first.isEmpty {
                byFirstName[first] = byFirstName.keys.contains(first) ? String?.none : member.id
            }
        }

        // The file declares its own roster with jersey numbers. A number is the least
        // ambiguous thing either side holds, so it is the best bridge between two
        // spellings of a name.
        for player in fileSeason?["roster"]?.arrayValue?.compactMap(\.objectValue) ?? [] {
            let number = (player["number"]?.stringValue ?? "").trimmingCharacters(in: .whitespaces)
            guard !number.isEmpty else { continue }
            fileNameToNumber[normalised(player["name"]?.stringValue ?? "")] = number
        }
    }

    func resolve(_ name: String) -> Match {
        let full = normalised(name)
        if let exact = byFullName[full] { return .found(exact) }

        if let number = fileNameToNumber[full], let match = byNumber[number], let playerId = match {
            return .found(playerId)
        }

        let first = firstName(name)
        if let match = byFirstName[first] {
            guard let playerId = match else { return .ambiguous(first) }
            return .found(playerId)
        }
        return .unknown
    }
}

// MARK: - Wording

/// Names the roster in the failure, so the mismatch can be seen rather than guessed at.
private func rosterNames(_ members: [RosterEntry]) -> String {
    let names = members.map(\.name)
    guard names.count > 12 else { return names.joined(separator: ", ") }
    return "\(names.prefix(12).joined(separator: ", ")), and \(names.count - 12) more"
}

private func normalised(_ name: String) -> String {
    name.trimmingCharacters(in: .whitespaces)
        .lowercased()
        .split(separator: " ", omittingEmptySubsequences: true)
        .joined(separator: " ")
}

private func firstName(_ name: String) -> String {
    normalised(name).split(separator: " ").first.map(String.init) ?? ""
}

private func capitalised(_ text: String) -> String {
    guard let first = text.first else { return text }
    return first.uppercased() + text.dropFirst()
}
