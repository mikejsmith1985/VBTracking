# Tasks: Seasons, Career Players, and Game Context

**Feature**: `003-seasons-and-career` | **Branch**: `feature/seasons-and-career` | **Date**: 2026-08-29

**Input**: [plan.md](./plan.md) · [data-model.md](./data-model.md) · [contracts/](./contracts/) · [quickstart.md](./quickstart.md)

**Hard ordering rule**: Phase A ships before anything that writes data in the new shape. A real season is already recorded on the live build.

---

## Phase A — Carry the season forward (US1, P1)

| # | Task | Covers |
|---|---|---|
| A1 | Capture a log from the **live release-002 build** as `tests/fixtures/v2-log.json`, with its expected figures, before any release-003 code exists | `quickstart.md` prerequisite |
| A2 | `[P]` Migration tests (RED): the `2 → 3` step prepends one season, stamps `seasonId` on the four event types and `result: undecided` on `END_MATCH`, renames nothing, and shifts no index beyond the prepend | `FR-002`–`FR-004` |
| A3 | `[P]` Integration tests (RED): both fixtures replay to identical figures after migration | `FR-001`, `FR-005` |
| A4 | `src/domain/migrations.js` — `SCHEMA_VERSION = 3`, `migrateTwoToThree` | `FR-002`–`FR-006` |

**Gate**: both fixtures load, every figure identical, nothing re-migrates.

---

## Phase B — Career players and seasons (US2, P1)

| # | Task | Covers |
|---|---|---|
| B1 | `[P]` Reducer tests (RED): season creation, activation refused mid-match, membership add/remove, duplicate person refused, duplicate number warned, per-season numbers, career rename, person not deletable while referenced | `FR-007`–`FR-023` |
| B2 | `src/domain/events.js` — season events, `seasonId` on four events, `result` on `endMatch`, `DEFAULT_FORMAT` | Data model §1 |
| B3 | `src/domain/reducer.js` — `players[]` split from `seasons[].members[]`; season transitions; validation | `FR-007`–`FR-023` |
| B4 | `src/domain/reducer.js` — readers: `activeSeason`, `seasonMembers`, `numberFor`, `playerById`, `gamesInSeason`, `gamesForPlayer`, `seasonsForPlayer` | Contract |

---

## Phase C — Context, results, notes (US3 + US6, P1/P2)

| # | Task | Covers |
|---|---|---|
| C1 | `[P]` Tests (RED): context settable on any game including ended; two games one date stay distinct; result recorded; unmarked match is undecided; game result derived; season record and per-opponent breakdown | `FR-024`–`FR-034` |
| C2 | `src/domain/reducer.js` — `SET_GAME_CONTEXT`, `SET_GAME_NOTES`, `result` on `END_MATCH` | `FR-024`–`FR-034` |
| C3 | `src/domain/stats.js` — `gameResult`, `seasonRecord`, `recordByOpponent` | `FR-030`, `FR-031` |

---

## Phase D — Historical games and import (US4, P2)

| # | Task | Covers |
|---|---|---|
| D1 | `[P]` Reducer tests (RED): historical game holds entries and no matches; negative counts refused; unknown player refused; editable | `FR-035`–`FR-039` |
| D2 | `[P]` Parser tests (RED): unknown name aborts the whole import naming the player; malformed, unmarked, and negative refused with reasons; never throws; all-or-nothing | `FR-040`–`FR-042` |
| D3 | `src/domain/reducer.js` — `ADD_HISTORICAL_GAME`, `EDIT_HISTORICAL_GAME` | `FR-035`–`FR-038` |
| D4 | `src/state/historical-import.js` — parse the batch into events; dispatch nothing | `FR-040`–`FR-042` |
| D5 | Verify the real file (`historical-games.json`) parses and its totals reconcile against the sheets | `SC-004` |

---

## Phase E — Statistics and honesty (US5 + US7, P2/P3)

| # | Task | Covers |
|---|---|---|
| E1 | `[P]` Tests (RED): serves and in span both game kinds; points and turns count tracked games only; coverage reported; never a zero for not-recorded; season equals sum of games; career equals sum of seasons | `FR-043`–`FR-051` |
| E2 | `src/domain/stats.js` — `aggregate` with coverage; `seasonStats`; `careerStats`; `gameSummary` | `FR-043`–`FR-050` |
| E3 | `src/ui/components/statstable.js` — coverage labelling; `—` for not recorded, never `0` | `FR-044`, `FR-045` |

---

## Phase F — Interface

| # | Task | Output | Covers |
|---|---|---|---|
| F1 | Season screen: totals, record, per-opponent, season and roster admin | `src/ui/screens/season.js` | `FR-012`–`FR-014`, `FR-031`, `FR-043` |
| F2 | Career view: one player across seasons | `src/ui/screens/career.js` | `FR-048` |
| F3 | Game form: context, notes, historical entry | `src/ui/screens/gameform.js` | `FR-024`, `FR-032`, `FR-035` |
| F4 | `[P]` Roster edits the active season's membership; numbers resolved through the season | `src/ui/screens/roster.js`, `components/chip.js` | `FR-018`–`FR-022` |
| F5 | `[P]` Match result on End Match, in one tap | `src/ui/screens/track.js` | `FR-028` |
| F6 | `[P]` Game context and notes on the Stats screen | `src/ui/screens/stats.js` | `FR-027`, `FR-034` |
| F7 | Wiring: season actions, import, context and notes editing; fourth tab | `src/ui/app.js`, `index.html` | `FR-040` |
| F8 | `[P]` Styles for the season, career, and game-form screens | `styles/app.css` | Platform contract |

---

## Phase G — Ship

| # | Task | Evidence |
|---|---|---|
| G1 | Every new source file in the `sw.js` precache list; `CACHE` bumped | `npm test` |
| G2 | Full suite green; releases 001 and 002 suites unchanged and passing | `npm test` |
| G3 | `ui → state → domain` holds; no rule in `src/ui/` | Source review |
| G4 | Browser pass at phone width: season, career, import, context, results | Screenshots |
| G5 | **On-device V3-1** — a real release-002 season survives | `quickstart.md` |
| G6 | **On-device V3-4** — the five paper games import on the phone | `quickstart.md` |
| G7 | **On-device V3-7** — releases 001 and 002 have not regressed, airplane mode included | `quickstart.md` |
| G8 | `CHANGELOG.md` updated | Article VI |

---

## Dependency graph

```
A ──▶ B ──▶ C ──▶ E ──▶ F ──▶ G
            │     ▲
            └▶ D ─┘
```

A gates everything. C and D are independent of each other; E needs both. F needs E.

## Parallel opportunities

- A2 with A3; B1 written alongside A4.
- C1 with D1 and D2.
- E1 with the tail of D.
- F4, F5, F6, F8 are independent once E lands.
