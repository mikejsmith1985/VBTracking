# Data Model: Native iOS App with a watchOS Companion

**Feature**: `specs/004-native-ios-and-watch/` · **Date**: 2026-08-29

The model is not new. Three releases established it and a real season is recorded in it. This
document says what it is, what the port to Swift may not change, and the three things this
release adds.

---

## The one rule everything else follows

**The event log is the only stored thing.** State is a pure function of the log:

```text
state = replay(events)
```

Nothing derived is ever written down. Undo is dropping the last event and replaying. This is
why a correction can be appended rather than a record rewritten, and why two devices can be
brought back into step by exchanging events rather than by merging state.

---

## Entities

### Player

A **career identity** — a person, who outlives any roster, team or season.

| Field | Notes |
|---|---|
| `id` | Stable for the life of the person, across every season |
| `name` | Career-wide |

**A jersey number is not here.** It belongs to the season membership. This is the one thing
in the model that cannot be retrofitted, and the port must not move it.

### Season

| Field | Notes |
|---|---|
| `id`, `name`, `team` | |
| `format` | Matches per game, target score, players on court — recorded per season so a later release can vary it without a data migration |
| `members` | Season memberships |

### Season Membership

| Field | Notes |
|---|---|
| `playerId` | The career identity |
| `number` | **The jersey number this player wore this season.** Changes year to year |

Removing a member removes them from that roster only. Every serve they recorded stays theirs.

### Game

Two kinds, and the difference is what was recorded, not how it is displayed.

| Field | Tracked | From paper |
|---|---|---|
| `id`, `seasonId` | ✔ | ✔ |
| `date`, `opponent`, `location`, `court` | ✔ | ✔ |
| `wentWell`, `needsWork`, `notes` | ✔ | ✔ |
| `matches` | Three, each with turns | — |
| `entries` | — | Serves in and out, per player, at game level only |
| `result` | Derived from the matches | Recorded directly |
| `rotatesAtServeLimit` | Written into the START_GAME event, never read from the code | — |

### Match

`index`, `status` (in progress or ended), `result` (won, lost, undecided), `lineup` (six
player ids in serving order, or none), `substitutions`, `turns`.

An ended match is immutable to play. It is **not** immutable to correction — fixing a typo is
not rewriting a game.

### Serve Turn

| Field | Notes |
|---|---|
| `playerId`, `ordinal`, `colorIndex` | Ordinal and colour renumber contiguously when a turn is deleted or inserted |
| `lineupPosition` | The rotation position consumed. `null` for a turn added as a correction, so adding one cannot move who serves next |
| `isOffLineup` | The referee let someone out of the order serve |
| `lineupSnapshot` | Who was on court at the time — this is what makes "turns on court" answerable |
| `serves` | In order |
| `isOpen` | At most one open turn per match |

A turn with no serves is a turn that did not happen: it is dropped, never stored, never
counted.

### Serve

One field: `outcome` — `IN_POINT`, `IN_NO_POINT`, or `OUT`. Nothing else was ever recorded,
and nothing else may be invented.

---

## What this release adds

### 1. Every event gets an identifier

**Why**: two devices now append to one log. `transferUserInfo` guarantees delivery, not
uniqueness — a retry can arrive twice. An identifier made once, when the event is created,
lets the phone ignore what it already holds. That is what makes FR-020's "exactly once" a
fact rather than a hope.

| Field | Notes |
|---|---|
| `eventId` | Assigned at creation, on whichever device created it. Never reused, never regenerated. Named apart from `id`, which several event types already use for the thing the event is about |

**Events imported from the web app have no identifier.** They are assigned one at import,
derived deterministically from the log's position and content, so importing the same file
twice yields the same identifiers and cannot double the season (FR-029).

**This is additive.** The web app ignores an unknown field, so a log written by the native
app still loads there — which is what keeps FR-038 true through the phase gap.

### 2. Court View — derived, never stored

What the watch draws. Computed from the match on every read, exactly like every other
statistic.

| Field | Notes |
|---|---|
| `positions` | Six court positions, each holding at most one player |
| `servingPosition` | The lineup index in the service corner — the open turn's own position, or the one the rotation says is due |
| `onDeckPosition` | The position that rotates into service next |
| Per position | Jersey number, serve-in percentage (**null when nothing was served**), points on serve |
| `scope` | Which match or game the figures cover, so the coach cannot mistake one for the other |

**The geometry** — the arrangement stays still and the players move through it:

```text
   4     3     2 ← on deck (biggest box)
   5     6     1 ← serving
```

Court position `p` holds lineup index `(servingPosition + p - 1) mod 6`. Rotation is
clockwise: the server steps to the bottom-middle box, and the top-right player steps down
into service. This is the same geometry the shipped web app already draws, so the two agree
by construction.

### 3. Device Link — how current the wrist is

| Field | Notes |
|---|---|
| `sequence` | Monotonic per snapshot; the watch ignores anything older than what it holds |
| `capturedAt` | When the phone made it |
| `isCurrent` | False once contact has been lost longer than the threshold |
| `pendingCount` | Serves recorded on the watch that have not reached the phone |

Held only in memory. It describes a moment, not a record.

### Migration Record

| Field | Notes |
|---|---|
| `sourceHash` | A hash of the imported log, so the same file is recognised on a second attempt |
| `importedAt`, `eventCount` | For the operator to see what landed |

---

## Invariants the port may not break

These are the ones bought with real bugs. Each has a test in the web app today, and each
gets its counterpart in `VBCore`.

1. **A jersey number lives on the season membership, never on the player.**
2. **A figure never recorded is null and renders as a dash, never zero.** A paper game's
   points are not zero points.
3. **Statistics are derived on read, never stored.**
4. **Migrations are additive: prepend and stamp, never rename or split.** A shifted index
   turns a bug into silent corruption of a recorded season.
5. **The rotation advance happens inside the serve transition, not as an event**, so one
   undo reverses one operator action.
6. **A rule that changes behaviour is written into the event**, not read from the code —
   `rotatesAtServeLimit` is the precedent. Otherwise a new rule silently rewrites old games.
7. **Serve turns over five are recorded in full and flagged.** Nothing caps at five.
8. **An empty turn is never kept.**
9. **A corrective event is appended, never a record rewritten.** Undo keeps working and the
   original entry stays visible as what it was.
10. **A turn added as a correction takes no rotation position**, so correcting a live match
    cannot change who serves next.

---

## Parity: how the port is proved

`VBCore` is not trusted because it reads correctly. It is trusted because it produces the
same numbers.

| Golden input | Assertion |
|---|---|
| `tests/fixtures/v1-log.json` | Migrated and replayed in Swift, every figure equals `v1-expected.json` |
| `tests/fixtures/v2-log.json` | Same, against `v2-expected.json` |
| An export of the operator's real season | Every per-player, per-match, per-game and per-season figure equals what the web app derives — **including which figures are dashes** |

The fixtures are logs captured from shipped builds. They are never edited: they are the
format as shipped, not as remembered. A one-serve difference fails the build.
