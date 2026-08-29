# Phase 1 Data Model: Rotation, Substitutions, and Durable Data

**Feature**: `002-rotation-and-subs` | **Date**: 2026-08-29

The shape from release 001 is unchanged: an append-only event log is the only thing stored, derived state is rebuilt from it by a pure reducer, and statistics are computed on read. This release adds three event types and extends two derived entities. **No existing event changes shape** — which is why a release-001 log is already a valid release-002 log.

```
  persisted            computed on every change              computed on read
┌────────────┐        ┌──────────────────────────┐        ┌──────────────────┐
│ Event[]    │ ─────▶ │ AppState                 │ ─────▶ │ Statistics       │
│ append-only│ reduce │ roster, games, matches,  │ derive │ turn/match/game  │
│ + version  │        │ lineups, turns, serves   │        │ + subs + on-court│
└────────────┘        └──────────────────────────┘        └──────────────────┘
      ▲
      └── undo = drop the last event, replay from empty
          (an automatic advance vanishes with it — it was never an event)
```

---

## 1. Event log

### New events

| Event | Payload | Meaning |
|---|---|---|
| `SET_LINEUP` | `playerIds` (6, ordered) | The six on court for the current match, in serving order |
| `SUBSTITUTE` | `outPlayerId`, `inPlayerId` | One player replaces another at that player's lineup position |
| `CLEAR_LINEUP` | — | The current match reverts to manual server selection |

Existing events — `ADD_PLAYER`, `EDIT_PLAYER`, `REMOVE_PLAYER`, `START_GAME`, `DISCARD_GAME`, `SELECT_SERVER`, `RECORD_SERVE`, `END_MATCH` — are unchanged in shape and meaning.

> **There is no rotation event.** The advance is part of the `RECORD_SERVE` transition, not a log entry. This is what makes one undo reverse one operator action (`FR-024`) without special handling. See `research.md` R-001.

### Validation rules

| Rule | Source |
|---|---|
| `SET_LINEUP` requires exactly 6 player ids | `FR-010` |
| `SET_LINEUP` ids must be distinct | `FR-010` |
| `SET_LINEUP` ids must all be on the roster | `FR-009` |
| `SET_LINEUP` is rejected when no match is in progress | `FR-011` |
| `SET_LINEUP` is rejected once the match has recorded a serve | `FR-016` |
| `SUBSTITUTE` requires an in-progress match with a lineup | `FR-026` |
| `SUBSTITUTE` `outPlayerId` must currently occupy a lineup position | `FR-027` |
| `SUBSTITUTE` `inPlayerId` must be on the roster | `FR-031` |
| `SUBSTITUTE` `inPlayerId` must not already be in the lineup | `FR-030` |
| `SUBSTITUTE` is rejected when both ids are the same | Edge case |

As in release 001, a rejected event is never appended, and validation lives in the reducer so a replayed log cannot reach a state the live app would have refused.

---

## 2. Derived state

### `Match` — extended

| Field | Type | Notes |
|---|---|---|
| `index` | `0 \| 1 \| 2` | Unchanged |
| `status` | `'in_progress' \| 'ended'` | Unchanged |
| `turns` | `ServeTurn[]` | Unchanged, but each turn carries two new fields |
| **`lineup`** | `string[6] \| null` | **New.** The lineup *as it stands now*: the starting lineup with this match's substitutions applied in order. `null` means manual selection (`FR-014`). |
| **`substitutions`** | `Substitution[]` | **New.** In the order they were made |

### `ServeTurn` — extended

| Field | Type | Notes |
|---|---|---|
| `playerId`, `ordinal`, `colorIndex`, `serves`, `isOpen` | | Unchanged |
| **`lineupPosition`** | `0–5 \| null` | **New.** The position this turn was served from. `null` when the server was not in the lineup (`FR-023`), or when the match has no lineup. |
| **`lineupSnapshot`** | `string[6] \| null` | **New.** The six occupants when this turn opened. `null` when the match has no lineup. |

**Why both.** They answer different questions and conflating them tangles the design (`research.md` R-003):

- `lineupPosition` drives *who serves next* — positions are stable, occupants are not.
- `lineupSnapshot` answers *who was on court then*, which is what turns-on-court (`FR-054`) needs. Without it, that statistic becomes a fold over substitution history at every read.

### `Substitution` — new

