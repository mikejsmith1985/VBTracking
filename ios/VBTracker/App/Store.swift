// The one thing that holds the log, and the only thing that writes it.
//
// Every screen reads `state` and dispatches events. Nothing else knows the log exists —
// which is what keeps undo honest: it drops the last event and replays, and there is no
// second copy of anything to fall out of step.
import Foundation
import Observation
import VBCore
import VBPresentation
import VBStore

/// The app's state, and the only route to changing it.
@MainActor
@Observable
public final class Store {
    /// The replayed state. Read by every screen; written by nothing but `dispatch`.
    public private(set) var state = AppState()

    /// The last refusal, in the operator's words. Cleared by the next accepted event.
    public private(set) var notice: Notice?

    /// What the app could not do, and whether it was the operator's doing.
    public struct Notice: Equatable, Sendable {
        public var text: String
        public var isFailure: Bool
    }

    private var log: LogFile
    private var events: [RawEvent] = []

    /// The identifiers of the newest events on the record, for the wrist to check its own
    /// against. The log itself stays private; this is the only part of it anybody outside
    /// needs to see.
    var acknowledgedEventIds: [String] { acknowledgedIds(in: events) }
    private let ledger: ImportLedger
    private let now: () -> Date

    /// Called after every accepted event, so the wrist can be told without the store
    /// knowing what a wrist is.
    /// Told whenever the record moves. More than one, because two links listen: the wrist,
    /// and a second phone sharing the match. A single slot meant whichever was built last
    /// silently replaced the other.
    private var observers: [(AppState) -> Void] = []

    /// Registers a listener for the life of the app. There is no way to remove one: both
    /// links live as long as the app does, and an unregister nobody calls is a method that
    /// only ever goes wrong.
    public func observe(_ listener: @escaping (AppState) -> Void) {
        observers.append(listener)
    }

    private func notify() {
        for listener in observers { listener(state) }
    }

    public init(directory: URL, now: @escaping () -> Date = Date.init) {
        self.log = LogFile(url: directory.appendingPathComponent("log.jsonl"))
        self.ledger = ImportLedger(url: directory.appendingPathComponent("imports.json"))
        self.now = now
        load()
    }

    /// Reads the log and replays it.
    ///
    /// A log that cannot be read leaves the app empty and says so, rather than refusing to
    /// open: an app that will not start is an operator who cannot reach their season.
    private func load() {
        do {
            events = try log.read()
            state = replay(raw: events)
            if log.hadPartialLine {
                notice = Notice(
                    text: "The app closed mid-serve last time. Everything before that is here.",
                    isFailure: false
                )
            }
        } catch {
            events = []
            state = AppState()
            notice = Notice(text: (error as? LogFileError)?.message ?? "The saved log could not be read.", isFailure: true)
        }
    }

    // MARK: - Recording

    /// Records one event, or says why it was refused.
    ///
    /// Returns whether it was accepted, because several callers need to know — a picker
    /// that closes on a substitution must not close on a refused one.
    @discardableResult
    public func dispatch(_ kind: Event.Kind) -> Bool {
        dispatch(Event(id: UUID().uuidString, kind: kind))
    }

    @discardableResult
    public func dispatch(_ event: Event) -> Bool {
        if let reason = rejectionReason(state, event) {
            notice = Notice(text: reason, isFailure: true)
            return false
        }
        return append(raw(event))
    }

    /// Takes in events recorded on the wrist.
    ///
    /// They are applied by the same rules as anything else, and an identifier already held
    /// is ignored — delivery may retry; the record may not double.
    @discardableResult
    public func accept(fromWatch incoming: [RawEvent]) -> [String] {
        let merged = merge(incoming: incoming, into: events)
        guard !merged.accepted.isEmpty else { return [] }

        let accepted = merged.log.suffix(merged.accepted.count)
        do {
            try log.append(Array(accepted))
        } catch {
            notice = Notice(text: (error as? LogFileError)?.message ?? "Those serves could not be saved.", isFailure: true)
            return []
        }

        events = merged.log
        state = replay(raw: events)
        notify()
        return merged.accepted
    }

    /// Drops the last event and replays. One undo, one operator action.
    public func undo() {
        guard !events.isEmpty else { return }
        do {
            try log.removeLast()
            events.removeLast()
            state = replay(raw: events)
            notice = nil
            notify()
        } catch {
            notice = Notice(text: (error as? LogFileError)?.message ?? "That could not be undone.", isFailure: true)
        }
    }

    /// True when there is anything to undo, and the last match has not closed over it.
    public var canUndo: Bool {
        !events.isEmpty
    }

    // MARK: - The whole record

    /// Everything, as a file the operator keeps.
    public func exportedBackup() -> String {
        buildBackup(events, exportedAt: ISO8601DateFormatter().string(from: now()))
    }

    public func backupFilename() -> String {
        let day = ISO8601DateFormatter().string(from: now()).prefix(10)
        return VBCore.backupFilename(on: String(day))
    }

    /// Reads a backup and, if it is good and not already in, replaces everything.
    ///
    /// All or nothing. A refused file changes nothing at all, which is the whole promise:
    /// an operator who taps the wrong file must not lose the season they have.
    @discardableResult
    public func restore(from text: String) -> Bool {
        let decision = decideImport(readBackup(text), alreadyImported: ledger.knownHashes())
        guard let imported = decision.log else {
            notice = Notice(text: decision.reason ?? "That backup could not be read.", isFailure: true)
            return false
        }

        do {
            try log.replace(with: imported.events)
            try ledger.record(
                ImportEntry(
                    sourceHash: imported.sourceHash,
                    importedAt: ISO8601DateFormatter().string(from: now()),
                    eventCount: imported.events.count
                )
            )
        } catch {
            notice = Notice(text: (error as? LogFileError)?.message ?? "That backup could not be saved.", isFailure: true)
            return false
        }

        events = imported.events
        state = replay(raw: events)
        notice = Notice(text: "Restored \(imported.events.count) recorded actions.", isFailure: false)
        notify()
        return true
    }

