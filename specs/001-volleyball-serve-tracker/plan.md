# Implementation Plan: Volleyball Serve Tracker

**Branch**: `feature/volleyball-serve-tracker` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-volleyball-serve-tracker/spec.md`

## Summary

An offline-first, installable web app for recording volleyball serve outcomes courtside on an iPhone, reporting serving performance per turn, per match, and per game.

The technical approach is deliberately narrow: **plain ES modules served as static files, with no bundler, no framework, and no backend.** State is an append-only event log reduced by a pure function; statistics are derived on read and never stored. Undo is `pop the last event and replay`, which makes the strictest requirement in the spec — restore every statistic *and* every turn boundary exactly (`FR-041`, `FR-042`) — a structural property rather than something defended by test coverage.

Offline is treated as a correctness requirement, not a fallback. A hand-written service worker precaches an explicit file list and serves cache-first, so after install the app makes no network requests at all (`FR-055`). The proof of that claim is a full three-match game played on the device in airplane mode, not a green test suite.

## Technical Context

**Language/Version**: JavaScript (ES2022 modules), no transpilation

**Primary Dependencies**: **None at runtime.** Development only: Vitest (unit + persistence), Cypress with `cypress-real-events` (UX)

**Storage**: `localStorage` — a single versioned key holding the serialized event log, behind one swappable adapter module

**Testing**: Vitest for the pure domain and the persistence adapter; Cypress with real pointer events for the tap loop; on-device airplane-mode run for offline and install claims

**Target Platform**: iOS Safari 16.4+, installed to the Home Screen as a standalone PWA. Portrait phone only.

**Project Type**: Single static web application — mobile-first PWA, no server component

**Performance Goals**: A tap is reflected within one frame (~16 ms). A full event-log replay stays under 1 ms at end-of-game volume.

**Constraints**: Zero network requests after install. All data local. Portrait only. Every control ≥ 44 pt, outcome controls in the thumb zone. No hover, keyboard, or pointer-precision dependency. Safe-area aware. WCAG AA contrast under gymnasium lighting.

**Scale/Scope**: 1 operator, 1 device, ≤ 20 players, 3 matches per game, a few hundred serves per game. 3 screens.

## Constitution Check

*GATE: evaluated before Phase 0 and re-evaluated after Phase 1 design. Both passes recorded.*

| Article | Gate | Pre-Phase 0 | Post-Phase 1 |
|---|---|---|---|
| **I** — Prime Directive | Best route, not fastest | ✅ Event sourcing chosen for correctness under undo, not for speed of delivery. The no-bundler decision is argued on auditability of the offline precache list (research R-001), not on saving setup time. | ✅ Holds. |
| **II** — Process Protection | No wildcard process kills | ✅ N/A — no process management in this feature. | ✅ N/A |
| **III** — Branching | Feature branch, PR to main | ✅ On `feature/volleyball-serve-tracker`. No direct commit to `main`. | ✅ Holds. |
| **IV** — Code Quality | Self-documenting names, file purpose comments, doc comments on exports, functions < 40 lines, guard clauses | ✅ Binding on implementation. The layer split keeps functions small by construction. | ✅ Every module in the structure below has a single responsibility; no function in the contracts exceeds a screen. |
| **V** — Testing | Three layers, Red→Green→Refactor | ⚠️ Deviation — see Complexity Tracking. | ⚠️ Deviation stands, justified and scoped. |
| **VI** — Documentation | `CHANGELOG.md` is the source of truth; no auxiliary status docs | ✅ `CHANGELOG.md` updated in the implementation PR. Artifacts here are Spec Kit pipeline output, explicitly exempt. | ✅ Holds. |
| **VII** — Framework-First | Confirm the framework does not already provide it | ✅ The governing framework is the web platform. Service Worker, Web App Manifest, and `localStorage` are used as provided rather than wrapped. | ✅ The only custom infrastructure is a ~60-line reducer store — justified in Complexity Tracking. |
| **VIII** — Release | Local pipeline only, never GitHub Actions | ✅ No build step exists. Deployment is a branch push to GitHub Pages; no workflow is authored. | ✅ Holds. |
| **IX** — Vault | Secrets injected, never handled | ✅ N/A — no secrets, no credentials, no API keys. The app has no network surface. | ✅ N/A |
| **X** — Verification | Evidence, not "it compiles" | ✅ The stated proof is a full game played on-device in airplane mode with the Network panel showing zero requests (`quickstart.md` V-7). | ✅ Eight numbered validation scenarios, each mapped to requirements. |
| **XI** — Output Restraint | ≤ 1 dashboard, no unrequested summaries | ✅ No dashboard. No auxiliary docs beyond pipeline artifacts. | ✅ Holds. |
| **XII** — Response Format | Tight, scannable, emoji headers | ✅ Applies to conversation, not artifacts. | ✅ N/A |

**Gate result**: **PASS**, with one declared and justified deviation (Article V integration layer).

## Project Structure

### Documentation (this feature)

```text
specs/001-volleyball-serve-tracker/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 — 10 resolved decisions
├── data-model.md        # Phase 1 — event log, derived state, statistics
├── quickstart.md        # Phase 1 — 8 validation scenarios + deploy
├── contracts/
│   ├── domain-api.md    # Pure module surface and guarantees
│   └── ui-interaction.md# Screen layout and interaction rules
├── checklists/
│   └── requirements.md  # Spec quality validation
└── tasks.md             # Phase 2 output (/speckit-tasks — not created here)
```

### Source Code (repository root)

The repository root **is** the deployed artifact. There is no build output directory, because there is no build.

```text
index.html                    # Single entry point; all three screens
manifest.webmanifest          # display: standalone, orientation: portrait
sw.js                         # Hand-written service worker, cache-first precache
styles/
└── app.css                   # Safe areas, thumb zone, touch suppression, palette

