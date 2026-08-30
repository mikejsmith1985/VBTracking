---

description: "Task list for the native iOS app and its watchOS companion"
---

# Tasks: Native iOS App with a watchOS Companion

**Input**: Design documents from `specs/004-native-ios-and-watch/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Test tasks are included and are not optional here. Article V of the constitution requires red → green → refactor, and the port has no other way of being trusted — the parity suite is the whole argument that a season's figures did not change when the language did.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on unfinished work)
- **[Story]**: The user story the task serves (US1–US7)
- Every task names the file it touches

## Path Conventions

- `packages/VBCore/` — the pure domain. **Builds and tests on this Windows workstation.**
- `ios/` — the two apps. Needs the cloud build service; nothing here runs locally.
- `tests/fixtures/` — existing golden files, reused unchanged.
- The shipped web app stays in the repository root and is not touched by any task below.

## Order of the P1 stories

US1, US2 and US3 are all P1. They are phased below in build order rather than in story order, because the wrist court has nothing to draw until the phone can record and the season has arrived. The plan's delivery order is followed: the domain, then the log and the import (US2), then the tracking loop (US3), then the court on the wrist (US1).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: The two build environments — the local Swift loop, and the cloud one.

- [X] T001 Install the Swift toolchain for Windows and record the exact version in `specs/004-native-ios-and-watch/quickstart.md` — **Swift 6.3.3**, plus Visual Studio Build Tools for the MSVC linker, wrapped by `scripts/swift-env.ps1`
- [X] T002 Create the package manifest with a `VBCore` library target and a `VBCoreTests` test target in `packages/VBCore/Package.swift`, using swift-testing and Swift 6 strict concurrency
- [X] T003 Make `tests/fixtures/` readable from a test without depending on the working directory — **done by reading them where they live**, from a path derived from the test's own source location, rather than as a resource bundle. A copy inside the target would be a second copy of files that must never drift
- [X] T004 [P] Declare the three targets — iOS app, watchOS app, shared link — with the App Group `group.com.mikejsmith.vbtracker` and bundle ids `com.mikejsmith.vbtracker` and `com.mikejsmith.vbtracker.watchapp` in `ios/project.yml`
- [X] T005 [P] Add the Codemagic workflow — XcodeGen generate, `swift test` for `VBCore`, build both targets, run the interface suite, publish to TestFlight — in `codemagic.yaml`, taking the App Store Connect key from the vault names `APPLE_ASC_KEY_ID`, `APPLE_ASC_ISSUER_ID`, `APPLE_ASC_PRIVATE_KEY`, `APPLE_TEAM_ID`
- [X] T006 [P] Add Swift build artefacts, generated Xcode projects and `DerivedData` to `.gitignore`
- [X] T007 [P] Add a swift-format configuration matching the web app's conventions — self-documenting names, no abbreviations — in `.swift-format`
- [ ] T008 **Operator task**: create the App ID and the App Store Connect record, upload the `.p8` once through the Codemagic web UI (the vault cannot do this step), and record the numeric `APP_ID` in `CLAUDE.md`

**Checkpoint**: `swift test` runs locally — **done, 117 tests in 0.02s**. A Codemagic build reaching the signing step waits on T008.

---

## Phase 2: Foundational — the rulebook, ported and proved

**Purpose**: `VBCore`. Every user story depends on it, and none of it needs a Mac. This is the largest phase and the only one with a fast loop.

**⚠️ BLOCKING**: no user story starts until T027 is green.

### The event model

- [X] T009 Write failing tests for event encoding and decoding against the shapes in `specs/004-native-ios-and-watch/contracts/event-log.md`, including the additive `id` field and unknown-field tolerance, in `packages/VBCore/Tests/VBCoreTests/EventCodecTests.swift`
- [X] T010 Implement the event type, its cases, and its JSON codec in `packages/VBCore/Sources/VBCore/Events.swift`
- [X] T011 [P] Implement the constants — `OUTCOME`, `MATCH_RESULT`, `GAME_KIND`, `MAX_ROSTER`, `MATCHES_PER_GAME`, `LINEUP_SIZE`, `SERVE_LIMIT`, `DEFAULT_FORMAT` — in `packages/VBCore/Sources/VBCore/Events.swift`
- [X] T012 [P] Implement event identity — assigned once at creation, never regenerated — in `packages/VBCore/Sources/VBCore/Events.swift`

### The reducer

- [X] T013 Write failing tests for roster rules, the game and match lifecycle, and serve-turn boundaries — ported from `tests/unit/reducer.test.js` — in `packages/VBCore/Tests/VBCoreTests/ReducerTests.swift`
- [X] T014 Implement `replay(events)` and the state shape in `packages/VBCore/Sources/VBCore/Reducer.swift`
- [X] T015 Implement the rejection rules, returning a reason rather than throwing, in `packages/VBCore/Sources/VBCore/Reducer.swift`
- [X] T016 [P] Write failing tests for the lineup, auto-advancing rotation and substitution — ported from `tests/unit/rotation.test.js` and `substitution.test.js` — in `packages/VBCore/Tests/VBCoreTests/RotationTests.swift`
- [X] T017 Implement the lineup, the rotation advance **inside** the serve transition, and substitution taking the outgoing player's exact slot in `packages/VBCore/Sources/VBCore/Reducer.swift`
- [X] T018 [P] Write failing tests for the corrections — set serves, reassign, delete, insert — ported from `tests/unit/corrections.test.js`, including that an inserted turn takes no rotation position, in `packages/VBCore/Tests/VBCoreTests/CorrectionTests.swift`
- [X] T019 Implement the four correction transitions and contiguous renumbering in `packages/VBCore/Sources/VBCore/Reducer.swift`

### Statistics, derived on read

- [X] T020 [P] Write failing tests asserting that a figure never recorded is null and never zero — ported from `tests/unit/stats.test.js` and `aggregate.test.js` — in `packages/VBCore/Tests/VBCoreTests/StatisticsTests.swift`
- [X] T021 Implement turn, match and game statistics in `packages/VBCore/Sources/VBCore/Statistics.swift`
- [X] T022 Implement season, career and game-summary aggregation, with coverage labelling for games copied from paper, in `packages/VBCore/Sources/VBCore/Aggregate.swift`

### Migrations

- [X] T023 [P] Write failing tests for the ordered migration chain — ported from `tests/unit/migrations.test.js` — in `packages/VBCore/Tests/VBCoreTests/MigrationTests.swift`
- [X] T024 Implement the additive migration chain (v1→v2→v3) and the schema version in `packages/VBCore/Sources/VBCore/Migrations.swift`

### Court geometry

- [X] T025 [P] Write failing tests for the court — bottom-right serves, clockwise rotation, on-deck at top-right, wrap-around, empty positions — ported from `tests/unit/court.test.js` — in `packages/VBCore/Tests/VBCoreTests/CourtTests.swift`
- [X] T026 Implement the court view model — positions, serving position, on-deck position, per-position figures with nulls intact — in `packages/VBCore/Sources/VBCore/Court.swift`

### The proof

- [X] T027 Write the parity suite: replay `tests/fixtures/v1-log.json` and `v2-log.json` through the Swift reducer and assert every figure equals `v1-expected.json` and `v2-expected.json`, in `packages/VBCore/Tests/VBCoreTests/ParityTests.swift`
- [X] T028 Export the operator's real season from the shipped web app, commit it as `tests/fixtures/season-2026.json`, and assert in `ParityTests` that every per-player, per-match, per-game and per-season figure matches the web app's — **including which figures are dashes**

**Checkpoint**: **done.** `swift test` is green — 167 tests — and the two shipped fixtures
*and the operator's own season* replay to identical figures, dashes included. `VBCore` has
no I/O, no clock and no randomness. Phase 2 is closed; the user stories are unblocked.

---

## Phase 3: US2 — The season already recorded comes across intact (P1)

**Goal**: The operator's real season is on the phone, unchanged.

**Independent test**: Import the web app's backup and compare every figure against the browser, side by side.

- [X] T029 [P] [US2] Write failing tests for the append-only log file — one complete line per event, a partial trailing line discarded on read, undo truncating the last line — in `packages/VBCore/Tests/VBCoreTests/LogFileTests.swift`
- [X] T030 [US2] Implement the JSON-Lines log store against the contract in `contracts/event-log.md` — **in a new `VBStore` target**, not in `VBCore`. The domain promises to have no I/O in it, and putting a file handle there would have broken that promise on the first day. `VBStore` still tests locally
- [X] T031 [P] [US2] Write failing tests for reading the backup file — wrong marker, unreadable JSON, no events, a newer schema — each returning a reason and changing nothing, in `packages/VBCore/Tests/VBCoreTests/TransferTests.swift`
- [X] T032 [US2] Implement backup parsing, the migration run, and deterministic `id` assignment for events that lack one, in `packages/VBCore/Sources/VBCore/Transfer.swift`
- [X] T033 [US2] Implement import idempotence — hash the imported log, refuse a hash already recorded — in `packages/VBCore/Sources/VBCore/Transfer.swift`
- [X] T034 [US2] Implement export in the web app's exact shape, and add a round-trip test proving a natively written file parses in the web app's parser, in `packages/VBCore/Sources/VBCore/Transfer.swift`
- [X] T035 [US2] Wire the log store into the app's store, replaying on launch and appending on every accepted event, in `ios/VBTracker/App/EventStore.swift`
- [X] T036 [US2] Build the import screen — choose a file, state plainly what will happen before it happens, report the outcome in one sentence — in `ios/VBTracker/Transfer/ImportView.swift`
- [X] T037 [P] [US2] Build the export screen, offering the file through the share sheet, in `ios/VBTracker/Transfer/ExportView.swift`
- [X] T038 [US2] Add an interface test that imports a fixture backup and asserts the season figures on screen, in `ios/VBTrackerUITests/ImportTests.swift`

**Checkpoint**: the rules of the log and the import are done and tested — **157 tests, 0.04
seconds**, including a whole season surviving a round trip through this app's own export.
T035–T038 are the app-side wiring: they are held with the rest of the UI and built as one
batch on the cloud service, per R-001. The real season lands on the phone at the end of that
batch, and FR-036 is satisfied then.

---

## Phase 4: US3 — The tracker records a match on the phone (P1)

**Goal**: One tap per serve, the rotation advancing itself, undo reversing one action.

**Independent test**: Track a full three-match game with no internet — Wi-Fi and cellular off — against a paper tally.

- [X] T039 [US3] Build the observable store — dispatch, rejection reasons surfaced, undo dropping the last event and replaying — in `ios/VBTracker/App/Store.swift`
- [X] T040 [P] [US3] Build the roster screen: add, edit, remove from season, in `ios/VBTracker/Track/RosterView.swift`
- [X] T041 [P] [US3] Build the lineup chooser for the six on court, in `ios/VBTracker/Track/LineupView.swift`
- [X] T042 [US3] Build the court picker on the phone — the same arrangement the wrist uses, driven by `VBCore.Court` — in `ios/VBTracker/Track/CourtPicker.swift`
- [X] T043 [US3] Build the outcome controls in the thumb zone, one tap per serve, with the repeat-tap guard, in `ios/VBTracker/Track/OutcomeControls.swift`
- [X] T044 [US3] Build the tally board — one mark per serve, grouped and coloured by turn, outcome carried by shape not colour — in `ios/VBTracker/Track/TallyBoard.swift`
- [X] T045 [US3] Implement bench-first substitution: tap the incoming player, then tap who they replace, in `ios/VBTracker/Track/CourtPicker.swift`
- [X] T046 [US3] Implement the five-serve alert as a full-screen interruption cleared by any tap, in `ios/VBTracker/Track/ServeLimitAlert.swift`
- [X] T047 [P] [US3] Build ending a match with its result, and ending a game part-way, in `ios/VBTracker/Track/EndMatchView.swift`
- [X] T048 [US3] Add an interface test tracking a whole match through real taps and asserting the recorded figures, in `ios/VBTrackerUITests/TrackingTests.swift`
- [X] T049 [US3] Add an interface test asserting one undo reverses exactly one operator action, including the rotation advance it caused, in `ios/VBTrackerUITests/UndoTests.swift`

**Checkpoint**: a game can be tracked start to finish with no network and no watch.

---

## Phase 5: US1 — The coach reads the court from her wrist (P1)

**Goal**: Six boxes as the court, the on-deck box the biggest thing on the screen.

**Independent test**: Drive the watch view from a fixture snapshot — no phone, no link — and read it at arm's length.

- [X] T050 [P] [US1] Write failing tests for the snapshot codec against `contracts/watch-link.md`, including nulls surviving as nulls, in `ios/SharedTests/CourtSnapshotTests.swift`
- [X] T051 [US1] Implement the court snapshot type, encoded from `VBCore.Court`, in `ios/Shared/Link/CourtSnapshot.swift`
- [X] T052 [US1] Build the court grid with uneven tracks — columns 1 : 1 : 1.35, rows 1.25 : 1 — sized for the 42 mm screen, in `ios/VBTrackerWatch/CourtView/CourtGrid.swift`
- [X] T053 [US1] Build the box: jersey number primary at ~46 pt on deck and ~32 pt elsewhere, serve-in percentage second, points third, in `ios/VBTrackerWatch/CourtView/PlayerBox.swift`
- [X] T054 [US1] Render a figure that was never recorded as a dash, never as zero and never as a full percentage, in `ios/VBTrackerWatch/CourtView/PlayerBox.swift`
- [X] T055 [P] [US1] Render an empty court position as empty, and say plainly when there is no lineup to name a next server from, in `ios/VBTrackerWatch/CourtView/CourtGrid.swift`
- [X] T056 [US1] Show the scope the figures cover — which match or game — so one cannot be mistaken for the other, in `ios/VBTrackerWatch/CourtView/ScopeLabel.swift`
- [X] T057 [US1] Make the layout legible in the always-on display, with nothing carried by colour alone, in `ios/VBTrackerWatch/CourtView/CourtGrid.swift`
- [X] T058 [US1] Add the interface test that **measures** every box frame and asserts the on-deck box is at least 1.5× the smallest by area on the 42 mm screen (SC-014), in `ios/VBTrackerWatchUITests/CourtLayoutTests.swift`
- [X] T059 [US1] Add an interface test driving the view from three fixture snapshots — full court, five on court, no lineup — in `ios/VBTrackerWatchUITests/CourtContentTests.swift`

**Checkpoint**: the wrist court reads correctly from fixture data, and its layout is asserted by measurement rather than by an eye that cannot open a simulator.

---

## Phase 6: US6 — The watch and the phone stay in step (P2)

**Goal**: What the phone records reaches the wrist, and staleness is stated plainly.

**Independent test**: Record on the phone and watch the wrist follow; separate the devices and confirm the watch marks itself not current.

- [X] T060 [US6] Define the connectivity protocol and its fake, so every rule below is testable without two devices, in `ios/Shared/Link/ConnectivitySession.swift`
- [X] T061 [P] [US6] Write failing tests for snapshot ordering — sequence 5 then 4, and 5 wins — in `ios/SharedTests/LinkTests.swift`
- [X] T062 [US6] Implement sending the snapshot: `updateApplicationContext` always, plus `sendMessage` while reachable, in `ios/VBTracker/App/PhoneLink.swift`
- [X] T063 [US6] Implement receiving on the watch, discarding anything not newer than what is held, in `ios/VBTrackerWatch/Link/WatchLink.swift`
- [X] T064 [US6] Send a snapshot after every event that changes the court, substitutions included, in `ios/VBTracker/App/PhoneLink.swift`
- [X] T065 [US6] Show how long ago the court was current, and mark it not-current past the threshold, in `ios/VBTrackerWatch/CourtView/StalenessBanner.swift`
- [X] T066 [P] [US6] Add tests for losing contact and recovering — the fake drops everything, then reconnects and flushes — in `ios/SharedTests/LinkTests.swift`
- [ ] T067 [US6] Verify on the real devices that a serve reaches the wrist within 3 seconds (SC-002), and record the result in `CHANGELOG.md`

**Checkpoint**: the wrist follows the phone, and never lies about how current it is.

---

## Phase 7: US7 — The coach records from the wrist (P2)

**Goal**: Three buttons, one deliberate tap each, delivered exactly once.

**Independent test**: Put the phone down, record a whole turn from the watch, and compare the phone's record against one recorded on the phone.

- [X] T068 [US7] Build the record page — three outcome buttons, reached by a swipe from the court, never by a gesture or the crown — in `ios/VBTrackerWatch/RecordView/RecordView.swift`
- [X] T069 [US7] Send recorded events with `transferUserInfo`, keeping each until the phone confirms it, in `ios/VBTrackerWatch/Link/WatchLink.swift`
- [X] T070 [US7] Implement exactly-once on the phone: ignore an event `id` already held, in `ios/VBTracker/App/PhoneLink.swift`
- [X] T071 [P] [US7] Write failing tests delivering the same event twice and asserting the log holds it once, in `ios/SharedTests/LinkTests.swift`
- [X] T072 [US7] Show the count of serves not yet landed on the phone, so a serve recorded out of range is never assumed safe, in `ios/VBTrackerWatch/RecordView/PendingBadge.swift`
- [X] T073 [US7] Raise the five-serve limit as a haptic on the wrist as well as a visual, in `ios/VBTrackerWatch/RecordView/ServeLimitHaptic.swift`
- [X] T074 [US7] Add an interface test asserting a watch-recorded serve is indistinguishable in the log from a phone-recorded one, in `ios/VBTrackerWatchUITests/RecordTests.swift`
- [ ] T075 [US7] Wear the watch through an ordinary evening with no intent to record, and confirm nothing was recorded by accident (SC-011)

**Checkpoint**: phase one of the release is complete and ready for TestFlight.

---

## Phase 8: US4 — The record can still be corrected afterwards (P2, release phase two)

**Goal**: Any past game, serve by serve.

**Independent test**: Mis-enter a game deliberately, then correct every kind of mistake.

- [X] T076 [US4] Build the game list, opening any game in the season and not only the one being tracked, in `ios/VBTracker/Record/GameListView.swift`
- [X] T077 [US4] Build the serve record: every turn in order, with its serves, in `ios/VBTracker/Record/ServeRecordView.swift`
- [X] T078 [US4] Implement cycling a serve outcome, adding one, and removing the last, in `ios/VBTracker/Record/TurnEditor.swift`
- [X] T079 [P] [US4] Implement reassigning a turn and deleting one, each confirmed before it commits, in `ios/VBTracker/Record/TurnEditor.swift`
- [X] T080 [US4] Implement adding a turn missed at the time, at any point in the match, in `ios/VBTracker/Record/TurnEditor.swift`
- [X] T081 [US4] Add an interface test correcting each kind of mistake and asserting the season figures follow, in `ios/VBTrackerUITests/CorrectionTests.swift`

---

## Phase 9: US5 — The rest of the season is all still there (P2, release phase two)

**Goal**: Parity. Every screen of the web app has a counterpart.

**Independent test**: Walk every web-app screen and find its counterpart, with the same figures.

- [X] T082 [US5] Build the season screen — per-player totals, win-loss record, breakdown by opponent — in `ios/VBTracker/Season/SeasonView.swift`
- [X] T083 [P] [US5] Build season management: create, rename, switch, and season membership with this season's numbers, in `ios/VBTracker/Season/SeasonAdminView.swift`
- [X] T084 [P] [US5] Build the career screen, one player across every season they appear in, in `ios/VBTracker/Season/CareerView.swift`
- [X] T085 [US5] Build the game record editor — context, per-match results, and the three note boxes — in `ios/VBTracker/Season/GameFormView.swift`
- [X] T086 [US5] Build entry of a game copied from paper, serves in and out only, in `ios/VBTracker/Season/PaperGameView.swift`
- [X] T087 [P] [US5] Build importing a batch of paper games from a prepared file, in `ios/VBTracker/Transfer/PaperImportView.swift`
- [X] T088 [US5] Add an interface test walking every screen and asserting the figures against the web app's for the same season, in `ios/VBTrackerUITests/ParityScreenTests.swift`

---

> **Everything above marked done and living under `ios/` is written but not yet compiled.**
> There is no Mac here (R-001), so the first cloud build is where the SwiftUI is first seen
> by a compiler. That is the working condition, not an oversight — and it is why every
> decision those screens would otherwise make was moved into `VBPresentation`, where 218
> tests run in a fifth of a second on this machine.

---

## Phase 10: Polish & Cross-Cutting Concerns

- [X] T089 [P] Add the app icon and the watch complication placeholder assets in `ios/VBTracker/Assets.xcassets` and `ios/VBTrackerWatch/Assets.xcassets`
- [X] T090 [P] Confirm every screen holds no rules: any decision a view makes has a tested type behind it (R-001)
- [X] T091 Prove the app cannot reach a network at all, in `packages/VBCore/Tests/VBCoreTests/OfflineTests.swift` — **done, and better than the manual run it replaces**: it reads every shipped source file on every test run. Aeroplane mode was the wrong test twice over: the stakeholder dropped it as a gate in release 003, and it turns off the Bluetooth the watch link needs
- [ ] T092 Hand the watch to someone who has never seen it and ask who serves next: nine of ten correct, under two seconds (SC-008)
- [X] T093 [P] Update `CHANGELOG.md` with the release, and `CLAUDE.md` with the numeric `APP_ID` and the TestFlight route
- [ ] T094 Ship phase one to TestFlight through Codemagic, and confirm the build installs on both devices

---

## Dependencies

```text
Phase 1 (Setup)
      ↓
