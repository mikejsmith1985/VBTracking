# Contract: Domain API

**Feature**: `001-volleyball-serve-tracker` | **Date**: 2026-08-29

The domain layer is the entire rulebook of the application. It is **pure**: no DOM, no `localStorage`, no `Date.now()`, no randomness. Everything in `src/domain/` is a function of its arguments alone, which is what makes the Article V unit layer possible and what makes replay deterministic.

The UI layer may read from the domain. It must never reimplement a rule the domain owns.

---

## `src/domain/events.js`

Constructors and constants for the event log. No logic beyond shape validation.

```js
export const OUTCOME = { OUT: 'OUT', IN_NO_POINT: 'IN_NO_POINT', IN_POINT: 'IN_POINT' }
export const EVENT = { ADD_PLAYER, EDIT_PLAYER, REMOVE_PLAYER, START_GAME, SELECT_SERVER, RECORD_SERVE, END_MATCH }

export function addPlayer(id, name, number)   // → Event
export function editPlayer(id, name, number)  // → Event
export function removePlayer(id)              // → Event
export function startGame(id)                 // → Event
export function selectServer(playerId)        // → Event
export function recordServe(outcome)          // → Event
export function endMatch()                    // → Event
```

| Guarantee | |
|---|---|
| Returned events are plain, JSON-serializable objects | Required for the persisted log |
| Constructors never read ambient state | An event's meaning comes from its position in the log, not from when it was built |

---

## `src/domain/reducer.js`

The single source of truth for every rule in the spec.

```js
export function emptyState()                  // → AppState
export function applyEvent(state, event)      // → AppState   (pure, returns new state)
export function replay(events)                // → AppState   (events.reduce(applyEvent, emptyState()))
export function isEventValid(state, event)    // → boolean
export function rejectionReason(state, event) // → string | null
```

| Guarantee | Source |
|---|---|
| `applyEvent` never mutates `state` | Replay correctness |
| An invalid event returns `state` unchanged rather than throwing | A corrupt stored log must not crash startup |
| A turn with zero serves is never present in returned state | `FR-027`, `FR-042` |
| Exactly one turn per match may have `isOpen === true` | `FR-022` |
| `replay(events)` is deterministic — same input, same output, always | Undo correctness |
| Ended matches are never modified by any subsequent event | `FR-012`, `FR-043` |

**Turn boundary rules** — the reducer is the only place these exist:

| Input | Effect on the open turn |
|---|---|
| `SELECT_SERVER` | Close it (discard if empty), open a new one for the named player |
| `RECORD_SERVE(IN_POINT)` | Append; stays open |
| `RECORD_SERVE(OUT \| IN_NO_POINT)` | Append; closes |
| `END_MATCH` | Close it (discard if empty); open the next match unless this was match 3 |

---

## `src/domain/stats.js`

```js
export function turnStats(turn)                 // → Stats
export function matchStats(match)               // → Map<playerId, Stats>
export function gameStats(game)                 // → Map<playerId, Stats>
export function matchScore(match)               // → number   (points on serve)
export function isOverServeLimit(turn)          // → boolean
export function activeServerId(state)           // → string | null
export function undoableCount(events)           // → number
```

`Stats` shape:

```js
{ serves: number, servesIn: number, points: number, inPercentage: number | null, turnsTaken: number }
```

| Guarantee | Source |
|---|---|
| `inPercentage` is `null`, never `NaN` or `0`, when `serves === 0` | `FR-039` |
| `gameStats` totals equal the sum of that game's `matchStats` totals | `FR-037` |
| Nothing here caps, clamps, or truncates a count at 5 | `FR-029` |
| `activeServerId` is derived from the open turn, never stored | Undo consistency |
| `undoableCount` counts only events after the last `END_MATCH` | `FR-043` |

---

## `src/domain/palette.js`

```js
export const PALETTE          // → readonly string[], length 6
export function colorForTurn(ordinal)  // → string
```

| Guarantee | Source |
|---|---|
| `colorForTurn(n) !== colorForTurn(n + 1)` for every `n >= 0` | `FR-033` |
| Depends only on `ordinal` — a turn's colour never changes retroactively | Replay determinism |
| Every palette colour meets WCAG AA contrast against the app background | `FR-052` |

---

## `src/state/store.js`

The only stateful module. Wraps the event log, persistence, and subscription.

```js
export function createStore(persistence)  // → Store

// Store:
//   getState()             → AppState
//   getEvents()            → readonly Event[]
//   dispatch(event)        → { accepted: boolean, reason: string | null }
//   undo()                 → { undone: boolean }
//   canUndo()              → boolean
//   subscribe(listener)    → unsubscribe fn
//   storageStatus()        → 'ok' | 'unavailable' | 'corrupt' | 'unsupported-version'
```

| Guarantee | Source |
|---|---|
| A rejected event is not appended and not persisted | Data model §1 |
| Every accepted event and every undo triggers a persist attempt | `FR-057` |
| A persist failure does **not** discard the in-memory event | `FR-058` |
| `undo()` on an empty undoable range is a no-op returning `{ undone: false }` | Edge case: *Undo at the start of a match* |

---

## `src/state/persistence.js`

The only module that touches `localStorage`. Swappable in one file (research R-005).

```js
export function createLocalStoragePersistence(storage = window.localStorage)
//   load()          → { events: Event[], status: StorageStatus }
//   save(events)    → { ok: boolean }
//   requestPersistent() → Promise<boolean>
```

| Guarantee | Source |
|---|---|
| A corrupt or unknown-version payload returns an empty log plus a non-`ok` status — never a partial load | Data model §5 |
| `save` reports failure rather than throwing | `FR-058` |
| No other module imports `localStorage` directly | Containment |

---

## Layer rule

```
ui/  ──────▶  state/  ──────▶  domain/
             (stateful)       (pure)
```

Imports point one direction only. `domain/` imports nothing from `state/` or `ui/`. A rule that appears in `ui/` is a defect, because it cannot be unit-tested and will drift from the reducer.
