# Implementation Plan: Native iOS App with a watchOS Companion

**Branch**: `004-native-ios-and-watch` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/004-native-ios-and-watch/spec.md`

## Summary

Put the court on the coach's wrist, and move a real season across without changing a figure.

The rules that make this app worth anything are ~700 lines of pure functions with no I/O.
They are ported to a **cross-platform Swift package**, which is the whole trick of this plan:
the rulebook can be developed and tested on the Windows workstation in a fast loop, and only
the screens need a Mac. The port is proved against the golden files the shipped web app
already produced — replay the same log, get the same figures, or fail the build.

On top of that package sit two thin SwiftUI apps. The phone records and holds the truth. The
watch draws six boxes in the court's own arrangement, makes the on-deck box the biggest
thing on the screen, and can record a serve outcome itself. They are joined by
WatchConnectivity, with a latest-wins snapshot going out and a guaranteed, exactly-once
queue of events coming back.

The season comes across as the backup file the web app already writes — no new capability on
the web side, no network, and refused rather than doubled if imported twice.

## Technical Context

**Language/Version**: Swift 6 (strict concurrency). `VBCore` is Foundation-only and builds
on Windows, macOS, iOS and watchOS.

**Primary Dependencies**: SwiftUI, WatchConnectivity, swift-testing. No third-party runtime
dependency — the web app shipped with none and the reasons still hold. XcodeGen is a
build-time tool only, run on CI.

**Storage**: One append-only file of JSON lines in the App Group container
`group.com.mikejsmith.vbtracker`, replayed on launch. No SwiftData, no Core Data — see R-004.

**Testing**: swift-testing for `VBCore` (unit, pure, runs on Windows); XCTest for
persistence and the watch link against a faked session; XCUITest for the interface layer on
both platforms. The cross-language parity suite gates every build.

**Target Platform**: iOS 17+, watchOS 10+. iPhone portrait only. Floor to be confirmed
against the coach's actual watch (R-002).

**Project Type**: Native mobile app with a watch companion, over a shared pure-domain
package. The existing web app stays in the repository root, untouched and still shipping.

**Performance Goals**: A serve recorded on the phone is on the wrist within 3 seconds
(SC-002). Replay of a full season on launch is imperceptible. The recording loop stays at
one tap per serve (SC-005).

**Constraints**: Offline in a gym — no network of any kind during a match (FR-033). No
account, no sign-in (FR-041). All data on the operator's own devices (FR-040). Nothing in
the tracking loop may wait on the watch (FR-015). **No Mac on the workstation** — the
constraint that shapes the sequencing more than any other (R-001).

**Scale/Scope**: One operator, several seasons, ~20 players per season, a few thousand
events per season. Phase one is roughly a dozen screens across two platforms; phase two adds
the season, career, paper-entry and correction screens.

## Constitution Check

*GATE: checked before Phase 0, re-checked after Phase 1 design.*

| Article | Gate | Status |
|---|---|---|
| I — Prime directive | Best route, not fastest | **Pass.** The domain is ported and proved against golden files rather than trusted; the split that allows local testing was chosen over the quicker path of writing everything blind. |
| II — Process protection | No wildcard process kills | **Pass.** Nothing in this plan kills a process. |
| III — Branching | Feature branches, PR to main | **Pass.** `004-native-ios-and-watch` and per-slice branches beneath it. |
| IV — Code quality | Self-documenting names, doc comments, <40-line functions, why-comments | **Pass.** Carried over from the web app, which holds to it. |
| V — Testing | Three layers, real events at the top, red→green→refactor | **Deviation.** Cypress cannot drive a watch. XCUITest replaces it at the interface layer, same intent. Recorded below. |
| VI — Documentation | `CHANGELOG.md` is the record; no auxiliary status docs | **Pass.** The `specs/004-*` tree is a pipeline artefact and exempt. |
| VII — Framework-first | Do not build what the framework provides | **Pass with justification.** SwiftData and Core Data were examined and rejected for an append-only log; the one-line reason lives at the store (R-004). |
| VIII — Release | Local pipeline only, never GitHub Actions | **Deviation.** No local route exists: a Windows workstation cannot sign an iOS build. Codemagic — already the established Apple path in the operator's global rules — with TestFlight. Recorded below. |
| IX — Vault | Secrets injected, never handled | **Pass.** The four App Store Connect values are named, never read. |
| X — Verification | Evidence, not "it compiles" | **Pass.** Parity is proved figure by figure against the shipped web app; the wrist court is verified on a real watch in a real gym. |
| XI — Output restraint | One dashboard, no narration | **Pass.** |
| XII — Response format | Tight, scannable | **Pass.** |

## Project Structure

### Documentation (this feature)

```text
specs/004-native-ios-and-watch/
├── spec.md              # The specification (7 stories, 41 requirements)
├── plan.md              # This file
├── research.md          # Phase 0: ten decisions, with what each costs
├── data-model.md        # Phase 1: entities, the event log, and what the port must not change
├── quickstart.md        # Phase 1: how to run and verify each slice
├── contracts/           # Phase 1: the watch link, the log file, the import format
└── tasks.md             # Phase 2 output — not created by /speckit-plan
```

### Source Code (repository root)

```text
packages/VBCore/                 # Pure domain. Builds and tests on Windows.
├── Package.swift
├── Sources/VBCore/
│   ├── Events.swift             # The event type and its constructors
│   ├── Reducer.swift            # replay(events) -> State, and the rejection rules
│   ├── Statistics.swift         # Derived on read, never stored
│   ├── Aggregate.swift          # Season, career, game summaries; null-not-zero
│   ├── Migrations.swift         # The ordered chain, ported with its fixtures
│   └── Court.swift              # Court geometry: positions, rotation, who is on deck
└── Tests/VBCoreTests/
    ├── ReducerTests.swift
    ├── StatisticsTests.swift
    ├── MigrationTests.swift
    ├── CourtTests.swift
    └── ParityTests.swift        # Golden files vs the JavaScript figures

