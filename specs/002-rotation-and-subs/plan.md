# Implementation Plan: Rotation, Substitutions, and Durable Data

**Branch**: `feature/rotation-and-subs` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-rotation-and-subs/spec.md`

## Summary

The second release of the courtside serve tracker. It teaches the app the team's rotation so the next server is chosen automatically, makes substitutions recordable so that rotation stays true, and makes the stored data durable across app updates and lost phones.

The technical approach turns on one decision: **the automatic advance lives in the reducer, not the UI, and emits no event.** When a recorded serve closes a turn and the match has a lineup, the same state transition opens the next turn for the next player. That keeps the rule where every other rule lives, replays identically, and makes "one undo reverses one operator action" (`FR-024`) a property of the design rather than something handled.

The rotation pointer is likewise derived, never stored: each turn records the lineup position it was served from, and the next position is the last non-null one plus one. Nothing can go stale, because there is nothing to keep in step.

Data durability is a migration chain plus an export file. The `1 → 2` step is the identity function — release 002 only adds event types — and that is the point: the mechanism is proven to run before a release needs it to do real work.

## Technical Context

**Language/Version**: JavaScript (ES2022 modules), no transpilation — unchanged

**Primary Dependencies**: **None at runtime**, unchanged. Development only: Vitest, Cypress with `cypress-real-events`

**Storage**: `localStorage`, single versioned key, behind one adapter — unchanged. Gains a migration chain and a file-based export/import path.

**Testing**: Vitest for the pure domain and the storage adapter; a committed release-001 log fixture for the migration; on-device verification for the share sheet, the touch gesture, and offline behaviour

**Target Platform**: iOS Safari 16.4+, installed to the Home Screen as a standalone PWA, portrait phone only — unchanged

**Project Type**: Single static web application, no server component — unchanged

**Performance Goals**: A tap reflected within one frame. Full event-log replay under 1 ms at end-of-game volume, unchanged by the added per-turn lineup snapshot.

**Constraints**: All of release 001's, unchanged. Added: real recorded data must survive the upgrade with no operator action; a failed storage write must never destroy the original.

**Scale/Scope**: 1 operator, 1 device, ≤ 20 players, 6 on court, 3 matches per game, a few hundred serves per game. 3 screens plus a lineup setup step.

## Constitution Check

*GATE: evaluated before Phase 0 and re-evaluated after Phase 1. Both passes recorded.*

| Article | Gate | Pre-Phase 0 | Post-Phase 1 |
|---|---|---|---|
| **I** — Prime Directive | Best route, not fastest | ✅ The advance is put in the reducer rather than the UI specifically because the UI version breaks undo and replay — the harder placement is the correct one. | ✅ Holds. |
| **II** — Process Protection | No wildcard process kills | ✅ N/A | ✅ N/A |
| **III** — Branching | Feature branch, PR to main | ✅ On `feature/rotation-and-subs`, cut from merged `main`. | ✅ Holds. |
| **IV** — Code Quality | Self-documenting names, purpose comments, doc comments, < 40-line functions, guard clauses | ✅ Binding. The reducer grows; new transitions are extracted as named functions rather than added to a switch arm. | ✅ Every new module has one responsibility. |
| **V** — Testing | Three layers, Red→Green→Refactor | ⚠️ Deviation carried forward — see Complexity Tracking. | ⚠️ Stands, and is narrowed by the release-001 log fixture. |
| **VI** — Documentation | `CHANGELOG.md` is the source of truth | ✅ Updated in the implementation PR. Spec Kit artifacts are exempt. | ✅ Holds. |
| **VII** — Framework-First | Confirm the framework does not already provide it | ✅ Export uses the platform's Web Share API and file input rather than a library. No new runtime dependency. | ✅ The only custom infrastructure is the migration chain, justified below. |
| **VIII** — Release | Local pipeline only, never GitHub Actions | ✅ No build step. Branch push, PR, Pages redeploys from `main`. | ✅ Holds. |
| **IX** — Vault | Secrets injected, never handled | ✅ N/A — no secrets, no network surface. | ✅ N/A |
| **X** — Verification | Evidence, not "it compiles" | ✅ The stated proof is `quickstart.md` V2-1: a real release-001 game surviving the upgrade on the device, plus V2-6 producing an actual file through the iOS share sheet. | ✅ Eight scenarios, each mapped to requirements. |
| **XI** — Output Restraint | ≤ 1 dashboard, no unrequested summaries | ✅ None. | ✅ Holds. |
| **XII** — Response Format | Tight, scannable | ✅ Applies to conversation, not artifacts. | ✅ N/A |

**Gate result**: **PASS**, with one deviation carried forward from release 001 and one new one, both justified below.

## Project Structure

### Documentation (this feature)

```text
specs/002-rotation-and-subs/
├── plan.md              # This file
├── spec.md              # 6 stories, 54 requirements
├── research.md          # Phase 0 — 9 decisions
├── data-model.md        # Phase 1 — new events, extended entities, migration
├── quickstart.md        # Phase 1 — 8 validation scenarios
├── contracts/
│   ├── domain-api.md
│   └── ui-interaction.md
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

