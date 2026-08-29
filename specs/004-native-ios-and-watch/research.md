# Research: Native iOS App with a watchOS Companion

**Feature**: `specs/004-native-ios-and-watch/` · **Date**: 2026-08-29

Every decision below is recorded with what it costs, because the constitution asks for the
best route rather than the fastest and a route with no stated cost has not been examined.

---

## R-001 — There is no Mac

**Decision**: The domain is a cross-platform Swift package developed and tested on the
Windows workstation. Only the UI and the build require macOS, and that runs on Codemagic.

**The problem**: The workstation is Windows 11. There is no Xcode, no Swift toolchain, and
no simulator. An iOS app cannot be compiled, signed, or run here.

**What this changes**: everything about how the work is sequenced. So the code is split by
what needs a Mac:

| Part | Where it is written | Where it is tested |
|---|---|---|
| `VBCore` — events, reducer, statistics, migrations | Windows | Windows (`swift test`), and again on CI |
| Persistence, the watch link | Windows | macOS runner |
| iOS and watchOS screens | Windows | macOS runner, and on the operator's own devices |

The whole rulebook — which is where every bug that matters lives — is testable locally with
a fast loop. The screens are not, and that is the real cost of this decision: a UI change
cannot be seen until CI has built it. That is slow, and it will stay slow.

**Rationale**: Swift runs on Windows officially. Foundation and swift-testing run there.
SwiftUI does not, and never will. Splitting on that line is not a preference; it is the only
line that exists.

**Settled**: there is no Mac and none is being bought. The build runs on the cloud service.
So the slow loop is not a risk to be managed away — it is the working condition, and the plan
has to be built for it rather than around it.

**What that forces, and it is worth the discipline**:

- **Screens hold no rules.** Anything a view decides, a testable type decides first. A
  SwiftUI view that cannot be run locally must be thin enough that being unable to run it
  costs little.
- **Visual requirements become machine-checkable ones.** "The on-deck box is the biggest
  thing on the screen" is not left to an eye that cannot see the simulator: an interface test
  measures every box's frame and asserts the on-deck box is the largest by area, by a stated
  margin. It runs on the same CI that builds the app.
- **UI changes are batched.** One build that carries five layout changes costs what one
  carrying one costs. Working in ones is the expensive habit here.

**Alternatives considered**: a used Mac mini (would remove the slow loop entirely; the
operator has decided against it for now); a hosted Mac by the hour (a remote loop with state
that is not yours); writing everything blind with no invariant tests (rejected — a UI that
has never been run and cannot be measured is not a UI that has been built).

---

## R-002 — Stack

**Decision**: Swift 6, SwiftUI on both platforms, minimum iOS 18 and watchOS 11.

**The devices this release is actually for**:

| Device | Screen | Notes |
|---|---|---|
| Apple Watch Series 11, 42 mm | 374 × 446 pt | **The smaller of the two sizes — this is the design target.** If the court works here it works on the 46 mm |
| iPhone 14 Pro | 393 × 852 pt | Comfortably above the floor |

**Rationale**: both devices are current, so the floor is not being dragged down by them. iOS
18 / watchOS 11 is chosen for a later public release rather than for these two: it reaches
back to an Apple Watch Series 6 and an iPhone XS, which is a reasonable audience to keep,
while still allowing modern layout APIs.

SwiftUI is the only framework with one language across phone and watch, and the watch view is
six boxes and three numbers — precisely what a declarative layout is good at.

**Alternatives considered**: UIKit + WatchKit (two idioms, more code, no gain here);
Flutter or React Native (no watchOS story worth having; a wrist court in a cross-platform
runtime is the one thing these are worst at); floors at watchOS 26 (nothing needs it, and it
would exclude most of a future audience for no gain).

---

## R-003 — Porting the rules, not wrapping them

**Decision**: Port the domain from JavaScript to Swift, and prove the port with the golden
files the web app already produced.