    /// The log as it stands, for a second phone to compare against its own.
    public var heldEvents: [RawEvent] { events }

    /// Takes events sent by another phone at the same match.
    ///
    /// The same merge a season handed over by AirDrop goes through, so an event already held
    /// is skipped by identifier and two phones that both recorded the same game are refused
    /// whole. Silent on success: this arrives while somebody is watching a match, and a
    /// notice per serve would cover the court.
    @discardableResult
    public func receive(peerEvents incoming: [RawEvent]) -> Bool {
        let merged = merge(mine: events, theirs: incoming)
        guard merged.refusal == nil, merged.eventsAdded > 0 else { return false }

        do {
            try log.replace(with: merged.events)
        } catch {
            return false
        }

        events = merged.events
        state = replay(raw: events)
        notify()
        return true
    }

    /// A filename for handing this season to somebody else's phone.
    public func handoverFilename() -> String {
        let day = ISO8601DateFormatter().string(from: now()).prefix(10)
        return VBCore.seasonFilename(on: String(day))
    }

    /// Takes in a season from a file the phone handed us.
    ///
    /// A file arriving from AirDrop sits outside the app's own container, so it has to be
    /// asked for before it can be read. Reading it here rather than at the call site keeps
    /// every failure reported in the one place the operator reads notices.
    @discardableResult
    public func receive(fileAt url: URL) -> Bool {
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }

        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            notice = Notice(text: "That file could not be opened.", isFailure: true)
            return false
        }
        return receive(from: text)
    }

    /// Takes in a season somebody else recorded, keeping everything already here.
    ///
    /// Different from `restore` on purpose. Restoring is for a lost phone and replaces
    /// everything; this is for a coach handing the match over, where wiping the roster on
    /// the receiving phone would be a disaster dressed up as a feature.
    ///
    /// All or nothing, like every other way into the log. A merge the rulebook would refuse
    /// changes nothing and says why.
    @discardableResult
    public func receive(from text: String) -> Bool {
        let read = readBackup(text)
        guard let incoming = read.log else {
            notice = Notice(text: read.reason ?? "That file could not be read.", isFailure: true)
            return false
        }

        let merged = merge(mine: events, theirs: incoming.events)
        if let refusal = merged.refusal {
            notice = Notice(text: refusal, isFailure: true)
            return false
        }
        guard merged.eventsAdded > 0 else {
            notice = Notice(text: "That season is already here. Nothing was changed.", isFailure: false)
            return true
        }

        do {
            try log.replace(with: merged.events)
            try ledger.record(
                ImportEntry(
                    sourceHash: incoming.sourceHash,
                    importedAt: ISO8601DateFormatter().string(from: now()),
                    eventCount: merged.eventsAdded
                )
            )
        } catch {
            notice = Notice(
                text: (error as? LogFileError)?.message ?? "That season could not be saved.",
                isFailure: true
            )
            return false
        }

        events = merged.events
        state = replay(raw: events)
        notice = Notice(text: arrivalWording(merged), isFailure: false)
        notify()
        return true
    }

    /// What to tell the operator arrived, counted rather than guessed at.
    private func arrivalWording(_ merged: MergeResult) -> String {
        var parts: [String] = []
        if merged.seasonsAdded > 0 { parts.append(count(merged.seasonsAdded, "season")) }
        if merged.playersAdded > 0 { parts.append(count(merged.playersAdded, "player")) }
        parts.append(count(merged.eventsAdded, "recorded action"))
        return "Added " + parts.joined(separator: ", ") + "."
    }

    private func count(_ number: Int, _ noun: String) -> String {
        "\(number) \(noun)\(number == 1 ? "" : "s")"
    }

    /// Throws away every season, every game and every player, leaving a new install.
    ///
    /// Not an event: an event would be appended to the log it is meant to empty, and the
    /// figures would come back on the next replay. The log itself is replaced with nothing.
    ///
    /// The import ledger is cleared with it, so a backup restored before can be restored
    /// again -- otherwise erasing everything would leave the app refusing the only file the
    /// operator has to put it back.
    @discardableResult
    public func eraseEverything() -> Bool {
        do {
            try log.replace(with: [])
            try ledger.forget()
        } catch {
            notice = Notice(
                text: (error as? LogFileError)?.message ?? "That could not be erased.",
                isFailure: true
            )
            return false
        }

        events = []
        state = replay(raw: events)
        notice = Notice(text: "Everything was erased.", isFailure: false)
        notify()
        return true
    }

    /// Says something happened, when it was not an event that said it.
    ///
    /// Used by the screens that add several events at once — a batch of games from paper —
    /// where the outcome is worth a sentence but no single event carries it.
    public func report(success text: String) {
        notice = Notice(text: text, isFailure: false)
    }

    public func report(failure text: String) {
        notice = Notice(text: text, isFailure: true)
    }

    // MARK: - Internals

    private func append(_ event: RawEvent) -> Bool {
        do {
            try log.append(event)
        } catch {
            notice = Notice(text: (error as? LogFileError)?.message ?? "That could not be saved.", isFailure: true)
            return false
        }

        events.append(event)
        state = replay(raw: events)
        notice = nil
        notify()
        return true
    }

    /// Turns a typed event back into the shape the log stores.
    private func raw(_ event: Event) -> RawEvent {
        var stored = EventEncoder.encode(event.kind)
        stored["eventId"] = .string(event.id)
        return stored
    }
}
