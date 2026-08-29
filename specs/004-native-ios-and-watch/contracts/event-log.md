# Contract: The event log on disk, and the backup file

**Feature**: `specs/004-native-ios-and-watch/`

Two formats, one shape. The file on disk is how the phone stores the log; the backup file is
how a log moves between the web app and the native app. They carry the same events.

---

## The log file

**Location**: the App Group container `group.com.mikejsmith.vbtracker`, file `log.jsonl`.

**Format**: JSON Lines. One event per line, appended in order, never rewritten.

```jsonl
{"eventId":"9f2c…","t":"CREATE_SEASON","id":"s1","name":"2026 Fall","team":"Eastern"}
{"eventId":"a10d…","t":"ADD_PLAYER","id":"p1","name":"Ella","number":"7","seasonId":"s1"}
{"eventId":"b73e…","t":"RECORD_SERVE","outcome":"IN_POINT"}
```

**Rules**

| Rule | Why |
|---|---|
| Append only; a line is never edited or removed | The log is the record. Corrections are new events |
| A write is one `write` of one complete line, flushed | A crash mid-append loses at most the line being written, and a partial line is discarded on read |
| Reading is the whole file, in order | Replay is a pure function of the sequence |
| An unreadable line stops the read at that point, and says so | Loading half a season silently is worse than refusing |
| `schemaVersion` lives in a sibling `meta.json`, not per line | It describes the log, not an event |

**Undo** truncates the last line. This is the one operation that removes a line, and it is
the same operation the web app performs on its array.

---

## Events

Every event has `t` (its type) and, from this release, `eventId`.

| Field | Type | Notes |
|---|---|---|
| `eventId` | string | Assigned once, at creation, on the device that created it. Never regenerated |
| `t` | string | One of the types below |

**Why `eventId` and not `id`**: several event types already use `id` for the thing they are
about — the player added, the season created, the game started. Reusing that key would
silently rewrite a season the web app recorded. The identifier of the event is a different
thing from the identifier of what the event is about, and is named accordingly.

The types are unchanged from release 003 and are not restated here field by field — they are
defined by `src/domain/events.js` in the shipped web app, which is the format of record:

```text
ADD_PLAYER · EDIT_PLAYER · REMOVE_PLAYER · REMOVE_FROM_SEASON
CREATE_SEASON · RENAME_SEASON · ACTIVATE_SEASON
START_GAME · DISCARD_GAME · SET_GAME_CONTEXT · SET_GAME_NOTES · SET_MATCH_RESULT
ADD_HISTORICAL_GAME · EDIT_HISTORICAL_GAME
SET_LINEUP · CLEAR_LINEUP · SUBSTITUTE
SELECT_SERVER · RECORD_SERVE · END_MATCH · END_GAME
SET_TURN_SERVES · REASSIGN_TURN · DELETE_TURN · INSERT_TURN
```

**Adding `eventId` is additive.** The web app ignores fields it does not know, so a log written by
the native app still loads in the browser. That is what keeps both apps able to read the same
season while parity is being built (FR-038).

---

## The backup file

The format the shipped web app already writes. The native app both reads and writes it.

```json
{
  "app": "vbtracking",
  "schemaVersion": 3,
  "exportedAt": "2026-08-29T18:04:11.000Z",
  "events": [ … ]
}
```

| Field | Rule |
|---|---|
| `app` | Must equal `vbtracking`. Anything else is refused as "not a Serve Tracker backup" |
| `schemaVersion` | Migrated forward through the ordered chain. A version newer than this build understands is refused, not guessed at |
| `events` | The whole log, in order |

**Reading**

1. Refuse anything that is not this shape, with a plain reason. Nothing on the device changes.
2. Run the migration chain to the current version.
3. Assign an `eventId` to every event that lacks one, derived deterministically from its
   index and content so the same file always produces the same identifiers.
4. Compute a hash of the resulting log. If a previous import recorded that hash, refuse:
   this file is already in (FR-029).
5. Replace or merge — **the operator is told which before it happens** — and either complete
   in full or change nothing (FR-028).

**Writing**

The native export is byte-compatible with the web app's parser: same marker, same version
field, same event array. A round trip through either app must produce identical figures.

---

## Failure messages

Every failure is a returned reason, never a thrown error, and never a silent partial load.
The wording carries over from the web app because it has already been read by the operator in
a gym:

| Situation | Message |
|---|---|
| Not JSON | "That file is not readable. It may be damaged or incomplete." |
| Wrong marker | "That file is not a Serve Tracker backup." |
| No events | "That backup has no recorded data in it." |
| Newer schema | "That backup was written by a newer version of this app." |
| Already imported | "That backup is already in. Nothing was changed." |
