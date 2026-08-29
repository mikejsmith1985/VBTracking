# Contract: Domain API additions

**Feature**: `003-seasons-and-career` | **Date**: 2026-08-29

Extends the contracts of releases 001 and 002, which remain in force. `src/domain/` stays pure — no DOM, storage, clock, or randomness — and imports still point one direction only: `ui → state → domain`.

---

## `src/domain/events.js`

```js
export function createSeason(id, name, team, format)
export function renameSeason(id, name, team)
export function activateSeason(id)
export function setGameContext(gameId, context)   // { date, opponent, location, court }
export function setGameNotes(gameId, notes)
export function addHistoricalGame(id, seasonId, context, entries, notes)
export function editHistoricalGame(id, context, entries, notes)

export const MATCH_RESULT = { WON: 'won', LOST: 'lost', UNDECIDED: 'undecided' }
export const DEFAULT_FORMAT = { matchesPerGame: 3, targetScore: 21, playersOnCourt: 6 }
```

`addPlayer`, `editPlayer`, `removePlayer`, `startGame` each gain a `seasonId`; `endMatch` gains a `result`.

---

## `src/domain/reducer.js`

New readers:

```js
export function activeSeason(state)
export function seasonById(state, seasonId)
export function seasonMembers(state, seasonId)      // [{ playerId, number, name }]
export function numberFor(state, seasonId, playerId) // string | null
export function playerById(state, playerId)          // career identity
export function gamesInSeason(state, seasonId)
export function gamesForPlayer(state, playerId)      // across every season
export function seasonsForPlayer(state, playerId)
```

| Guarantee | Source |
|---|---|
| A number is resolved through a season and never read off a player | `FR-019`, `FR-022` |
| Removing a player from a season leaves the person and their serves intact | `FR-023` |
| A player referenced by any game cannot be deleted | `FR-010` |
| `ACTIVATE_SEASON` is refused while a match is in progress, with a reason | `FR-015` |
| Renaming a player changes the name everywhere, in every season | `FR-011` |
| A duplicate number within a season is accepted; a duplicate person is refused | `FR-020`, `FR-021` |
| Context and notes may be set on any game, ended or not | `FR-025`, `FR-033` |
| A historical game holds no matches and no turns | R-003 |
| No transition mutates the state it was given | Replay correctness |

---

## `src/domain/stats.js`

```js
export function aggregate(games, options)   // → { byPlayer, coverage }
export function seasonStats(state, seasonId)
export function careerStats(state, playerId)
export function gameSummary(game)           // → { topScorer, topPercentage, serves, servesIn }
export function seasonRecord(games)         // → { won, lost, undecided }
export function recordByOpponent(games)     // → Map<opponent, record>
export function gameResult(game)            // → 'won' | 'lost' | 'undecided'
```

| Guarantee | Source |
|---|---|
| `serves`, `servesIn`, `inPercentage` span tracked and historical games alike | `FR-043` |
| `points`, `turnsTaken`, `turnsOnCourt` count tracked games only, and `coverage` says so | `FR-044` |
| A figure never recorded is `null`, never `0` | `FR-045` |
| A season's totals equal the sum of its games | `FR-050` |
| A career total equals the sum of that player's seasons | `FR-048` |
| An undecided match counts toward neither wins nor losses | `FR-029` |
| A game is won only when more matches were won than lost | `FR-030` |
| Every figure from releases 001 and 002 is unchanged | `FR-051` |

---

## `src/domain/migrations.js`

```js
export const SCHEMA_VERSION = 3
export const MIGRATIONS = { 1: …, 2: migrateTwoToThree }
```

`migrateTwoToThree` is pure and additive: it prepends one `CREATE_SEASON` and stamps `seasonId` / `result` onto existing events. It renames nothing, removes nothing, and shifts no index other than by the single prepend.

| Guarantee | Source |
|---|---|
| Every existing player becomes a career player | `FR-003` |
| Every jersey number becomes that season's number | `FR-002` |
| Every existing game joins the season | `FR-004` |
| Every replayed figure is identical to before | `FR-005` |
| No past match becomes a loss — all become `undecided` | R-005 |
| Proven against committed release-001 **and** release-002 fixtures | R-008 |

---

## `src/state/historical-import.js` — new

Parses the batch file. Builds nothing and writes nothing; it returns events for the caller to dispatch.

```js
export function parseHistoricalGames(text, season)
//   → { games, ok: true } | { ok: false, reason }
```

| Guarantee | Source |
|---|---|
| Players are matched by name against the season's roster | R-006 |
| An unknown name fails the whole import and names that player | `FR-041` |
| Malformed input, a missing marker, or a negative count is refused with a reason | `FR-039`, `FR-042` |
| Never throws; every failure is a returned reason | `FR-042` |
| Returns events only — the caller decides whether to dispatch | Purity |

Kept separate from `backup.js`: that file **replaces** everything and carries an event log; this one **adds** games and carries figures. Different verbs, different shapes, no shared parsing.
