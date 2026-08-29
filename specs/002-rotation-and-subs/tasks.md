# Tasks: Rotation, Substitutions, and Durable Data

**Feature**: `002-rotation-and-subs` | **Branch**: `feature/rotation-and-subs` | **Date**: 2026-08-29

**Input**: [plan.md](./plan.md) · [data-model.md](./data-model.md) · [contracts/](./contracts/) · [quickstart.md](./quickstart.md)

**Hard ordering rule**: Phase A ships before anything that writes data in the new shape. Real games are already recorded on the live build.

---

## Phase A — Carry existing data forward (US1, P1)

| # | Task | Covers |
|---|---|---|
| A1 | Capture a log written by the **shipped release-001 code** and commit it as `tests/fixtures/v1-log.json`. Generated before any release-002 code exists, so it is the format as shipped, not as remembered. | `quickstart.md` prerequisite |
| A2 | `[P]` Migration tests (RED): chain applies in order; newer version refused; unknown path refused; current version untouched; input array never mutated. | `FR-003`–`FR-006` |
| A3 | `src/domain/migrations.js` — `SCHEMA_VERSION`, ordered `MIGRATIONS`, pure `migrate()`. `1 → 2` is identity. | `FR-002`, `FR-003` |
| A4 | Integration test (RED): load the **real fixture** through the adapter; assert every replayed figure is identical. | `FR-001`, `FR-007` |
| A5 | `src/state/persistence.js` — migrate an older version instead of refusing it; stamp and write back; a failed write-back keeps the in-memory log and leaves the original alone. | `FR-003`, `FR-004`, `FR-008` |

**Gate**: fixture loads, every figure matches, nothing re-migrates on second load.

---

## Phase B — Backup and restore (US5, P2)

Independent of A3–A5; only shares the version chain.

| # | Task | Covers |
|---|---|---|
| B1 | `[P]` Tests (RED): empty export is importable; missing marker, malformed JSON, missing events, newer version each refused with a reason; older version migrated; never throws. | `FR-039`, `FR-043`–`FR-046` |
| B2 | `src/state/backup.js` — `buildExport(events, now)`, `parseImport(text)`. Builds and parses only; delivery is UI. | `FR-038`, `FR-040`, `FR-042` |

---

## Phase C — Rotation (US2 + US3, P1)

| # | Task | Covers |
|---|---|---|
| C1 | `[P]` Reducer tests (RED): lineup of exactly 6, distinct, on-roster; refused once a serve exists; refused with no match. | `FR-009`–`FR-011`, `FR-016` |
| C2 | `[P]` Reducer tests (RED): a closing serve opens the next turn; wraps 5→0; skips `null` positions; does nothing without a lineup; one undo reverses serve **and** advance. | `FR-018`, `FR-019`, `FR-023`–`FR-025` |
| C3 | `[P]` Reducer tests (RED): override sets the server and the rotation continues from their position. | `FR-021`, `FR-022` |
| C4 | `src/domain/events.js` — `setLineup`, `substitute`, `clearLineup`, `LINEUP_SIZE`. | Data model §1 |
| C5 | `src/domain/reducer.js` — `SET_LINEUP` / `CLEAR_LINEUP`; `lineupPosition` and `lineupSnapshot` on every turn; `RECORD_SERVE` advances the rotation in the same transition. | `FR-018`–`FR-025` |
| C6 | `src/domain/reducer.js` — readers: `currentLineup`, `nextRotationPosition`, `nextRotationPlayerId`, `lineupPositionOf`. | Contract |
| C7 | `[P]` `src/domain/stats.js` — `turnsOnCourt`, `substitutionsFor`; every release-001 figure unchanged. | `FR-052`–`FR-054` |

**Gate**: six recorded outcome taps produce six servers in lineup order, and one undo reverses one action.

---

## Phase D — Substitutions (US4, P2)

| # | Task | Covers |
|---|---|---|
| D1 | `[P]` Tests (RED): replaces at position; rotation follows; prior serves stay attributed; incoming already in lineup refused; same player refused; undo restores. | `FR-027`–`FR-031`, `FR-035`, `FR-037` |
| D2 | `[P]` Tests (RED): substituting the **active server** closes their turn with its serves intact and opens one for the incoming player. | `FR-029`, `FR-034` |
| D3 | `src/domain/reducer.js` — `SUBSTITUTE` transition and validation. | `FR-026`–`FR-031`, `FR-034` |
| D4 | `src/state/store.js` — transient pending-substitution state; never appended, never persisted; cleared on match end. | `FR-032`, `FR-033` |

---

## Phase E — Interface

| # | Task | Output | Covers |
|---|---|---|---|
| E1 | `[P]` Number-only player chip, one implementation for all three call sites | `src/ui/components/chip.js` | `FR-047`–`FR-051` |
| E2 | Lineup setup — pick six, order them, choose the first server, skip, prefill from the previous match | `src/ui/screens/lineup.js` | `FR-009`–`FR-015` |
| E3 | Track screen — dock stays on outcomes through a side-out; server shown at display size; off-lineup marker | `src/ui/screens/track.js` | `FR-018`, `FR-020`, `FR-023` |
| E4 | `[P]` Off-lineup marker on the tally board | `src/ui/components/tally.js` | `FR-023` |
| E5 | `[P]` Turns-on-court column; substitutions list per match | `src/ui/components/statstable.js`, `src/ui/screens/stats.js` | `FR-053`, `FR-054` |
| E6 | Export and import controls beside Discard, with replace-everything confirmation | `src/ui/screens/stats.js` | `FR-038`, `FR-040`, `FR-041` |
| E7 | Wiring — double-tap arming, lineup actions, export via share sheet with download fallback, import via file input | `src/ui/app.js` | `FR-026`, `FR-032`, `FR-038` |
| E8 | Styles for chips, lineup setup, and the armed state | `styles/app.css` | `FR-047`, `FR-052` |

---

## Phase F — Ship

| # | Task | Evidence |
|---|---|---|
| F1 | Add every new source file to the `sw.js` precache list; bump `CACHE`. `tests/unit/sw.test.js` fails if one is missed. | `npm test` |
| F2 | Full suite green; release-001 tests unchanged and passing | `npm test` |
| F3 | Import direction holds: `ui → state → domain`; no rule in `src/ui/` | Source review |
| F4 | Browser pass at phone width: rotation, substitution, lineup, export/import | Screenshots |
| F5 | **On-device V2-1** — a real release-001 game survives the upgrade | `quickstart.md` V2-1 |
| F6 | **On-device V2-6** — export reaches a real file through the share sheet | `quickstart.md` V2-6 |
| F7 | **On-device V2-8** — release 001 has not regressed, airplane mode included | `quickstart.md` V2-8 |
| F8 | `CHANGELOG.md` updated | Article VI |

---

## Dependency graph

```
A ──▶ C ──▶ D ──▶ E ──▶ F
 │           ▲      ▲
 └──▶ B ─────┴──────┘
```

Phase A gates everything. B is independent of C and D. E needs C, D, and B.

## Parallel opportunities

- A2 with A4; B1 with everything in A.
- C1, C2, C3 are independent of each other; C7 needs only C5.
- D1 with D2.
- E1, E4, E5 are independent once C and D land.
