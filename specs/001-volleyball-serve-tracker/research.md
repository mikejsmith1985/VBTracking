# Phase 0 Research: Volleyball Serve Tracker

**Feature**: `001-volleyball-serve-tracker` | **Date**: 2026-08-29

All `NEEDS CLARIFICATION` items from Technical Context are resolved below.

---

## R-001: Application shell — build tooling

**Decision**: Plain ES modules served as static files. **No bundler for the shipped app.** Vite, webpack, and friends are not used.

**Rationale**: The deployed artifact is the source. That is worth more here than any developer-experience gain, for three reasons specific to this feature:

1. **Offline correctness is auditable.** The service worker precaches an explicit list of files. With no bundler, that list is the actual file tree — a human can read it and confirm nothing is missing. With hashed bundle output, the precache list is generated, and a stale or wrong manifest is an offline failure that only reproduces on a phone in airplane mode.
2. **No build-time version risk.** A bundler plus a service-worker plugin is two more dependencies whose interaction is the single most common source of "works in dev, broken when installed" PWA bugs.
3. **Deployment is `git push`.** No build step means no build artifacts to keep in sync with source, and no CI to author (Article VIII).

**Alternatives considered**:

| Option | Rejected because |
|---|---|
| Vite + React + `vite-plugin-pwa` | Adds ~3 dependencies, a build step, and a generated service worker for an app with one state machine and three screens. The generated Workbox SW is harder to verify than the 40 lines it replaces. |
| Vite + vanilla | Keeps the build-step and precache-manifest risk without buying a component model. |
| Single self-contained HTML file | Would work, but collapses the domain logic into the view layer and makes the pure-function unit tests required by Article V impossible to isolate. |

**Consequence**: ES module `import` paths must be relative and extension-explicit (`./stats.js`, not `./stats`), because there is no resolver.

---

## R-002: State and undo model

**Decision**: **Append-only event log with a pure reducer.** Application state is never mutated in place; it is always `events.reduce(applyEvent, emptyState())`. Undo pops the last event and replays.

**Rationale**: Undo is the requirement that makes this choice obvious rather than merely tidy. `FR-041` demands that undo restore *every* derived statistic **and** every serve-turn boundary to its exact prior state, and `FR-042` demands that a turn left empty by an undo disappear entirely.

Under a mutate-in-place model, each of those is hand-written inverse logic per action type, and each is a place to introduce a bug that only shows up as a wrong stat three matches later. Under replay, undo is `events.pop()` — correctness is structural, not defended by test coverage. Empty turns cannot survive because the reducer never creates one on the way through.

Replaying the entire log on every tap is free at this scale: a full three-match game is a few hundred events, so a replay is microseconds.

**Secondary benefits** (not the reason, but they fall out):
- `FR-057` crash recovery: persist the event log, replay on boot. Nothing else to serialize.
- "Statistics are always derived" (spec Assumptions): stats read from replayed state and cannot drift.

**Alternatives considered**:

| Option | Rejected because |
|---|---|
| Snapshot stack (deep-clone state before each action) | Works, but stores N copies of the whole state and still needs bespoke handling to avoid resurrecting an empty turn. Strictly more memory and more code for less guarantee. |
| Mutable state + per-action inverse (`undoRecordServe`, …) | Every new action type adds a matching inverse that must stay correct forever. This is the failure mode `FR-041` is written to prevent. |
| Redux / Zustand / XState | The reducer is roughly 60 lines. Article VII: a dependency must close a documented gap, and there is none. |

---

## R-003: Serve turn boundary detection

**Decision**: A turn closes when a serve's outcome is anything other than `IN_POINT`, or when a different player is selected as server. No manual "end turn" control is required.

**Rationale**: Under rally scoring every lost rally surrenders the serve, so "did not earn a point" and "turn is over" are the same event. This is what lets the operator record a complete side-out in two taps (`SC-001`) instead of three — the turn boundary is inferred, never typed.

**Consequence worth naming**: every closed turn therefore ends with exactly one non-point serve, so a turn of *N* serves represents *N−1* points and one side-out. The single exception is a turn closed by `END_MATCH` or by a player switch, which may end on a point. The reducer must handle that case rather than assuming the last serve is always a loss.

---

## R-004: Serve-turn colour assignment

**Decision**: `colorIndex = turnOrdinalWithinMatch % PALETTE.length`, with a palette of 6 colours.

**Rationale**: Satisfies `FR-033` (no two consecutive turns share a colour) by construction for any palette longer than one, needs no lookback, and survives replay deterministically — a turn's colour never changes because of something that happened later.

Six colours means a player's two turns in a match collide only if those turns are exactly six apart, which is both rare and harmless since they are visually far apart.

**Accessibility** (`FR-034`): colour encodes the *turn*, never the *outcome*. Outcomes are distinguished by mark shape — a full stroke for a point, a hollow stroke for in-no-point, a struck-through stroke for out — so the display is fully readable without colour vision.

---

## R-005: Local persistence

**Decision**: `localStorage`, holding the serialized event log under a single versioned key. `navigator.storage.persist()` is requested opportunistically at startup.

**Rationale**: The synchronous API is the deciding factor, not the simplicity. Every tap writes. An async write on a rapid-tap path introduces interleaving between a tap and its persistence that has to be reasoned about; a synchronous write cannot interleave at all. For a workload this size that is a correctness win with no cost.

Volume is not close to a constraint: a full game is a few hundred events, well under 100 KB against a 5 MB budget.