Phase 2 (VBCore + parity)  ← BLOCKS EVERYTHING. T027/T028 must be green.
      ↓
Phase 3 (US2 import)  →  Phase 4 (US3 tracking)  →  Phase 5 (US1 wrist court)
                                                          ↓
                                              Phase 6 (US6 link)
                                                          ↓
                                              Phase 7 (US7 wrist recording)
                                                          ↓
                                    ── phase one ships ──
                                                          ↓
                            Phase 8 (US4)  →  Phase 9 (US5)  →  Phase 10
```

**Why US1 sits after US2 and US3 despite being the release's reason**: the wrist court draws what the phone records. It is still independently testable before the link exists — Phase 5 drives it entirely from fixture snapshots — but it cannot be *verified in a gym* until Phase 6.

**US4 and US5 are release phase two** (FR-037) and must be complete before the season ends.

---

## Parallel opportunities

| Phase | Can run together |
|---|---|
| 1 | T004, T005, T006, T007 — four different files, no shared state |
| 2 | The failing-test tasks T016, T018, T020, T023, T025 — separate test files, all written before their implementations |
| 3 | T029 and T031; T037 alongside T036 |
| 4 | T040, T041, T047 — three independent screens |
| 5 | T050 and T055 |
| 6 | T061 and T066 — the same file, so sequence them if one agent is working |
| 9 | T083, T084, T087 |

Anything touching `packages/VBCore/Sources/VBCore/Reducer.swift` (T014, T015, T017, T019) is strictly sequential — one file, one rulebook.

---

## Implementation strategy

**The MVP is Phase 2 plus Phase 3.** The rulebook, proved against the real season, and that season living on the phone. It has no UI worth showing, and it is still the point at which the release stops being a risk to the operator's data.

**The first thing worth demonstrating** is Phase 5: the court on the wrist, driven by fixture data. It proves the release's reason before the link exists.

**Batch the UI work.** There is no Mac (R-001), so a cloud build that carries five layout changes costs what one carrying one costs. Write Phase 5 through Phase 7 in full, then build.

**Phase 2 is the only phase with a fast loop.** It is also the largest and the most dangerous. Do it properly — every test written before its implementation, and the parity suite green — because a port that reads correctly and counts differently has failed.
