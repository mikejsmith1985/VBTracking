# Quickstart & Validation: Rotation, Substitutions, and Durable Data

**Feature**: `002-rotation-and-subs` | **Date**: 2026-08-29

Extends `specs/001-volleyball-serve-tracker/quickstart.md`. Its scenarios V-1 to V-8 must still pass unchanged — this release may not regress the shipped one.

---

## Prerequisites

Same as release 001: Node 20+ for the test suite, an HTTPS origin for the service worker, and an iPhone for the claims only a device can prove.

**One addition:** a stored event log written by the **live release-001 build**, captured as a fixture before any release-002 code touches it. Without it, the migration test asserts against the format as remembered rather than as shipped.

```bash
# In Safari devtools on the live build, or the browser console:
copy(localStorage.getItem('vbtracking.eventlog'))
# Save to tests/fixtures/v1-log.json
```

---

## Run

```bash
npx serve . -l 5173     # or: .\scripts\run-dev-clean.ps1
npm test
```

---

## Validation scenarios

### V2-1 · Nothing already recorded is lost — **the one that matters**

Covers `FR-001` to `FR-008`, `US1`, `SC-001`.

1. On the **live release-001 build**, record a full game. Note every figure on the Stats screen at all three scopes.
2. Deploy release 002 to the same origin.
3. Relaunch the installed app.

**Expected**: every roster entry, game, match, serve turn and serve is present. Every figure matches what was noted. The operator is asked nothing.

4. Relaunch again.
   **Expected**: loads normally; nothing is migrated a second time.
5. Hand-edit the stored `schemaVersion` to a number above the current one and relaunch.
   **Expected**: the app explains the data is from a newer version, does not load it, and **does not overwrite it** — confirm by reading storage afterwards.

> If this scenario fails, nothing else in the release ships. A stakeholder's recorded season is the thing being protected.

---

### V2-2 · The rotation serves the right players

Covers `FR-009` to `FR-013`, `FR-018` to `FR-022`, `US2`, `US3`, `SC-002`, `SC-003`.

1. With a 9-player roster, start a game. Set a lineup of six in a known order. Pick position 1 to serve first.
2. Record a side-out with a **single tap** (`OUT`).
   **Expected**: the second player in the lineup is already the server. No picker appeared.
3. Continue until all six have served and it wraps to the first.
   **Expected**: the order matches the lineup exactly; the wrap is correct.
4. Tap **Change** and pick a different player.
   **Expected**: they become the server, and the next advance continues from *their* position.
5. End match 1 and open match 2.
   **Expected**: the lineup is prefilled from match 1 and is editable before the first serve.
6. Try to confirm a lineup of five, and one with the same player twice.
   **Expected**: both refused, with the shortfall stated.

---

### V2-3 · Substitutions land in the right slot

Covers `FR-026` to `FR-037`, `US4`, `SC-005`, `SC-006`.

1. Mid-match, double-tap a lineup player.
   **Expected**: that chip is visibly armed.
2. Tap a player already in the lineup.
   **Expected**: refused with a reason; the arm survives.
3. Tap a bench player.
   **Expected**: they take the armed player's exact position.
4. Play through a full rotation.
   **Expected**: the incoming player serves in that slot; the outgoing player's earlier serves are still theirs and still counted.
5. Substitute the **current server** mid-turn.
   **Expected**: serves already in that turn stay with the outgoing player; the incoming player becomes the server.
6. Undo.
   **Expected**: the outgoing player returns to their position and the rotation continues as before.
7. Double-tap a player, then tap somewhere that is not a player.
   **Expected**: the arm clears; nothing recorded.
8. Double-tap a player, then end the match.
   **Expected**: the arm is discarded, not applied.

---

### V2-4 · Undo still reverses exactly one operator action

Covers `FR-024`, `SC-011`.

1. With a lineup set, note every figure. Record a serve that ends the turn — the rotation advances.
2. Undo **once**.

