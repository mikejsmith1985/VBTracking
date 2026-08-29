# Implementation Plan: Seasons, Career Players, and Game Context

**Branch**: `feature/seasons-and-career` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-seasons-and-career/spec.md`

## Summary

The third release. The first two made the app good at recording a match; this one makes it good at holding a history — seasons, career players, game context, results, notes, and the five games recorded on paper before the app existed.

The technical approach turns on two decisions.

**The jersey number moves off the player and onto the season membership.** A `Player` becomes `{ id, name }` — a person who outlives every roster. This is the change that cannot be retrofitted cheaply, and it is invisible until a second season arrives.

**The migration is additive.** It prepends one `CREATE_SEASON` and stamps a field onto four existing event types. It renames nothing and decomposes nothing, because the alternative shifts every event index and turns a migration bug into silent corruption of the only real season recorded.

Statistics gain one honesty rule that shapes the whole reporting layer: historical games hold serves only, so points and turns are labelled as covering tracked games, and a figure never recorded is shown as not recorded rather than as zero.

## Technical Context

**Language/Version**: JavaScript (ES2022 modules), no transpilation — unchanged

**Primary Dependencies**: **None at runtime**, unchanged. Development only: Vitest, Cypress

**Storage**: `localStorage`, single versioned key, behind one adapter. Schema version moves to 3.

**Testing**: Vitest for the pure domain and adapters; **two** committed fixtures (release-001 and release-002 logs) for the migration; on-device verification for the screens and the file import

**Target Platform**: iOS Safari 16.4+, installed standalone, portrait phone only — unchanged

**Project Type**: Single static web application, no server — unchanged

**Performance Goals**: A tap reflected within one frame. Replay under 1 ms at a season's volume — a season is a few thousand events.

**Constraints**: All of releases 001 and 002, unchanged. Added: a real recorded season must survive with identical figures and no operator action; nothing never-recorded may be displayed as zero.

**Scale/Scope**: 1 operator, 1 device, ≤ 20 players per season, several seasons, ~20 games per season. 4 screens plus season and career views.

## Constitution Check

*GATE: evaluated before Phase 0 and re-evaluated after Phase 1.*

| Article | Gate | Pre-Phase 0 | Post-Phase 1 |
|---|---|---|---|
| **I** — Prime Directive | Best route, not fastest | ✅ The additive migration is chosen over the tidier decomposition specifically because a bug in the tidy one is silent. Correctness of real recorded data over elegance. | ✅ Holds. |
| **II** — Process Protection | No wildcard kills | ✅ N/A | ✅ N/A |
| **III** — Branching | Feature branch, PR to main | ✅ On `feature/seasons-and-career`, cut from merged `main`. | ✅ Holds. |
| **IV** — Code Quality | Self-documenting, < 40-line functions, doc comments | ✅ Binding. The reducer grows again; new transitions are extracted as named functions. | ✅ Each new module has one responsibility. |
| **V** — Testing | Three layers, Red→Green→Refactor | ⚠️ Deviation carried forward — see Complexity Tracking. | ⚠️ Stands, and narrows again: a second real fixture is added. |
| **VI** — Documentation | `CHANGELOG.md` is the source of truth | ✅ Updated in the PR. Spec Kit artifacts exempt. | ✅ Holds. |
| **VII** — Framework-First | Confirm the platform does not already provide it | ✅ File import uses the platform file input. No new runtime dependency. | ✅ Only the migration step and the import parser are custom, both justified below. |
| **VIII** — Release | Local pipeline only | ✅ No build step. Branch push, PR, Pages redeploys from `main`. | ✅ Holds. |
| **IX** — Vault | Secrets injected | ✅ N/A — no secrets, no network surface. | ✅ N/A |
| **X** — Verification | Evidence, not "it compiles" | ✅ The proof is `quickstart.md` V3-1: a real release-002 season surviving on the device with identical figures, plus V3-4 importing the five transcribed games. | ✅ Seven scenarios, each mapped to requirements. |
| **XI** — Output Restraint | ≤ 1 dashboard | ✅ None. | ✅ Holds. |
| **XII** — Response Format | Tight, scannable | ✅ Conversation only. | ✅ N/A |

**Gate result**: **PASS**, with the deviation carried forward from release 001 and one new one, both justified below.

## Project Structure

### Documentation (this feature)

```text
specs/003-seasons-and-career/
├── plan.md · spec.md · research.md · data-model.md · quickstart.md
├── contracts/domain-api.md
├── checklists/requirements.md
├── historical-games.json     # the five paper games, transcribed and reconciled
└── tasks.md                  # Phase 2 output
```

### Source Code (repository root)

Additions and changes only.

```text
src/
├── domain/                        # PURE. Every rule lands here.
│   ├── events.js                  # + season, context, notes, historical events; result on endMatch
│   ├── reducer.js                 # + seasons, memberships, career players, historical games
│   ├── stats.js                   # + aggregate/coverage, season, career, records, game summary
│   └── migrations.js              # + the 2 -> 3 step, the first that does real work
├── state/
│   ├── historical-import.js       # NEW — parse the batch file into events
│   ├── backup.js                  # unchanged
│   └── store.js                   # unchanged
└── ui/
    ├── app.js                     # + season, career, context, notes, import actions
    ├── components/
    │   ├── chip.js                # number resolved through the season
    │   └── statstable.js          # + coverage labelling; never a zero for "not recorded"
    └── screens/
        ├── season.js              # NEW — season stats, record, per-opponent, season admin
        ├── career.js              # NEW — one player across seasons
        ├── gameform.js            # NEW — context, notes, historical entry
        ├── roster.js              # edits the active season's membership
        ├── track.js               # + match result on End Match
        └── stats.js               # + context and notes on each game

