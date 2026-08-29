# Phase 1 Data Model: Seasons, Career Players, and Game Context

**Feature**: `003-seasons-and-career` | **Date**: 2026-08-29

The shape from the earlier releases is unchanged: an append-only event log is the only thing stored, derived state is rebuilt by a pure reducer, statistics are computed on read. This release adds events, extends four existing ones with a single field each, and splits the roster into career players plus per-season memberships.

---

## 1. Event log

### Extended events — one field each, nothing renamed or removed

| Event | New field | Meaning |
|---|---|---|
| `ADD_PLAYER` | `seasonId` | Create the person if new, and add them to this season with this number |
| `EDIT_PLAYER` | `seasonId` | Correct the name (career-wide) and the number (this season only) |
| `REMOVE_PLAYER` | `seasonId` | Remove from this season's roster; the person survives |
| `END_MATCH` | `result` | `'won' \| 'lost' \| 'undecided'` |
| `START_GAME` | `seasonId` | Which season the game belongs to |

Additive by design (`research.md` R-001): no event changes identity or position, so the migration cannot shift an index and a mistake surfaces as a wrong figure rather than a wrong shape.

### New events

| Event | Payload |
|---|---|
| `CREATE_SEASON` | `id`, `name`, `team`, `format` |
| `RENAME_SEASON` | `id`, `name`, `team` |
| `ACTIVATE_SEASON` | `id` |
| `SET_GAME_CONTEXT` | `gameId`, `date`, `opponent`, `location`, `court` |
| `SET_GAME_NOTES` | `gameId`, `notes` |
| `ADD_HISTORICAL_GAME` | `id`, `seasonId`, context fields, `entries: [{ playerId, in, out }]` |
| `EDIT_HISTORICAL_GAME` | `id`, context fields, `entries` |

### Validation rules

| Rule | Source |
|---|---|
| `CREATE_SEASON` needs a non-empty name and team | `FR-012` |
| `ADD_PLAYER` is rejected when the person is already in that season | `FR-020` |
| `ADD_PLAYER` is accepted, with a warning, when the number duplicates another in the season | `FR-021` |
| `ACTIVATE_SEASON` is rejected while a match is in progress | `FR-015` |
| `REMOVE_PLAYER` never deletes the person | `FR-023` |
| A player referenced by any game cannot be deleted | `FR-010` |
| `ADD_HISTORICAL_GAME` rejects a negative `in` or `out` | `FR-039` |
| `ADD_HISTORICAL_GAME` rejects a `playerId` not in that season's roster | `FR-041` |
| `SET_GAME_CONTEXT` and `SET_GAME_NOTES` apply to any game, ended or not | `FR-025`, `FR-033` |

---

## 2. Derived state

```
AppState
├── players[]        { id, name }                    ← career identities
├── seasons[]        { id, name, team, format, members[] }
│                    members: { playerId, number }   ← the number lives HERE
├── activeSeasonId
└── games[]          { id, seasonId, kind, context, notes, ... }
                     kind 'tracked'    → matches[]   (as before)
                     kind 'historical' → entries[]   { playerId, in, out }
```

### `Player`

| Field | Notes |
|---|---|
| `id` | Stable forever. Never carries a number. |
| `name` | Career-wide; editing it changes every season and statistic |

### `Season`

| Field | Notes |
|---|---|
| `id`, `name`, `team` | |
| `format` | `{ matchesPerGame, targetScore, playersOnCourt }` — recorded, not editable (`FR-016`, `FR-017`) |
| `members` | `[{ playerId, number }]`, in roster order |

### `Game`

| Field | Tracked | Historical |
|---|---|---|
| `id`, `seasonId`, `kind` | ✅ | ✅ |
| `date`, `opponent`, `location`, `court`, `notes` | ✅ | ✅ |
| `matches[]` (with turns, serves, lineups, substitutions) | ✅ | — |
| `entries[]` `{ playerId, in, out }` | — | ✅ |

A historical game has no matches and no turns because that detail was never written down. Synthesising them was rejected (`research.md` R-003) — it would report turn counts that never happened.

### `Match` — extended

Gains `result: 'won' | 'lost' | 'undecided'`. Everything else is unchanged.

---

## 3. Transitions