**Rationale**: The rulebook is ~700 lines of pure functions with no I/O — the single easiest
kind of code to port, and the single most dangerous to get subtly wrong. So the port is not
trusted on inspection: the two committed migration fixtures (`tests/fixtures/v1-log.json`,
`v2-log.json`) and an export of the operator's real season are replayed through the Swift
reducer, and every derived figure is compared against the figures the JavaScript produces.
A difference of one serve fails the build.

This is what makes FR-026 testable rather than aspirational, and it runs on Windows.

**Alternatives considered**:

- *Embed JavaScriptCore and keep the existing rules verbatim.* Genuinely tempting: identical
  behaviour by construction. Rejected — JavaScriptCore is not on watchOS, so the watch could
  not compute a percentage without asking the phone, and the rules would live in a language
  neither platform can test properly.
- *Rewrite the rules from the spec rather than from the code.* Rejected. The shipped code is
  the specification of its own edge cases, and several of them were bought with real bugs.

---

## R-004 — Persistence is an append-only file

**Decision**: One append-only file of JSON lines in the App Group container, replayed on
launch. No SwiftData, no Core Data.

**Rationale**: Article VII asks whether the framework already provides this. It provides
object-graph persistence with mutation and change tracking — the exact model this app has
spent three releases *not* having. An event log is appended to and never updated; the only
read is "give me all of it, in order". A file does that in one call, survives a crash after
any complete line, and can be handed to a diff.

Cost of a full replay: the operator's real season is a few thousand events. Replay is
milliseconds. A checkpoint is not needed and would be a second source of truth.

**Alternatives considered**: SwiftData (fights the model, and its migrations are a second
migration system next to the one the log already has); a single blob rewritten per event
(loses the whole log to one bad write); SQLite (a dependency to hold what a file holds).

**Consequence**: the App Group is `group.com.mikejsmith.vbtracker`, derived from the bundle
id exactly as the global build-identity rule requires, so a later widget or complication can
read the same log without a second copy.

---

## R-005 — The watch link

**Decision**: WatchConnectivity, with a different channel in each direction because the two
directions want opposite guarantees.

| Direction | Carries | Mechanism | Why |
|---|---|---|---|
| Phone → watch | The court, as a snapshot | `updateApplicationContext`, plus `sendMessage` while reachable | Only the newest snapshot matters; a queue of stale courts is worse than none |
| Watch → phone | Recorded serves, as events | `transferUserInfo` | Queued, FIFO, delivered even if the app is not running, survives going out of range |

**Exactly once (FR-020)**: every event carries a stable identifier made when it is created.
The phone ignores an identifier it already holds. Delivery can then retry freely, which is
what makes "exactly once" true rather than hoped for.

**Staleness (FR-013)**: each snapshot carries a sequence number and the moment it was made.
The watch shows how long ago that was, and marks itself not-current after a threshold —
because a court that is quietly ten minutes old is worse than a blank screen.

**Alternatives considered**: sending the whole log both ways (the watch does not need a
season to draw six boxes); CloudKit (needs a network and an account, and FR-032 forbids
both); Multipeer or nearby-device sync (that is the second-phone problem, ruled out of scope
by FR-017).

---

## R-006 — Making one box the biggest without breaking the court

**Decision**: A 3×2 grid with deliberately uneven tracks — the right column wider, the top
row taller — so the top-right cell is the largest cell on the screen by area, while the
court arrangement stays exactly as it is on the floor.

**Why the top-right cell**: the server is bottom-right; the player who rotates into that
position next is the one at top-right. That is the on-deck player, and the decision the
coach is making is about them (FR-005).

**Why not simply enlarge one box**: a box that grows out of its grid overlaps its
neighbours, and the arrangement *is* the information. Uneven tracks keep every box in its
true position and still leave one box unmistakably the biggest.

**The numbers, on the 42 mm watch** — the smaller size is the design target, so the layout is
sized against 374 × 446 pt rather than against the roomier 46 mm:

| | Width | Height |
|---|---|---|
| Columns (1 : 1 : 1.35) | ~100 pt · ~100 pt · ~135 pt | |
| Rows (1.25 : 1) | | ~205 pt · ~165 pt |
| **On-deck box** (top right) | **~135 pt** | **~205 pt** |
| Smallest box (bottom left/middle) | ~100 pt | ~165 pt |