ios/
├── project.yml                  # XcodeGen input; the .xcodeproj is generated on CI
├── VBTracker/                   # iPhone app
│   ├── App/                     # Entry point, the store, the log file
│   ├── Track/                   # The recording loop: court, dock, outcomes, rotation
│   ├── Record/                  # Serve-by-serve correction of a past game (phase two)
│   ├── Season/                  # Seasons, career, paper entry (phase two)
│   └── Transfer/                # Import from the web app, export back out
├── VBTrackerWatch/              # watchOS app
│   ├── CourtView/               # Six boxes, uneven tracks, the on-deck box biggest
│   ├── RecordView/              # Three outcome buttons, one deliberate tap each
│   └── Link/                    # WatchConnectivity: snapshot in, events out
└── Shared/
    └── Link/                    # The connectivity contract, and its fake for tests

tests/fixtures/                  # Existing. Reused unchanged as the parity golden files.
```

Everything already in the repository root — the shipped web app — stays exactly where it is
and keeps deploying. It is not moved into a subdirectory: a working app in a real season is
not worth disturbing for tidiness.

**Structure Decision**: A pure Swift package under `packages/VBCore` with the two apps under
`ios/`. The line between them is the line between what can be tested on this workstation and
what cannot, which is the single most useful boundary available on a machine with no Mac.

## Phase Outputs

| Phase | Output | State |
|---|---|---|
| 0 | `research.md` — ten decisions: no Mac, the stack, porting vs wrapping, the log file, the watch link, the wrist layout, the migration route, the three test layers, Codemagic, and what each phase contains | Complete |
| 1 | `data-model.md`, `contracts/`, `quickstart.md` | Complete |
| 2 | `tasks.md` | Not started — `/speckit-tasks` |

## Delivery order

Phase one, in the order each slice can be proved:

1. **`VBCore` with parity.** The rulebook, ported, replaying the committed fixtures and the
   operator's real season to identical figures. Testable on Windows, and worth nothing until
   the parity suite is green.
2. **The log file and the import.** The season lands on the phone, all-or-nothing, refused
   if imported twice, and exports back out in a shape the web app can still read.
3. **The phone's tracking loop.** One tap per serve, the rotation advancing itself, the
   five-serve alert, undo reversing exactly one action.
4. **The wrist court.** Six boxes, the arrangement of the floor, the on-deck box the biggest
   thing on the screen.
5. **The link.** Snapshot out, events back, staleness stated plainly, exactly-once delivery.
6. **Recording from the wrist.** Three buttons, a haptic at five, and no accidental serves.

Phase two follows the same rule — one slice, one proof: correcting a past game, then
seasons, then career, then paper entry.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Article V: XCUITest instead of Cypress at the interface layer | Cypress cannot drive an Apple Watch, or any native app | There is no Cypress equivalent for watchOS. XCUITest drives real events on a real device, which is the article's actual requirement |
| Article VIII: Codemagic instead of a local release pipeline | A Windows workstation cannot compile or sign an iOS build by any local route | The article's stated concern is waiting on a GitHub Actions runner; Codemagic is not Actions, and the operator's global rules already establish it as the Apple path with the key in the vault |
| A second implementation of the domain, in a second language | The watch must compute a percentage without asking the phone, and watchOS has no JavaScript runtime | Embedding JavaScriptCore was examined (R-003): it is unavailable on watchOS and would leave the rules untestable on both platforms. The duplication is contained by the parity suite, which fails the build on a one-serve difference |
