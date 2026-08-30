# Quickstart: verifying the native app and its watch

**Feature**: `specs/004-native-ios-and-watch/` · Read with [plan.md](./plan.md)

How to run each slice and how to know it works. Nothing here is a formality: every step below
is the evidence Article X asks for, and each names what would count as a failure.

---

## Prerequisites

| Need | For | Notes |
|---|---|---|
| **Swift 6.3.3** for Windows | `VBCore` | `winget install Swift.Toolchain`. This is the whole local loop |
| **Visual Studio Build Tools 2022**, C++ workload | `VBCore` | Swift on Windows links with MSVC: without `link.exe` the toolchain reports itself invalid. `winget install Microsoft.VisualStudio.2022.BuildTools --override "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"` |
| Codemagic, connected to this repository | Every build with a UI | Key already in the vault as `APPLE_ASC_KEY_ID`, `APPLE_ASC_ISSUER_ID`, `APPLE_ASC_PRIVATE_KEY`, `APPLE_TEAM_ID` |
| iPhone 17 Pro, and the paired Apple Watch Ultra 2 | The court on the wrist | The design target is the *smallest* supported watch (40 mm), not these — a court that reads there reads everywhere |
| A backup file from the shipped web app | Parity, and the migration | *Game tab → Save a backup file* |

There is no Mac and none is coming. Slice 1 is the only part with a local loop; everything
with a screen in it is built on the cloud service and verified on the two devices above.

---

## Slice 1 — `VBCore`, with parity

Nothing else starts until this is green.

```powershell
.\scriptsbcore-test.ps1
```

That wrapper exists because three things have to be in the session before `swift build`
works, and none of them are in a shell that was open before the toolchain was installed:
the Visual Studio developer environment, the user PATH, and `SDKROOT`. `scripts/swift-env.ps1`
sets all three; source it directly if you want a shell to work in.

**Passes when**

- The reducer, statistics, rotation, correction, court and migration suites pass — the
  ported counterparts of the web app's 677 tests. **117 of them exist today, and run in
  0.02 seconds.**
- `ParityTests` replays `tests/fixtures/v1-log.json` and `v2-log.json` and matches
  `v1-expected.json` and `v2-expected.json` exactly.
- `ParityTests` replays the operator's real season export and produces figures identical to
  the web app's, **including which figures are dashes**.

**Fails if** any figure differs by one serve. That is the whole point of the suite: a port
that reads correctly and counts differently is a port that has failed.

**Also verify**: `swift test` completes in seconds. `VBCore` has no I/O, no clock and no
randomness; if a test needs a delay, something has leaked into the domain.

---

## Slice 2 — The log file and the import

```bash
swift test --filter LogFileTests   # the parts with no UI
```

*(needs a Mac for the app-side steps)*

| Step | Expect |
|---|---|
| Import the web app's backup | Every player, game, match, turn and note present; the season reads as it did in the browser |
| Compare figures screen by screen against the web app | Identical, dashes included (SC-003) |
| Import the same file again | Refused — "That backup is already in. Nothing was changed." (FR-029) |
| Import a truncated file | Refused, and nothing on the device has changed (FR-028) |
| Export from the native app, open that file in the web app | Loads, and the figures match |
| Force-quit mid-match, reopen | Resumes exactly where it stopped, nothing lost (SC-007) |

---

## Slice 3 — The tracking loop on the phone

Track a full three-match game with **Wi-Fi and cellular off, Bluetooth on** — a gym, in
other words — keeping a paper tally alongside.

Not aeroplane mode: that turns Bluetooth off too, and Bluetooth is how the watch hears the
phone. It would prove the app works offline by breaking the one link the release is for.

| Check | Expect |
|---|---|
| One tap per serve | The tally and the figures move immediately |
| Rotation | Advances itself on a side-out; no tap needed |
| Undo | Reverses exactly one operator action, including the rotation advance it caused |
| Five serves | The alert covers the screen; a sixth is still recorded and flagged |
| No internet, Bluetooth on | Nothing fails, nothing waits, and the wrist still follows (SC-004) |
| The paper tally | Matches the app, figure for figure |

---

## Slice 4 — The court on the wrist

With a match in progress, and **without touching either device**:

| Check | Expect |
|---|---|
| Arrangement | Six boxes as the players are standing; server bottom-right |
| Rotation | Server steps to bottom-middle; top-right steps down into service |
| Each box | Number, serve-in percentage, points |
| A player who has not served | A dash. Never `0%`, never `100%` |
| The on-deck box | Unmistakably the largest box on the screen (FR-005). Asserted by measurement — at least 1.5x the area of the smallest box (SC-014), on every supported watch size from 40 mm to the Ultra's 49 mm — because no simulator can be opened on this workstation |
| Substitution | The incoming player appears in the outgoing player's exact box |
| No lineup set | The watch says it cannot name the next server, rather than naming one |
| Five on court | The empty position shows as empty |
| Always-on display | Still readable; nothing carried by colour alone |

**The test that matters** (SC-001, SC-008): hand the watch to someone who has never seen it,
say nothing, and ask them who serves next. Nine of ten should be right, in under two seconds.

---

## Slice 5 — The link

| Step | Expect |
|---|---|
| Record a serve on the phone | The wrist follows within 3 seconds (SC-002) |
| Put the phone in a bag across the gym | The watch marks itself not current, and says how long ago it was (SC-006) |
| Bring them back together | Catches up on its own, with nothing lost or doubled |
| Out-of-order snapshots (fake session) | The older snapshot never wins |

---

## Slice 6 — Recording from the wrist

| Step | Expect |
|---|---|
| Put the phone down; record a whole turn on the watch | The phone's record is identical to one recorded on the phone (FR-019) |
| Undo on the phone | Reverses that watch-recorded serve, and only it |
| Record while out of range | The wrist shows what has not landed; all of it arrives, in order, exactly once, on reconnection |
| The fifth serve | Felt on the wrist without looking (FR-023) |
| A whole evening of ordinary wrist movement | Nothing recorded by accident (SC-011) |

---

## Release

Per Article VIII as amended in the plan's Complexity Tracking: Codemagic builds and signs;
TestFlight delivers to the operator's own devices. No GitHub Actions runner is involved.

`CHANGELOG.md` is updated in the same pull request as any behaviour change — including this
one, where the behaviour is "there is now an app".