Additions and changes only; everything unlisted is untouched.

```text
src/
├── domain/                       # PURE. Every rule in this feature lands here.
│   ├── events.js                 # + setLineup, substitute, clearLineup, LINEUP_SIZE
│   ├── reducer.js                # + lineup/substitute transitions; RECORD_SERVE advances
│   ├── stats.js                  # + turnsOnCourt, substitutionsFor
│   ├── palette.js                #   unchanged
│   └── migrations.js             # NEW — the version chain, pure
├── state/
│   ├── persistence.js            # migrates instead of refusing an older version
│   ├── backup.js                 # NEW — build and parse an export payload
│   └── store.js                  # + transient pending-substitution state
└── ui/
    ├── app.js                    # + lineup, substitution, export/import actions
    ├── html.js                   # unchanged
    ├── components/
    │   ├── tally.js              # + off-lineup marker
    │   ├── statstable.js         # + turns-on-court column
    │   └── chip.js               # NEW — the number-only player chip, one place
    └── screens/
        ├── track.js              # dock stays on outcomes through a side-out
        ├── lineup.js             # NEW — pick six, order them, choose first server
        ├── roster.js             # unchanged
        └── stats.js              # + substitutions, export/import

tests/
├── fixtures/
│   └── v1-log.json               # NEW — a log written by the shipped release 001
├── unit/                         # + rotation, substitution, migration, chip, lineup
└── integration/
    ├── persistence.test.js       # + migration against the real fixture
    └── backup.test.js            # NEW — export/import round trip
```

**Structure Decision**: unchanged from release 001 — three layers, imports one direction only: `ui → state → domain`.

Two new modules are worth naming. `src/domain/migrations.js` is pure and knows nothing about storage, so the chain is unit-testable without a browser. `src/state/backup.js` builds and parses the payload but never delivers it — the share sheet and the file input are UI concerns — which keeps the parsing rules testable in Node.

`src/ui/components/chip.js` exists because the player chip now appears in three places (picker, lineup setup, substitution) and must look and behave identically in all of them.

## Phase Outputs

| Phase | Artifact | Status |
|---|---|---|
| 0 | `research.md` — 9 decisions, all unknowns resolved | ✅ Complete |
| 1 | `data-model.md` | ✅ Complete |
| 1 | `contracts/domain-api.md`, `contracts/ui-interaction.md` | ✅ Complete |
| 1 | `quickstart.md` — 8 scenarios | ✅ Complete |
| 1 | Agent context (`CLAUDE.md` SPECKIT block) | ✅ Updated |
| 2 | `tasks.md` | Pending `/speckit-tasks` |

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| **Article V** — integration tests do not use testcontainers | Carried forward from release 001 and unchanged: this application has no server, database, or network to containerise. Its real integration surfaces are `localStorage`, the service worker, and the file system, all browser primitives. The storage adapter is tested against a **real** `Storage`, and the migration against a **real release-001 log fixture**. | Containerising a feature with no backend would test nothing that exists. Mocking `localStorage` is the mocked driver the Article forbids. This release narrows the gap rather than widening it: the fixture means the migration is tested against the format as shipped, not as remembered. |
| **Article VII** — a custom migration chain rather than a library | No framework governs this project, and the platform provides no schema-versioning primitive. The chain exists to satisfy `FR-001`–`FR-008`, which protect data a stakeholder has already recorded. | Schema-migration libraries assume a database with a schema; this is an append-only array of plain objects. The chain is a version number and an ordered map of pure functions — smaller than any dependency that could replace it, and it is the first runtime dependency the app would ever take. |
| **New: per-turn lineup snapshot duplicates derivable state** | `FR-054` (turns on court) needs the lineup *as it stood at each turn*. Deriving it means folding substitution history at every read, in every consumer — and each consumer is a chance to get it wrong. | Storing only the starting lineup is smaller but pushes a fold into every reader. Six ids per turn is roughly 240 ids across a full match, which is nothing at this scale, and it keeps statistics a filter rather than a reconstruction. The duplication is bounded and derived at write time by the reducer, so it cannot drift. |
