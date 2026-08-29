# Quickstart & Validation: Volleyball Serve Tracker

**Feature**: `001-volleyball-serve-tracker` | **Date**: 2026-08-29

---

## Prerequisites

| Need | Why |
|---|---|
| Node.js 20+ | Runs the test suite only. The app itself has no runtime dependencies. |
| An HTTPS origin | Service workers require a secure context. `file://` cannot install or work offline. |
| An iPhone | The Article X proof for this feature happens on the device, not in a desktop browser. |

---

## Run locally

The app is static files with no build step.

```bash
npx serve . -l 5173
```

Open `http://localhost:5173`. `localhost` counts as a secure context, so the service worker registers and offline behaviour can be exercised in DevTools.

> Desktop verification is for logic and layout only. It does **not** prove `FR-044`–`FR-058`. Those are device claims and need the device.

---

## Run the tests

```bash
npm install     # dev dependencies only — vitest, cypress
npm test        # unit + persistence integration
npm run test:ux # Cypress with real pointer events
```

The unit suite covers everything in `src/domain/` and must stay well under 10 ms per test (Article V). It is pure — no DOM, no storage, no clock.

---

## Validation scenarios

Each scenario below proves a specific claim. Run them in order; later ones assume the app is installed.

### V-1 · Roster persists and shows no empty rows

Covers `FR-002`–`FR-004`, `US1`.

1. Open the app. Go to **Roster**.
2. Add 9 players with names and jersey numbers.
3. Confirm exactly **9** rows are visible — no blank or placeholder rows.
4. Try to add players up to 21. The add control refuses at 20 and states the limit.
5. Force-quit the app entirely and reopen.

**Expected**: all players return in order, names and numbers intact.

---

### V-2 · Turn boundaries are inferred correctly

Covers `FR-020`, `FR-021`, `FR-024`–`FR-026`, `US2`.

1. Go to **Track**. Tap player A.
2. Record `IN — POINT` three times.
   **Expected**: A stays the active server throughout; the tally shows 3 marks in one colour.
3. Record `OUT`.
   **Expected**: the turn closes; the screen enters side-out state; the outcome controls are visibly disabled.
4. Tap an outcome control.
   **Expected**: nothing happens.
5. Tap player B, record `IN — POINT`, then tap player A **without** recording a serve for B.
   **Expected**: B's turn closes holding its single serve; a new turn opens for A in a different colour from the turn before it.

---

### V-3 · Undo restores exactly

Covers `FR-040`–`FR-043`, `US2`.

1. Note every figure on the Stats screen for the current match.
2. Record four more serves across two players.
3. Undo four times.

**Expected**: every figure returns to the noted values. No empty turn is left behind. The turn colours and boundaries are identical to before.

4. Tap a player, then immediately undo.
   **Expected**: the app returns to side-out state with no zero-serve turn anywhere in the tally.
5. End the match, then attempt undo.
   **Expected**: undo does not reach into the ended match.

---

### V-4 · Referee miscount is recorded in full

Covers `FR-029`, `FR-030`, `SC-008`, `US4`.

1. Give one player a turn of **7** consecutive serves (6 × `IN — POINT`, then one `OUT`).

**Expected**: 7 marks render — none dropped, none collapsed. The turn group carries a visible over-limit warning. The per-turn count reads 7. No statistic anywhere caps at 5.

---

### V-5 · Statistics reconcile against a hand tally

Covers `FR-036`–`FR-039`, `SC-006`, `US5`.

1. Play three matches with a serve sequence you record on paper as you go.
2. Compare per-match figures to the paper tally.
3. Compare game totals to the sum of the three matches.
4. Find a player with zero serves.

**Expected**: every figure matches exactly. Game totals equal the sum of matches. The zero-serve player shows a non-numeric in-percentage, never `0%` or `NaN`.

---

### V-6 · Install to Home Screen

Covers `FR-053`, `US3`.

1. Open the deployed HTTPS URL in Safari on the iPhone.
2. **Share → Add to Home Screen**.
3. Launch from the Home Screen icon.

**Expected**: the app fills the screen with no address bar and no browser navigation. The icon is the app icon, not a page screenshot.

---

### V-7 · Airplane mode — the Article X proof

Covers `FR-054`–`FR-057`, `SC-003`, `SC-004`, `US3`. **This is the proof that matters. A green test suite is not a substitute.**

1. Launch the installed app once with a connection so the service worker precaches.
2. Enable **airplane mode**.
3. Force-quit the app.
4. Relaunch from the Home Screen.
5. Play a complete three-match game end to end.
6. Force-quit mid-match at least once and relaunch.

**Expected**: the app launches and every screen works with no connection. No capability is missing or degraded. After each relaunch the in-progress game, the current match, the active server, and every recorded serve are restored exactly.

**Also confirm**: with DevTools attached over USB, the Network panel shows **zero** requests during normal operation after install (`FR-055`).

---

### V-8 · One-handed operation

Covers `FR-044`–`FR-052`, `SC-010`, `SC-011`, `US3`.

Hold the phone in one hand, standing, as if watching a match.

| Check | Expected |
|---|---|
| Record 20 serves using only the holding thumb | No grip change needed |
| Rotate the device | Layout stays portrait |
| Double-tap an outcome control | Exactly one serve recorded; no zoom |
| Pinch the screen | No zoom |
| Swipe down from the top of the list | No pull-to-refresh |
| Inspect top and bottom edges | Nothing hidden behind the notch or home indicator |
| Read the screen at arm's length in bright light | Marks and text remain legible |

---

## Deploy

No build step — the repository *is* the artifact.

```bash
git push origin feature/volleyball-serve-tracker
```

Then enable GitHub Pages for the branch, serving from the repository root. The resulting URL is the HTTPS origin used in V-6.

> **Paths must stay relative.** Pages serves project sites from a subpath (`/VBTracking/`). A root-absolute reference such as `/sw.js` will 404 there and break install and offline silently. See `research.md` R-008.

**Fallback** if Pages propagation is slow:

```bash
npx netlify-cli deploy --prod --dir=.
```

Per Article VIII no GitHub Actions workflow is authored for this; there is nothing to build.

---

## Definition of done

| # | Claim | Evidence |
|---|---|---|
| 1 | Unit suite green, each test under 10 ms | `npm test` output |
| 2 | Every rule lives in `src/domain/`, none in `src/ui/` | Import direction holds: `ui → state → domain` |
| 3 | Installs to Home Screen and launches standalone | V-6 on the device |
| 4 | Full game completed in airplane mode with no data loss | V-7 on the device |
| 5 | Zero network requests after install | V-7 Network panel |
| 6 | Statistics match an independent hand tally | V-5 |
| 7 | Over-5 turns recorded in full and flagged | V-4 |
| 8 | Operable one-handed in portrait | V-8 on the device |
| 9 | `CHANGELOG.md` updated | Article VI |
