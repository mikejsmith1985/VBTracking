# Quickstart & Validation: Seasons, Career Players, and Game Context

**Feature**: `003-seasons-and-career` | **Date**: 2026-08-29

Extends the quickstarts of releases 001 and 002. Their scenarios must still pass unchanged — this release may not regress either.

---

## Prerequisites

As before, plus **a stored event log captured from the live release-002 build**, committed as `tests/fixtures/v2-log.json` before any release-003 code exists. The release-001 fixture is already committed. Two fixtures mean the migration chain is proven from both of its real starting points.

```bash
npx serve . -l 5173     # or: .\scripts\run-dev-clean.ps1
npm test
```

---

## V3-1 · A real season survives — the one that gates the release

Covers `FR-001` to `FR-006`, `US1`, `SC-001`.

1. On the **live release-002 build**, note every figure on the Stats screen at all three scopes.
2. Deploy release 003. Relaunch the installed app.

**Expected**: every player, game, match, turn and serve present; every figure identical; the operator asked nothing. The former roster now appears as a season's players, each with their jersey number.

3. Open the Season screen.
   **Expected**: one season exists, holding every game recorded so far.
4. Relaunch again.
   **Expected**: loads normally; nothing migrates twice.
5. Check any previously ended match.
   **Expected**: shown as **undecided**, never as a loss.

> If this fails, nothing ships. A real season is already recorded on the live build.

---

## V3-2 · A number belongs to a season, not a person

Covers `FR-007` to `FR-011`, `FR-018` to `FR-023`, `US2`, `SC-002`.

1. Create a second season with a different team name.
2. Add an existing player to it with a **different number**.
3. View both seasons.
   **Expected**: each shows its own number for that player; they are recognisably one person.
4. Open that player's career.
   **Expected**: both seasons listed separately with the right team and number, plus a combined total.
5. Remove them from the second season.
   **Expected**: gone from that roster; the person and every recorded serve remain.
6. Try to add the same person to one season twice. **Expected**: refused.
7. Give two players in one season the same number. **Expected**: warned, allowed, both identifiable.
8. Try to switch seasons with a match in progress. **Expected**: refused, with the reason.
9. Correct a player's name. **Expected**: changed in every season and every statistic.

---

## V3-3 · Context and results

Covers `FR-024` to `FR-031`, `US3`, `SC-008`.

1. Set a game's date, opponent, location and court; confirm all four appear wherever the game does.
2. Correct the opponent after the game has ended. **Expected**: applies; nothing else changes.
3. Record two games on the same date against different opponents. **Expected**: both kept, distinct.
4. End a match and mark it won — one tap. **Expected**: recorded.
5. End a match without marking. **Expected**: undecided, not a loss.
6. Win two matches of three. **Expected**: game shows as won.
7. Open the Season screen. **Expected**: wins and losses, plus a per-opponent breakdown.

---

## V3-4 · The five paper games

Covers `FR-035` to `FR-042`, `US4`, `SC-004`, `SC-006`.

1. Import `specs/003-seasons-and-career/historical-games.json`.

**Expected**: five games added in one action, each with its date, opponent, location, court and notes, and per-player serve figures. Nothing typed.

2. Compare each game's totals against the transcription note on it.
   **Expected**: 37/15, 42/15, 42/17, 42/19, 32/10 — reconciling with the handwritten sheets.
3. Import a file naming a player not on the roster.
   **Expected**: refused, that player named, **nothing** imported.
4. Import a malformed file, and an unrelated JSON file.
   **Expected**: refused with plain reasons; recorded data untouched — verify by reading it afterwards.
5. Import a file with a negative count. **Expected**: refused.
6. Open a historical game on the tracking screen. **Expected**: not offered for serve-by-serve recording.
7. Correct a figure on a historical game. **Expected**: applies; totals follow.

> ⚠️ The 29 August game is in the import file **and** already tracked in the app. Importing both double-counts the season. Confirm the app prevents or flags this.

---

## V3-5 · Statistics tell the truth about what was never recorded

Covers `FR-043` to `FR-051`, `US5`, `US7`, `SC-005`, `SC-007`, `SC-010`.

1. With five historical and one tracked game in a season, open the Season screen.

**Expected**: serves, serves in and in-percentage span all six games. Points, turns taken and turns on court are **labelled as covering the tracked game only**, and are **never shown as zero** for a historical game.

2. Add each player's per-game figures by hand and compare with the season totals. **Expected**: exact.
3. Find a player who played no games this season. **Expected**: shown as having none, not as zeroes.
4. Open any single game. **Expected**: top scorer and top serve percentage stated, not calculated by you.
5. Check the labelling of *in* against *points*. **Expected**: unmistakably different figures.

---

## V3-6 · Notes

Covers `FR-032` to `FR-034`, `US6`, `SC-011`.

Write several paragraphs of notes on a game, force-quit, relaunch.
**Expected**: attached to that game, in full, wherever it appears. Editable afterwards.

---

## V3-7 · On the device

Covers `FR-044` and the platform contract of releases 001 and 002.

| Check | Expected |
|---|---|
| Season screen at phone width | No horizontal scroll; the tracked-only labelling readable |
| Career screen | Seasons legible side by side |
| Importing the five games | Works through the file picker on the phone |
| Airplane-mode game | Release 001 V-7 passes unchanged |
| One-tap side-out | Release 002 V2-2 passes unchanged |

---

## Deploy

```bash
git push origin feature/seasons-and-career
gh pr create --base main
```

**Bump `CACHE` in `sw.js`** and add every new source file to the precache list. `tests/unit/sw.test.js` fails if one is missed.

---

## Definition of done

| # | Claim | Evidence |
|---|---|---|
| 1 | Release-002 data survives, figures identical, now a season | V3-1 on the device |
| 2 | Migration proven against both committed fixtures | `npm test` |
| 3 | A number resolves through the season, never the player | V3-2 |
| 4 | Five paper games imported in one action, totals reconciling | V3-4 |
| 5 | Nothing never-recorded is ever displayed as zero | V3-5 |
| 6 | A bad import changes nothing | V3-4 |
| 7 | `ui → state → domain` still holds; no rule in `src/ui/` | Source review |
| 8 | Releases 001 and 002 have not regressed, airplane mode included | V3-7 |
| 9 | `CHANGELOG.md` updated | Article VI |