The on-deck box is roughly **1.7× the area** of the smallest — a margin an interface test can
assert rather than an eye can judge (R-001).

**Within a box**: the jersey number is primary and set large — around 46 pt in the on-deck
box, around 32 pt elsewhere; the serve-in percentage is second at ~15 pt; points third at
~13 pt. Only the on-deck box shows all three at full size; the others compress, and the
smallest may drop points to a glyph. A figure never recorded is a dash (FR-006).

**Also decided**: the court is the first page; recording is the second page of a two-page
layout, reached by a swipe. Recording is buttons only — never a gesture, never the crown —
so nothing is recorded by a wrist moving through a gym evening (FR-024). The five-serve
limit is a haptic as well as a visual (FR-023). The layout must stay legible in the
always-on display, which means no information carried by colour alone.

---

## R-007 — How the season comes across

**Decision**: The backup file the web app already writes. No new capability on the web side.

The route: web app → *Save a backup file* → share sheet → Files → native app imports it.

**On arrival** the native app: validates the schema version; runs the same ordered migration
chain (v1→v2→v3), ported with its fixtures; assigns a stable identifier to every event that
does not have one; and either completes in full or changes nothing (FR-028).

**Idempotence (FR-029)**: the import records a hash of the log it read. Importing the same
file twice is recognised and refused rather than doubling the season.

**And back out again**: the native app's own export writes the identical shape, so the web
app can still read a log the native app has written. This is what makes FR-038 real during
the phase gap — the two apps do not share a live store, and pretending otherwise would be a
lie. What they share is a file format.

**Alternatives considered**: reading the PWA's `localStorage` directly (a native app cannot;
that store belongs to Safari); a hosted hand-off (needs a network the gym does not have);
retyping (a season of real data — not acceptable, and the reason FR-036 exists).

---

## R-008 — Testing, in the constitution's three layers

| Layer | What | Where it runs |
|---|---|---|
| Unit | `VBCore`: reducer, statistics, migrations, court geometry. Pure, no I/O | Windows, in a fast loop |
| Integration | The log file, the import, the watch link against a faked session | macOS runner |
| Interface | XCUITest: a match tracked end to end on both platforms | macOS runner |

**Deviation to record**: Article V names Cypress with `cypress-real-events` for the top
layer. There is no Cypress for a watch. XCUITest is the same idea in the only tool that can
drive the thing — real events on a real device, never synthetic taps into a view model.

**The parity suite is the load-bearing one**: the golden files from R-003 are the proof that
a season's figures did not change when the language did.

---

## R-009 — Building and releasing without a Mac

**Decision**: Codemagic, using the App Store Connect key already held in the vault under
`APPLE_ASC_KEY_ID`, `APPLE_ASC_ISSUER_ID`, `APPLE_ASC_PRIVATE_KEY`, `APPLE_TEAM_ID`.
Distribution to the operator's own devices through TestFlight.

**On Article VIII**: the article forbids releasing through GitHub Actions, and the reason it
gives is waiting on a runner to build a release. Codemagic is not GitHub Actions, and it is
already the established Apple path in the operator's global build-identity rules. A Windows
workstation cannot produce a signed iOS build by any local route, so the local pipeline the
article prefers does not exist for this target. Recorded in the plan's Complexity Tracking
rather than assumed away.

**Project file**: the Xcode project is generated from a checked-in `project.yml` by XcodeGen
on the runner. A `.pbxproj` is not a file anyone should hand-edit, least of all on a machine
that cannot open it.

---

## R-010 — What the two phases contain

Phase one is the match-day core and nothing else: `VBCore`, the log, the import, the phone's
tracking loop, the wrist court, and recording from the wrist. It is not shippable without
the import (FR-036).

Phase two is parity: seasons, career statistics, entering games from paper, and correcting a
past game serve by serve — every screen of the web app with a counterpart, before the season
ends (FR-037).

The web app keeps running throughout. During the gap the operator uses one app as the
recorder for any given game, and moves data by backup file in whichever direction is needed.