**Eviction risk, acknowledged**: Safari may evict site data after seven days of disuse. Home-Screen-installed web apps are exempt from that policy, and this app is installed by definition (`FR-053`), so the exposure is limited to the pre-install browsing case. `navigator.storage.persist()` further reduces it.

**Alternatives considered**:

| Option | Rejected because |
|---|---|
| IndexedDB | Better durability story, but every write becomes async on the hot path for data that is three orders of magnitude below `localStorage`'s limit. Reconsider only if history retention across many games is added later. |
| In-memory only | Violates `FR-057`. |

**Containment**: all storage access lives behind one module (`src/state/persistence.js`). Swapping to IndexedDB later touches that file and nothing else.

---

## R-006: Service worker strategy

**Decision**: Hand-written service worker, ~40 lines. Cache-first against an explicit precache list, with a versioned cache name and cleanup of old caches on `activate`.

**Rationale**: `FR-055` forbids network requests during normal operation after install. That is a stricter contract than a typical PWA's "network-first with offline fallback", and it is easier to *guarantee* than to configure: serve from cache, and do not reach for the network on a cache hit at all.

Cache versioning is by a constant bumped on release, so a new version fully replaces the old rather than serving a mix of both.

**Alternatives considered**: Workbox — rejected under Article VII. It exists to manage routing strategies, expiration, and background sync. This app has one strategy, no expiration, and no sync.

---

## R-007: iOS standalone and touch behaviour

**Decision**: A specific set of platform declarations, each mapped to the requirement it satisfies.

| Mechanism | Satisfies |
|---|---|
| `manifest.webmanifest` with `display: standalone`, `orientation: portrait` | `FR-045`, `FR-053` |
| `<link rel="apple-touch-icon">` | `FR-053` — iOS ignores manifest icons when adding to the Home Screen |
| `<meta name="apple-mobile-web-app-capable" content="yes">` | `FR-053` on iOS below 16.4, which does not honour manifest `display` |
| `viewport-fit=cover` + `env(safe-area-inset-*)` in CSS | `FR-051` |
| `user-scalable=no, maximum-scale=1` | `FR-049` |
| `touch-action: manipulation` on interactive elements | `FR-049` — removes the 300 ms double-tap-zoom wait |
| `overscroll-behavior: none` on the scroll container | `FR-049` — suppresses pull-to-refresh and rubber-banding |
| `-webkit-tap-highlight-color: transparent` + explicit `:active` states | Tap feedback the operator can see in peripheral vision |
| `user-select: none` on controls | Prevents a held tap raising the iOS text-selection callout |

**Note**: iOS honours `orientation: portrait` from the manifest only in a Home-Screen-installed context. In a browser tab the app is still usable but may rotate. This is acceptable — the installed context is the supported one.

---

## R-008: Hosting and install path

**Decision**: **GitHub Pages**, serving the repository root of a dedicated branch over HTTPS. All asset paths are **relative**, never root-absolute.

**Rationale**: A service worker requires a secure origin, so `file://` and plain-HTTP LAN serving are both out — the app cannot be installed or work offline without HTTPS. GitHub Pages provides it free, needs no account beyond the one already in use, and deploys by pushing a branch.

The relative-path rule is load-bearing: Pages serves project sites from a subpath (`/VBTracking/`), so any root-absolute reference (`/sw.js`, `/icons/…`) would 404 and silently break both install and offline. Relative paths make the app work unchanged at any base path, including a later move to a custom domain.

**Article VIII compliance**: no GitHub Actions workflow is authored. Pages branch serving is GitHub's own hosting, not a release pipeline of ours. There is no build to run.

**Fallback if Pages is unavailable or too slow to propagate**: `netlify deploy --prod --dir=.` from the CLI. Same static files, no configuration change needed, because the paths are relative.

---

## R-009: Match score display and the two-point margin

**Decision**: The match score shown is **points earned on serve**. The target indicator (`FR-011`) triggers when that figure reaches 21. Match end stays a manual action (`FR-010`).

**Rationale**: `FR-014` excludes the opponent's score, so the app cannot compute a two-point margin — the information required is not in the system. Rather than invent a number, the app displays only what it actually measured and labels it honestly, and the operator ends the match by reading the real scoreboard.

This limitation was raised with the stakeholder before planning and explicitly accepted. It is recorded in the spec under Assumptions → *Match score visibility*.

**Alternative available on request**: adding a single opponent-score stepper would make the score complete and the two-point margin automatic. It was deliberately left out of scope to keep the recording loop to two taps.

---

## R-010: Testing approach against Article V

**Decision**: Three layers, with the middle layer scoped honestly to what this app actually has.

| Layer | Tooling | Covers |
|---|---|---|
| Unit | Vitest, `src/domain/**` | Reducer, turn boundaries, statistics, palette, undo. Pure functions, zero DOM, zero storage, well under 10 ms. |
| Integration | Vitest, real `localStorage` via jsdom | The persistence adapter against a real storage implementation — no mocked driver. |
| UX | Cypress + `cypress-real-events` | The tap loop, undo, roster editing, with real pointer events. |

**Deviation, declared**: Article V specifies testcontainers-backed integration tests. This application has no infrastructure to containerise — no server, no database, no network. The genuine integration surfaces are `localStorage` and the service worker, both browser primitives. The persistence adapter is therefore tested against a real (not mocked) storage implementation, and **service-worker offline behaviour is verified on the device in airplane mode**, which is the only environment where it is real. That on-device run is the Article X proof for this feature; a green unit suite is explicitly not accepted as evidence that the app works offline.

Vitest and Cypress are development dependencies only and are never part of the deployed artifact, which remains dependency-free.
