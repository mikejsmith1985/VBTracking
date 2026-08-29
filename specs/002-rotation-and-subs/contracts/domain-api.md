# Contract: Domain API additions

**Feature**: `002-rotation-and-subs` | **Date**: 2026-08-29

Extends `specs/001-volleyball-serve-tracker/contracts/domain-api.md`, which remains in force. Everything in `src/domain/` stays **pure**: no DOM, no storage, no clock, no randomness. The layer rule is unchanged — `ui → state → domain`, one direction.

Every rule in this feature lives in `src/domain/`. Nothing in `src/ui/` decides who serves next.

---

## `src/domain/events.js` — additions

```js
export const LINEUP_SIZE = 6

export function setLineup(playerIds)              // → Event  (exactly 6, ordered)
export function substitute(outPlayerId, inPlayerId) // → Event
export function clearLineup()                     // → Event
```

`EVENT` gains `SET_LINEUP`, `SUBSTITUTE`, `CLEAR_LINEUP`. Existing constructors and constants are untouched.

---

## `src/domain/reducer.js` — extended

The exported surface does not change. Three transitions are added and two are extended.

| Guarantee | Source |
|---|---|
| A closing `RECORD_SERVE` opens the next rotation turn **within the same transition** — no second event | `FR-018`, `FR-024` |
| The rotation wraps from position 5 to position 0 | `FR-019` |
| A turn served from outside the lineup records `lineupPosition: null` and does not derail the rotation | `FR-023` |
| Nothing advances when `match.lineup` is `null` | `FR-025` |
| `SET_LINEUP` is refused once the match holds a serve | `FR-016` |
| `SUBSTITUTE` replaces the occupant of the outgoing player's position, leaving the position itself intact | `FR-027` |
| Substituting the active server closes their turn with its serves intact and opens a new one for the incoming player | `FR-029`, `FR-034` |
| No transition ever mutates the state it was given | Replay correctness |

**New readers:**

```js
export function currentLineup(state)          // → string[6] | null
export function nextRotationPosition(match)   // → 0-5 | null
export function nextRotationPlayerId(match)   // → string | null
export function lineupPositionOf(match, playerId) // → 0-5 | null
```

---

## `src/domain/stats.js` — additions

```js
export function turnsOnCourt(turns, playerId)  // → number
export function substitutionsFor(match)        // → Substitution[]
```

| Guarantee | Source |
|---|---|
| `turnsOnCourt` counts turns whose `lineupSnapshot` contains the player, served or not | `FR-054` |
| Every release-001 figure is unchanged | `FR-052` |
| Serves recorded by a substituted-out player stay attributed to them | `FR-029` |

---

## `src/domain/migrations.js` — new

The migration chain. Pure: it transforms an event array and knows nothing about storage.

```js
export const SCHEMA_VERSION = 2

// Ordered. MIGRATIONS[n] upgrades a log at version n to version n+1.
export const MIGRATIONS = { 1: (events) => events }

export function migrate(events, fromVersion)
//   → { events, ok: true } | { events: [], ok: false, reason }
```

| Guarantee | Source |
|---|---|
| Applies every step in order from `fromVersion` to `SCHEMA_VERSION` | `FR-003` |
| A version above `SCHEMA_VERSION` fails with a reason and returns no events | `FR-005` |
| A version with no migration path fails rather than guessing | `FR-006` |
| `migrate(events, SCHEMA_VERSION)` returns the events untouched | |
| Never mutates the array it is given | |

---

## `src/state/persistence.js` — extended

Still the only module that touches `localStorage`.

```js
export function createLocalStoragePersistence(storage)
//   load()  → { events, status, migratedFrom? }
//   save(events) → { ok }
```

`load()` now migrates instead of refusing an older version. `status` gains no new values; an unsupported version still reports `'unsupported-version'`, but only when the version is **newer** than current.

| Guarantee | Source |
|---|---|
| An older stored version is migrated, replayed, and written back stamped current | `FR-003`, `FR-004` |
| A failed write-back leaves the stored original untouched and does not fail the load | `FR-008` |
| A newer version is refused and left unmodified | `FR-005` |

---

## `src/state/backup.js` — new

File in, file out. The only module that builds or parses an export.

```js
export const EXPORT_MARKER = 'vbtracking'

export function buildExport(events, now)   // → string (JSON). `now` injected, never read ambiently.
export function parseImport(text)          // → { events, ok: true } | { ok: false, reason }
```

| Guarantee | Source |
|---|---|
| Produces a valid, importable payload for an empty event log | `FR-039` |
| Rejects a payload missing the app marker, with a reason | `FR-043` |
| Rejects malformed JSON or a missing event array, with a reason | `FR-043` |
| Rejects a newer schema version, with a reason | `FR-044` |
| Migrates an older schema version through the same chain as stored data | `FR-045` |
| Never throws — every failure is a returned reason | `FR-046` |
| `now` is a parameter, so the module stays testable and deterministic | |

Delivering the file to the operator (share sheet, download) and reading one back (file input) are UI concerns and live in `src/ui/`. This module only builds and parses.

---

## `src/state/store.js` — extended

```js
//   armSubstitution(playerId)  → void
//   pendingSubstitution()      → string | null
//   clearSubstitution()        → void
```

The armed half of a two-step substitution is **transient interaction state**, not history: it is never appended to the log and never persisted. Only the completed `SUBSTITUTE` is an event.

| Guarantee | Source |
|---|---|
| A pending substitution is discarded, never applied, when the match ends | `FR-033` |
| A pending substitution is cleared by any non-player interaction | `FR-032` |
| A pending substitution never reaches storage | |
