// The log as lines of text.
//
// One event per line, appended in order, never rewritten. This file knows the format; it
// does not know about files — that is `VBStore`, and keeping the two apart is what lets
// every rule about a partial write be tested without touching a disk.
import Foundation

/// Reading and writing the log's line format.
public enum LogFormat {
    /// One event, encoded as a single line with no newline in it.
    ///
    /// Keys are sorted so that the same event always produces the same line. A log that
    /// encoded differently on different days could not be compared, and comparing it is how
    /// the parity suite works.
    public static func line(for event: RawEvent) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(JSONValue.object(event)),
            let text = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return text
    }

    /// One event, read back from a line. Nil when the line is not a complete event.
    public static func event(from line: String) -> RawEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }
        return (try? JSONDecoder().decode(JSONValue.self, from: data))?.objectValue
    }

    /// Every event in a stored log, and whether the file ended mid-write.
    ///
    /// A crash between the write and the flush leaves a partial last line. That line is
    /// discarded rather than guessed at, and the caller is told — a log that quietly loses
    /// its last serve is worse than one that says it did.
    public static func read(_ contents: String) -> (events: [RawEvent], hadPartialLine: Bool) {
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var events: [RawEvent] = []
        var hadPartialLine = false

        for (index, line) in lines.enumerated() {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }

            guard let event = event(from: line) else {
                // Only the final line may be partial: anything else is a corrupt file, and
                // reading past it would load half a season while looking like a whole one.
                hadPartialLine = index == lines.count - 1
                break
            }
            events.append(event)
        }

        return (events, hadPartialLine)
    }

    /// A whole log, as the text of a file.
    public static func write(_ events: [RawEvent]) -> String {
        events.map(line(for:)).map { $0 + "\n" }.joined()
    }
}
