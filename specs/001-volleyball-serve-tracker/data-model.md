# Phase 1 Data Model: Volleyball Serve Tracker

**Feature**: `001-volleyball-serve-tracker` | **Date**: 2026-08-29

The application has **two** data shapes, and the distinction between them is the core of the design:

- **The event log** — the only thing that is stored. Append-only, never edited.
- **The derived state** — rebuilt from the log by a pure reducer on every change. Never stored, never mutated.

Statistics are a third layer, computed from derived state on read. Nothing is ever persisted twice.

```
  persisted            computed on every change         computed on read
┌────────────┐        ┌──────────────────────┐        ┌──────────────┐
│ Event[]    │ ─────▶ │ AppState             │ ─────▶ │ Statistics   │
│ append-only│ reduce │ roster, games,       │ derive │ turn/match/  │
│            │        │ matches, turns,serves│        │ game scope   │
└────────────┘        └──────────────────────┘        └──────────────┘
      ▲
      └── undo = drop the last event, replay from empty
```

---

## 1. Event log (persisted)

A single ordered array. Each entry is a plain object with a `t` discriminator. Events are immutable once appended; the only mutation ever performed on the log is removing the final element (undo).

| Event | Payload | Meaning |
|---|---|---|
| `ADD_PLAYER` | `id`, `name`, `number` | A player joins the roster |
| `EDIT_PLAYER` | `id`, `name`, `number` | A player's name or number is corrected |
| `REMOVE_PLAYER` | `id` | A player leaves the roster |
| `START_GAME` | `id` | A new game begins; match 1 opens automatically |
| `SELECT_SERVER` | `playerId` | This player takes the serving position; a new turn opens |
| `RECORD_SERVE` | `outcome` | One serve is recorded for the open turn |
| `END_MATCH` | — | The operator declares the current match finished |

### Validation rules

| Rule | Source |
|---|---|
| `ADD_PLAYER` is rejected when the roster already holds 20 players | `FR-002` |
| `name` must be non-empty after trimming | `FR-001` |
| `number` is a string, not an integer — jersey numbers may carry a leading zero | `FR-001` |
| `SELECT_SERVER` is rejected when there is no in-progress match | `FR-015` |
| `SELECT_SERVER` is rejected when `playerId` is not in the roster | `FR-015` |
| `RECORD_SERVE` is rejected when no turn is open | `FR-022` |
| `outcome` must be exactly one of `OUT`, `IN_NO_POINT`, `IN_POINT` | `FR-016` |
| `END_MATCH` is rejected when no match is in progress | `FR-010` |
| `START_GAME` is rejected while a game with an unfinished match exists | `FR-013` |

A rejected event is never appended. Validation lives in the reducer so that replay of a stored log cannot produce a state the live app would have refused.

---

## 2. Derived state (never persisted)

### `AppState`

| Field | Type | Notes |
|---|---|---|
| `roster` | `Player[]` | 0–20 entries, insertion-ordered |
| `games` | `Game[]` | Completed and in-progress |
| `currentGameId` | `string \| null` | |

### `Player`

| Field | Type | Notes |
|---|---|---|
| `id` | `string` | Stable across name and number edits — this is why serves survive an edit (`FR-007`) |
| `name` | `string` | Non-empty |
| `number` | `string` | Jersey number |

Serves reference `playerId`, never a name. `EDIT_PLAYER` therefore cannot orphan history.

### `Game`

| Field | Type | Notes |
|---|---|---|
| `id` | `string` | |
| `matches` | `Match[]` | Exactly 3 when complete; grows as matches end (`FR-008`, `FR-013`) |

### `Match`

| Field | Type | Notes |
|---|---|---|
| `index` | `0 \| 1 \| 2` | Position within the game |
| `status` | `'in_progress' \| 'ended'` | Ended matches are immutable (`FR-012`, `FR-043`) |
| `turns` | `ServeTurn[]` | Ordered by occurrence |

**State transitions**

```
        START_GAME                 END_MATCH                END_MATCH ×3
none ──────────────▶ in_progress ─────────────▶ ended ──────────────────▶ game complete
                          │                                                (no 4th match)
                          └── SELECT_SERVER / RECORD_SERVE (only here)
```

A match accepts serve events only while `in_progress`. `END_MATCH` closes any open turn first, discarding it if it holds no serves, then opens match `index + 1` unless `index` is already 2.

### `ServeTurn`