**Expected**: the serve **and** the advance are both reversed. The previous player is serving again with their turn open. Every figure matches what was noted.

3. Repeat with an off-lineup server and with a substitution in between.
   **Expected**: same — one undo, one operator action.

---

### V2-5 · Off-lineup serving does not derail the rotation

Covers `FR-023`, edge cases.

1. With a lineup set, tap a player **not** in the lineup and record a serve.

**Expected**: it records normally. The turn is marked as served from outside the lineup, on both the status row and the tally board.

2. Let the turn end.
   **Expected**: the rotation resumes from the last position that *was* in the lineup — one off-lineup turn does not shift the order.

---

### V2-6 · Backup and restore — on the device

Covers `FR-038` to `FR-046`, `US5`, `SC-007`, `SC-008`.

1. On the **iPhone**, with data recorded, tap **Export**.
   **Expected**: the iOS share sheet opens and **Save to Files** produces a real file. A silent failure here is the bug this scenario exists to catch.
2. Clear all app data. Import the file.
   **Expected**: every roster, game and figure returns identically.
3. Import a file with a character deleted from the middle.
   **Expected**: refused with a plain explanation; existing data completely untouched — verify by reading it afterwards.
4. Import an unrelated JSON file.
   **Expected**: refused; nothing changed.
5. Import a file whose `schemaVersion` is above the current one.
   **Expected**: refused with a reason; nothing partially applied.
6. Export with nothing recorded at all, then import that file.
   **Expected**: valid and importable.
7. Import during a live match.
   **Expected**: the confirmation names that the in-progress match is replaced too.

---

### V2-7 · Player chips read at arm's length

Covers `FR-047` to `FR-051`, `US6`, `SC-010`.

With a 20-player roster, on the device:

| Check | Expected |
|---|---|
| Every chip | One large jersey number, no truncated name |
| A player with no number | Still identifiable and selectable |
| Tally board and stats | Full name **and** number, untruncated |
| The picker | All 20 reachable, no horizontal scrolling |
| At arm's length | The current server identified in under 2 seconds |

---

### V2-8 · Release 001 has not regressed

Run V-1 through V-8 from `specs/001-volleyball-serve-tracker/quickstart.md` unchanged, including the **airplane-mode game (V-7)**.

**Expected**: all pass. In particular, a full three-match game completes offline with no data loss, and the app makes zero network requests after install.

---

## Deploy

```bash
git push origin feature/rotation-and-subs
gh pr create --base main
# merge; Pages redeploys from main
```

**Bump `CACHE` in `sw.js`** — installed clients keep serving the old version until the cache name changes. Add any new source file to the precache list; `tests/unit/sw.test.js` fails if one is missed.

---

## Definition of done

| # | Claim | Evidence |
|---|---|---|
| 1 | Real release-001 data survives, figures identical | V2-1 on the device |
| 2 | Migration runs against a committed release-001 log fixture | `npm test` |
| 3 | Side-out costs one tap; six turns match lineup order | V2-2 |
| 4 | Substitutions take the right slot; prior serves stay attributed | V2-3 |
| 5 | One undo reverses one operator action, advance included | V2-4 |
| 6 | Export reaches a real file on the phone; a bad import changes nothing | V2-6 |
| 7 | Every rule lives in `src/domain/`; `ui → state → domain` holds | Source review |
| 8 | Release 001 has not regressed, airplane mode included | V2-8 on the device |
| 9 | `CHANGELOG.md` updated | Article VI |

---

## Offline verification — dropped, deliberately

Airplane-mode verification is **no longer a release gate**, at the stakeholder's decision:
the app is expected to become a native iOS app before connectivity in a gymnasium
genuinely matters, so paying for the verification now buys little.

**The app is still offline-capable.** The service worker, the precache list and the
zero-network-request design are all unchanged, and the precache completeness test still
runs on every commit. What has gone is the requirement to *prove it on the device* before
shipping. If offline behaviour ever regresses it will be found in use rather than in a
checklist — an accepted trade, not an oversight.