| Field | Type | Notes |
|---|---|---|
| `outPlayerId` | `string` | Who came off |
| `inPlayerId` | `string` | Who came on |
| `position` | `0–5` | The lineup position exchanged |
| `afterTurnOrdinal` | `number` | The turn ordinal in effect when it happened — the "point in the match" (`FR-036`) |

No timestamp, for the same reason as `Serve`: a clock would make replay non-deterministic and order is the only ordering that matters.

---

## 3. Transitions

### `SET_LINEUP`

Sets `match.lineup` to the given ids. Rejected once a serve exists in the match (`FR-016`), so a lineup can never contradict turns already played under a different one.

### `RECORD_SERVE` — extended

Unchanged up to appending the serve and deciding whether the turn closes. Then:

```
if the turn just closed AND match.lineup exists:
    nextPosition = (last non-null lineupPosition among turns + 1) mod 6
    open a new turn for match.lineup[nextPosition] at nextPosition
```

| Rule | Source |
|---|---|
| Wraps from position 5 to 0 | `FR-019` |
| Skips `null` positions when looking back, so one off-lineup turn does not derail the rotation | `FR-023` |
| Does nothing when `match.lineup` is `null` | `FR-025` |
| Reversed by popping the one `RECORD_SERVE` event | `FR-024` |

### `SELECT_SERVER` — extended

Unchanged, except the new turn records `lineupPosition` — the index of the player in `match.lineup`, or `null` if absent — and `lineupSnapshot`.

Because the next position is derived from the last turn's position, an override automatically continues the rotation from the overriding player (`FR-022`). No separate resync step exists.

### `SUBSTITUTE`

1. Find the outgoing player's position in `match.lineup`.
2. Replace that position's occupant with the incoming player.
3. Append a `Substitution` record.
4. If the outgoing player held the **open turn**: close it, keeping its serves, and open a new turn for the incoming player at the same position.

Step 4 is the delicate one. Rewriting the open turn's `playerId` instead would reassign serves the outgoing player actually took, violating `FR-029` while satisfying `FR-034`. Closing and reopening satisfies both and is true to what happened — two players served, so there were two turns. The existing zero-serve-turn rule cleans up when the substitution lands before the outgoing player served.

### `CLEAR_LINEUP`

Sets `match.lineup` to `null`. The match reverts to manual selection; turns already recorded keep their `lineupPosition` and `lineupSnapshot`.

---

## 4. Statistics

Everything from release 001 is unchanged (`FR-052`). Two additions, both derived on read:

| Figure | Definition | Source |
|---|---|---|
| `substitutions` | The match's `substitutions` list, resolved to player names | `FR-053` |
| `turnsOnCourt` | Count of turns in scope whose `lineupSnapshot` contains the player | `FR-054` |

`turnsOnCourt` counts turns during which a player was on court whether or not they served, which is the point — it distinguishes a player who sat out from one who was on court and simply never reached the service position.

---

## 5. Persistence

The envelope gains a migration chain. The key and format are otherwise as before.

```json
{ "schemaVersion": 2, "events": [ … ] }
```

| Stored version | Behaviour | Source |
|---|---|---|
| `> current` | Refused, explained, left untouched | `FR-005` |
| `< current` | Each migration step applied in order, then replayed, then written back stamped current | `FR-003`, `FR-004` |
| `= current` | Loaded directly | |
| Unparseable | Reported; nothing applied | `FR-006` |

**Migration `1 → 2` is the identity function.** Release 002 only adds event types, so a release-001 log is already valid. The step exists so the *chain* is proven to run before a release needs it to do real work (`research.md` R-005).

**Write-back failure** (`FR-008`): the app continues from the migrated log it holds in memory and leaves the stored original untouched. A failed write must never be worse than not attempting one.

### Export file

The same envelope, as a file:

```json
{ "app": "vbtracking", "schemaVersion": 2, "exportedAt": "…", "events": [ … ] }
```

| Rule | Source |
|---|---|
| Valid and importable even with nothing recorded | `FR-039` |
| Import replaces all stored data, after explicit confirmation | `FR-041` |
| Wrong `app` marker, malformed JSON, or missing events → refused, nothing touched | `FR-043`, `FR-046` |
| Newer `schemaVersion` → refused with an explanation | `FR-044` |
| Older `schemaVersion` → migrated on import, as stored data is | `FR-045` |

`exportedAt` is written for the operator's benefit when identifying a file. It is never read back into state, so it cannot affect replay determinism.