tests/
├── fixtures/
│   ├── v1-log.json                # committed
│   └── v2-log.json                # NEW — captured from the live build before v3 code exists
└── unit/ · integration/           # + season, career, historical, import, migration suites
```

**Structure Decision**: unchanged — three layers, `ui → state → domain`, one direction.

Two new modules earn their place. `src/state/historical-import.js` parses the batch file and returns events without dispatching, so its rules are testable in Node. It is deliberately separate from `backup.js`: that file **replaces** everything and carries an event log, this one **adds** games and carries figures — different verbs, different shapes, no shared parsing.

`src/ui/screens/gameform.js` holds context, notes, and historical entry together because all three are the same thing: editing a game's record outside a rally.

## Phase Outputs

| Phase | Artifact | Status |
|---|---|---|
| 0 | `research.md` — 8 decisions | ✅ |
| 1 | `data-model.md`, `contracts/domain-api.md`, `quickstart.md` | ✅ |
| 1 | Agent context (`CLAUDE.md` SPECKIT block) | Pending |
| 2 | `tasks.md` | Pending `/speckit-tasks` |

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| **Article V** — integration tests do not use testcontainers | Carried forward and unchanged: no server, database, or network exists to containerise. The real integration surfaces are `localStorage`, the service worker, and the file system. The adapter is tested against a **real** `Storage`, and the migration against **two real log fixtures**. | Containerising a backend-free app tests nothing that exists. Mocking `localStorage` is the mocked driver the Article forbids. This release narrows the gap further by adding a second fixture, so the chain is proven from both real starting points rather than the oldest. |
| **Article VII** — a custom import parser rather than a schema library | The file is read by a person transcribing handwriting, so the failure modes that matter are semantic — an unknown player name, a negative count — not structural. A schema validator would accept a file naming a tenth player on a nine-player squad. | A validation library would be the app's first runtime dependency, and would still leave the checks that actually protect the data to be written by hand. The parser is a few dozen lines and returns reasons in the operator's language. |
| **New: `ADD_PLAYER` now means two things** | It creates the person when new *and* adds them to a season with a number. The alternative — decomposing it into two events during migration — shifts every event index in the only real season recorded, turning any bug into silent corruption. | Decomposition is the cleaner model and the riskier migration. The compound meaning is what the operator's action already means, so the event is honest; only its name is now slightly narrow. Renaming it would itself be a migration, for cosmetics. |