| Field | Type | Notes |
|---|---|---|
| `playerId` | `string` | |
| `ordinal` | `number` | 0-based position within the match |
| `colorIndex` | `number` | `ordinal % PALETTE_LENGTH` (`FR-032`, `FR-033`) |
| `serves` | `Serve[]` | Never empty in persisted-derived state (`FR-027`) |
| `isOpen` | `boolean` | Exactly one turn per match may be open |

**Turn lifecycle**

| Trigger | Effect |
|---|---|
| `SELECT_SERVER` | Close the open turn (discard if it has 0 serves), append a new open turn |
| `RECORD_SERVE` with `IN_POINT` | Append the serve; turn **stays open** (`FR-020`) |
| `RECORD_SERVE` with `OUT` or `IN_NO_POINT` | Append the serve; turn **closes** (`FR-021`) |
| `END_MATCH` | Close the open turn (discard if it has 0 serves) |

> A turn closed by a serve always ends on a non-point serve. A turn closed by `SELECT_SERVER` or `END_MATCH` may end on a point. Consumers must not assume the final serve is a loss.

### `Serve`

| Field | Type | Notes |
|---|---|---|
| `outcome` | `'OUT' \| 'IN_NO_POINT' \| 'IN_POINT'` | The complete record of a serve |

There is no timestamp. Order in the array is the only ordering that matters, and adding a clock would make replay non-deterministic for no gain.

### Active server

Not a stored field. It is `the open turn's playerId, or null`. Deriving it removes the possibility of an active-server pointer disagreeing with the turn list after an undo.

---

## 3. Statistics (computed on read)

All three scopes use the same shape, so one renderer handles all of them.

| Figure | Definition |
|---|---|
| `serves` | Count of all serves |
| `servesIn` | Count where outcome is `IN_POINT` or `IN_NO_POINT` (`FR-018`) |
| `points` | Count where outcome is `IN_POINT` (`FR-019`) |
| `inPercentage` | `servesIn / serves`, or `null` when `serves === 0` (`FR-039`) |
| `turnsTaken` | Count of turns belonging to the player in scope (`FR-028`) |

| Scope | Computation |
|---|---|
| **Turn** | Direct over `turn.serves`. `turnsTaken` is not meaningful and is omitted. |
| **Match** | Grouped by `playerId` across `match.turns` (`FR-036`) |
| **Game** | Grouped by `playerId` across all matches of the game (`FR-037`) |

Game totals equal the sum of the per-match totals because both derive from the same serves — this is structural, not an invariant that needs enforcing.

### Match score

`matchScore = count of IN_POINT serves across the match`.

Labelled **points on serve**, not "score". Per `FR-014` the opponent's score is not tracked, so this figure is not the full rally-scoring total. The target indicator (`FR-011`) fires when it reaches 21. See `research.md` R-009.

### Derived flags

| Flag | Rule | Source |
|---|---|---|
| `isOverServeLimit` | `turn.serves.length > 5` | `FR-030` |
| `hasReachedTarget` | `matchScore >= 21` | `FR-011` |
| `isGameComplete` | 3 matches with status `ended` | `FR-013` |

---

## 4. Undo

Undo removes the final event and replays the log from empty.

| Rule | Behaviour | Source |
|---|---|---|
| Scope | Only events appended since the last `END_MATCH` may be removed | `FR-043` |
| No-op | Undo with nothing removable does nothing and reports nothing to remove | Edge case: *Undo at the start of a match* |
| Empty turns | A `SELECT_SERVER` left with no serves after undo is discarded by the reducer on replay, not by undo itself | `FR-042` |
| Statistics | Recomputed from replayed state; no separate invalidation step exists | `FR-041` |

The undoable depth is `events.length - indexOfLastEndMatch - 1`. Reaching zero disables the control rather than failing on use.

---

## 5. Persistence

A single `localStorage` key holds a versioned envelope:

```json
{ "schemaVersion": 1, "events": [ … ] }
```

| Rule | Behaviour |
|---|---|
| Write | After every accepted event and every undo |
| Read | Once at startup; the log is replayed to rebuild state |
| Unknown `schemaVersion` | The log is not replayed; the operator is told rather than shown silently wrong data |
| Corrupt or unparseable JSON | Same — reported, never partially applied |
| Write failure (quota, private mode) | Surfaced immediately as a persistent warning (`FR-058`); recording continues in memory so a game in progress is not lost to a storage error |