icons/
├── icon-192.png
├── icon-512.png
└── apple-touch-icon.png      # iOS ignores manifest icons for Home Screen

src/
├── domain/                   # PURE. No DOM, no storage, no clock, no randomness.
│   ├── events.js             # Event constructors and outcome constants
│   ├── reducer.js            # applyEvent / replay — every rule in the spec
│   ├── stats.js              # Derived statistics at turn, match, game scope
│   └── palette.js            # Turn colour assignment
├── state/                    # Stateful, but thin.
│   ├── store.js              # Event log, dispatch, undo, subscribe
│   └── persistence.js        # The ONLY module that touches localStorage
└── ui/
    ├── app.js                # Bootstrap, service worker registration, routing
    ├── screens/
    │   ├── roster.js
    │   ├── track.js          # The match-long screen
    │   └── stats.js
    └── components/
        └── tally.js          # Tally marks, turn grouping, over-limit flag

tests/
├── unit/                     # Vitest — pure domain, < 10 ms each
│   ├── reducer.test.js
│   ├── stats.test.js
│   ├── palette.test.js
│   └── undo.test.js
├── integration/
│   └── persistence.test.js   # Real localStorage, no mocked driver
└── ux/
    └── track.cy.js           # Cypress + cypress-real-events

scripts/
└── run-dev-clean.ps1         # Clean dev server launch (Article V)

package.json                  # devDependencies ONLY — nothing ships
vitest.config.js
cypress.config.js
```

**Structure Decision**: Single static web application, laid out as three layers with a one-directional import rule: `ui → state → domain`.

The split is not decoration. `src/domain/` is pure by contract, which is precisely what makes the Article V unit layer possible — every rule in the spec is testable without a DOM, a browser, or a clock. A rule appearing in `src/ui/` is a defect by definition, because it cannot be unit-tested and will drift from the reducer. `src/state/persistence.js` is the sole point of contact with `localStorage`, so the storage decision in research R-005 can be revisited later by editing one file.

Files sit at the repository root rather than in a `dist/` or `public/` directory so that what is committed is exactly what is served. That is what makes the service worker's precache list auditable by reading it.

## Phase Outputs

| Phase | Artifact | Status |
|---|---|---|
| 0 | `research.md` — 10 decisions, all `NEEDS CLARIFICATION` resolved | ✅ Complete |
| 1 | `data-model.md` — event log, derived state, statistics, undo, persistence | ✅ Complete |
| 1 | `contracts/domain-api.md` — module surface with per-function guarantees | ✅ Complete |
| 1 | `contracts/ui-interaction.md` — screens, interaction contract, platform rules | ✅ Complete |
| 1 | `quickstart.md` — 8 validation scenarios, deploy path, definition of done | ✅ Complete |
| 1 | Agent context (`CLAUDE.md` SPECKIT block) | ✅ Updated |
| 2 | `tasks.md` | Pending `/speckit-tasks` |

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| **Article V** — integration tests do not use testcontainers | The application has no infrastructure to containerise: no server, no database, no network, no external service. Its only genuine integration surfaces are `localStorage` and the service worker, both browser primitives. The persistence adapter is therefore tested against a **real** storage implementation (never a mocked driver, which is the rule the Article actually protects), and service-worker offline behaviour is verified on the device in airplane mode — the only environment where it is real. | Standing up a container to test a feature with no backend would test nothing that exists. Mocking `localStorage` was rejected outright: it is exactly the "mocked driver" the Article forbids. Declaring the offline claim proven by a green unit suite was rejected under Article X — the on-device airplane-mode run in `quickstart.md` V-7 is the required evidence. |
| **Article VII** — a custom ~60-line reducer store rather than a state library | No framework governs this project; it is plain ES modules on the web platform, and the platform provides no state-management primitive. The store exists to satisfy `FR-041`/`FR-042`, which demand that undo restore every derived statistic *and* every turn boundary exactly. | Redux, Zustand, and XState were each considered (research R-002). Every one is heavier than the code it would replace and would be the project's first runtime dependency — against the Article's own test, since there is no documented gap they close. A snapshot-stack undo was also rejected: it stores N copies of the whole state and still needs bespoke logic to stop an empty turn being resurrected. |
