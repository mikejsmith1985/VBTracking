# Tasks: Volleyball Serve Tracker

**Feature**: `001-volleyball-serve-tracker` | **Branch**: `feature/volleyball-serve-tracker` | **Date**: 2026-08-29

**Input**: [plan.md](./plan.md) · [data-model.md](./data-model.md) · [contracts/](./contracts/) · [quickstart.md](./quickstart.md)

Ordering is dependency-driven: the pure domain is built and proven first, because every other layer reads from it. `[P]` marks tasks that may run in parallel with their siblings.

---

## Phase A — Scaffold

| # | Task | Output |
|---|---|---|
| A1 | Dev-only manifest. Vitest + Cypress. Nothing ships. | `package.json`, `vitest.config.js` |
| A2 | Clean dev-server launch (Article V) | `scripts/run-dev-clean.ps1` |
| A3 | Icon generation — dependency-free PNG encoder, run once | `scripts/generate-icons.mjs`, `icons/*.png` |

---

## Phase B — Domain tests (RED)

Written before implementation. Must fail first. Pure — no DOM, no storage, no clock.

| # | Task | Covers |
|---|---|---|
| B1 | `[P]` Reducer: roster rules, 20-player cap, edit preserves identity, removal drops turns | `FR-001`–`FR-007` |
| B2 | `[P]` Reducer: game/match lifecycle, 3-match cap, ended matches immutable | `FR-008`–`FR-013` |
| B3 | `[P]` Reducer: turn boundaries — point continues, non-point closes, player switch closes, empty turns never persist | `FR-020`, `FR-021`, `FR-024`–`FR-027` |
| B4 | `[P]` Stats: serves / in / points / percentage / turns at all three scopes; `null` not `NaN` | `FR-036`–`FR-039` |
| B5 | `[P]` Stats: no count caps at 5; over-limit flag at 6+ | `FR-029`, `FR-030` |
| B6 | `[P]` Palette: adjacent turns never share a colour, including wrap-around | `FR-032`, `FR-033` |
| B7 | `[P]` Undo: exact restore, empty-turn removal, ended matches untouched, no-op at floor | `FR-040`–`FR-043` |

---

## Phase C — Domain implementation (GREEN)

| # | Task | Output |
|---|---|---|
| C1 | Event constructors and outcome constants | `src/domain/events.js` |
| C2 | `applyEvent` / `replay` / validation — every rule in the spec lives here and nowhere else | `src/domain/reducer.js` |
| C3 | Derived statistics at turn, match, game scope; active server; undoable depth | `src/domain/stats.js` |
| C4 | `[P]` Turn colour assignment, 6-colour palette | `src/domain/palette.js` |

**Gate**: Phase B green, every test under 10 ms.

---

## Phase D — State layer

| # | Task | Output | Covers |
|---|---|---|---|
| D1 | Integration test against **real** `localStorage` — round-trip, corrupt payload, unknown version, quota failure | `tests/integration/persistence.test.js` | `FR-057`, `FR-058` |
| D2 | Storage adapter — the only module touching `localStorage` | `src/state/persistence.js` | `FR-056` |
| D3 | Store — event log, dispatch, undo, subscribe, storage status | `src/state/store.js` | `FR-040`, `FR-058` |

---

## Phase E — Shell, styling, offline

| # | Task | Output | Covers |
|---|---|---|---|
| E1 | Entry point, iOS meta, safe-area viewport, tab bar | `index.html` | `FR-049`, `FR-051`, `FR-053` |
| E2 | Manifest — `standalone`, `portrait`, relative `start_url` | `manifest.webmanifest` | `FR-045`, `FR-053` |
| E3 | Service worker — cache-first, explicit precache list, versioned | `sw.js` | `FR-054`, `FR-055` |
| E4 | Styles — thumb zone, ≥44 pt targets, touch suppression, AA contrast | `styles/app.css` | `FR-046`–`FR-052` |

---

## Phase F — Screens

| # | Task | Output | Covers |
|---|---|---|---|
| F1 | Bootstrap, routing, SW registration, storage warning banner | `src/ui/app.js` | `FR-058` |
| F2 | Tally component — one mark per serve, turn colour, shape-encoded outcome, over-limit flag, per-turn counts | `src/ui/components/tally.js` | `FR-031`–`FR-035` |
| F3 | Track screen — picker, server strip, side-out state, outcome controls, undo, end match | `src/ui/screens/track.js` | `FR-015`–`FR-023` |
| F4 | Roster screen — no placeholder rows, in-place edit, 20 cap, delete confirmation | `src/ui/screens/roster.js` | `FR-001`–`FR-006` |
| F5 | Stats screen — turn / match / game scopes, live updates | `src/ui/screens/stats.js` | `FR-036`–`FR-039` |

---

## Phase G — Verification

| # | Task | Evidence |
|---|---|---|
| G1 | Full unit + integration suite green | `npm test` output |
| G2 | Import direction holds: `ui → state → domain`; no rule in `src/ui/` | Source review |
| G3 | Local run — record a game, exercise undo, confirm stats | Browser |
| G4 | **On-device airplane-mode game** — the Article X proof | `quickstart.md` V-7 |
| G5 | `CHANGELOG.md` updated | Article VI |

---

## Dependency graph

```
A ──▶ B ──▶ C ──▶ D ──▶ F ──▶ G
      │           │      ▲
      └───────────┘      │
                    E ───┘
```

Phase E is independent of B–D and may be built alongside them. Phase F requires both C and E.

## Parallel opportunities

- B1–B7 are independent of one another.
- C4 (palette) has no dependency on C1–C3.
- E1–E4 may proceed in parallel with the entire domain track.
- F4 and F5 are independent of each other once F1 exists.