| Event | Effect |
|---|---|
| `CREATE_SEASON` | Appends the season; makes it active if none is |
| `ACTIVATE_SEASON` | Changes `activeSeasonId`. Refused mid-match. |
| `ADD_PLAYER` | Creates the person when the id is new; appends `{ playerId, number }` to the season's members |
| `EDIT_PLAYER` | Updates the person's name; updates that season's number only |
| `REMOVE_PLAYER` | Removes the membership. The person, and every serve they recorded, remain. |
| `END_MATCH` | As before, plus records the result |
| `SET_GAME_CONTEXT` / `SET_GAME_NOTES` | Replaces those fields on the named game, whatever its state |
| `ADD_HISTORICAL_GAME` | Appends a game of kind `historical` to the season |
| `EDIT_HISTORICAL_GAME` | Replaces its context and entries |

Every game-scoped event names its `gameId`, so an ended game can still be annotated (`FR-025`) — the rule that ended *matches* are immutable is about play, not about context.

---

## 4. Statistics

One aggregation over a list of games, called with different lists (`research.md` R-004):

```js
aggregate(games) → {
  byPlayer: Map<playerId, { serves, servesIn, inPercentage,
                            points, turnsTaken, turnsOnCourt }>,
  coverage: { totalGames, trackedGames }
}
```

| Scope | Games passed |
|---|---|
| Game | one |
| Season | every game of that season |
| Career | every game containing that player, across seasons |

### Which figures span which games

| Figure | Tracked | Historical |
|---|---|---|
| `serves`, `servesIn`, `inPercentage` | ✅ | ✅ |
| `points`, `turnsTaken`, `turnsOnCourt` | ✅ | **not recorded** |

When `coverage.trackedGames < coverage.totalGames`, the tracked-only columns are labelled as such. A figure never recorded is shown as not recorded, never zero (`FR-045`) — zero would report worse figures than the players earned.

### Results

| Figure | Rule |
|---|---|
| Game result | `won` when more matches won than lost; `lost` when more lost; otherwise `undecided` |
| Season record | Counts of won and lost games; undecided counted separately, never as a loss |
| Per-opponent | The same, grouped by opponent |

### Vocabulary (`FR-047`)

| App term | Means |
|---|---|
| **In** | Serves that landed in — what the operator's sheets call the *score* |
| **Points** | Rallies won while serving — a different figure, tracked games only |

Both are wanted. They are labelled so they cannot be read as each other.

---

## 5. Migration `2 → 3`

The first migration that does real work.

1. Prepend `CREATE_SEASON { id: 's1', name: '2026', team: 'Bethel Tigers', format: <current constants> }`.
2. Stamp `seasonId: 's1'` onto every `ADD_PLAYER`, `EDIT_PLAYER`, `REMOVE_PLAYER`, and `START_GAME`.
3. Stamp `result: 'undecided'` onto every `END_MATCH`.

| Guarantee | Source |
|---|---|
| Every existing player becomes a career player | `FR-003` |
| Every number becomes that season's number | `FR-002` |
| Every existing game belongs to the season | `FR-004` |
| Every existing figure is identical afterwards | `FR-005` |
| No past match is retroactively declared lost | R-005 |

Verified against **two** committed fixtures — a release-001 log and a release-002 log — so the chain is proven from both real starting points.

---

## 6. Import file

```json
{ "app": "vbtracking", "kind": "historical-games", "formatVersion": 1,
  "season": { "name": "…", "team": "…", "roster": [{ "number": "…", "name": "…" }] },
  "games": [{ "date": "…", "opponent": "…", "location": "…", "court": "…",
              "result": "won|lost|undecided",
              "serves": [{ "name": "…", "in": 0, "out": 0 }], "notes": "…" }] }
```

| Rule | Source |
|---|---|
| Players matched **by name** against the active season's roster | R-006 |
| An unknown name aborts the whole import, naming the player | `FR-041` |
| Malformed input is refused with a reason; nothing is written | `FR-042` |
| Negative counts are refused | `FR-039` |
| Import is all-or-nothing | R-006 |

Distinct from the backup file of release 002: that one **replaces** everything and holds an event log; this one **adds** games and holds figures. Different verbs, different shapes, separate code paths.
