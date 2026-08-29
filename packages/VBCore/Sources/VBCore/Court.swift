// The court, as it is actually arranged on the floor.
//
// This is what the watch draws and what the phone's picker draws, from one definition, so
// the two cannot disagree about who serves next. Derived on read like every other figure:
// a stored court would be one more thing that can fall out of step with the serves.
//
//     4     3     2  <- on deck: rotates into service next
//     5     6     1  <- serving
//
// The arrangement stays still and the players move through it. Rotation is clockwise: the
// server steps to the bottom-middle position, and the top-right player steps down into
// service.
import Foundation

/// A position on the court, numbered as volleyball numbers them.
public enum CourtPosition: Int, CaseIterable, Sendable {
    case service = 1
    case rightFront = 2
    case middleFront = 3
    case leftFront = 4
    case leftBack = 5
    case middleBack = 6

    /// How far along the serving order this position stands from whoever is serving.
    ///
    /// The service position is the server; the player at position 2 serves next, and so on
    /// round the six.
    public var offsetFromServer: Int { rawValue - 1 }

    /// The positions in the order they are drawn: front row left to right, then back row.
    public static let drawingOrder: [CourtPosition] = [
        .leftFront, .middleFront, .rightFront,
        .leftBack, .middleBack, .service,
    ]
}

/// One box on the court.
public struct CourtSlot: Equatable, Sendable {
    public var position: CourtPosition

    /// Who is standing here, or nil when the position is empty — a short bench, or a
    /// player removed from the roster mid-match. An empty position is shown as empty.
    public var playerId: String?

    public var number: String?

    /// Nil when this player has not served: they have no percentage, and reporting 0%
    /// would say they served and missed.
    public var inPercentage: Double?

    /// Nil where points were never recorded at all.
    public var points: Int?

    public var isServing: Bool
    public var isOnDeck: Bool

    public init(
        position: CourtPosition,
        playerId: String? = nil,
        number: String? = nil,
        inPercentage: Double? = nil,
        points: Int? = nil,
        isServing: Bool = false,
        isOnDeck: Bool = false
    ) {
        self.position = position
        self.playerId = playerId
        self.number = number
        self.inPercentage = inPercentage
        self.points = points
        self.isServing = isServing
        self.isOnDeck = isOnDeck
    }
}

/// The six boxes, and what the figures in them cover.
public struct CourtView: Equatable, Sendable {
    /// In drawing order: front row left to right, then back row.
    public var slots: [CourtSlot]

    /// The lineup index standing in the service corner.
    public var servingPosition: Int

    /// Nil when there is no order to advance, in which case the app must say it cannot
    /// name the next server rather than presenting one.
    public var onDeckPlayerId: String?

    /// What the figures cover, in words the coach can read: "Match 2", say.
    public var scopeLabel: String

    public init(
        slots: [CourtSlot],
        servingPosition: Int,
        onDeckPlayerId: String?,
        scopeLabel: String
    ) {
        self.slots = slots
        self.servingPosition = servingPosition
        self.onDeckPlayerId = onDeckPlayerId
        self.scopeLabel = scopeLabel
    }

    /// True when there is no lineup, so nobody can be named as next.
    public var hasOrder: Bool { onDeckPlayerId != nil }
}

/// The lineup index standing at a court position, wrapping round the order.
public func lineupIndex(servingPosition: Int, offset: Int) -> Int {
    let size = lineupSize
    return ((servingPosition + offset) % size + size) % size
}

extension AppState {
    /// The court as it stands in the match in progress, with figures for that match.
    ///
    /// Returns nil when there is no match to draw — the watch then says so rather than
    /// showing an empty court that looks like a court with nobody on it.
    public func courtView(scopeLabel: String? = nil) -> CourtView? {
        guard let match = currentMatch else { return nil }
        return courtView(of: match, scopeLabel: scopeLabel ?? "Match \(match.index + 1)")
    }

    /// The court for a given match.
    public func courtView(of match: Match, scopeLabel: String) -> CourtView {
        let servingPosition = serviceCornerPosition(of: match)
        let statistics = match.statistics
        let lineup = match.lineup

        let slots = CourtPosition.drawingOrder.map { position -> CourtSlot in
            let index = lineupIndex(servingPosition: servingPosition, offset: position.offsetFromServer)
            let playerId = lineup.flatMap { $0.indices.contains(index) ? $0[index] : nil }

            guard let playerId else { return CourtSlot(position: position) }

            let figures = statistics[playerId]
            return CourtSlot(
                position: position,
                playerId: playerId,
                number: rosterEntry(id: playerId)?.number,
                inPercentage: figures?.inPercentage,
                // Nil rather than zero: a player who has not served has earned no points
                // that were recorded, which is not the same as having earned none.
                points: figures?.points,
                isServing: position == .service,
                isOnDeck: position == .rightFront
            )
        }

        return CourtView(
            slots: slots,
            servingPosition: servingPosition,
            onDeckPlayerId: onDeckPlayerId(of: match, servingPosition: servingPosition),
            scopeLabel: scopeLabel
        )
    }

    /// Which lineup position is standing in the service corner.
    ///
    /// The open turn's own position comes first: it is where the ball actually is,
    /// including when a server out of the order took the position that was due.
    private func serviceCornerPosition(of match: Match) -> Int {
        if let position = match.openTurn?.lineupPosition { return position }
        return match.nextRotationPosition ?? 0
    }

    private func onDeckPlayerId(of match: Match, servingPosition: Int) -> String? {
        guard let lineup = match.lineup else { return nil }
        let index = lineupIndex(servingPosition: servingPosition, offset: 1)
        return lineup.indices.contains(index) ? lineup[index] : nil
    }
}
