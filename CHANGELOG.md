# Changelog

All notable changes to this project are recorded here.

## [Unreleased]

### Added — Volleyball Serve Tracker (`feature/volleyball-serve-tracker`)

The first release: an offline-first, installable web app for recording volleyball serve
outcomes courtside on a phone.

**Recording**

- Tap the serving player, then one of three outcomes: `OUT`, `IN — no point`, `IN — POINT`.
  A point keeps the same server; anything else is a side-out and closes the turn.
- Serve turns are inferred, never typed. A turn also closes when a different player is
  tapped, so a full side-out costs at most two taps.
- The side-out state disables the outcome controls outright rather than ignoring taps, so a
  serve cannot be recorded against the wrong player.
- Undo on every action. It works by dropping the last event and replaying the log, so
  statistics, turn boundaries, and turn colours all return to exactly their prior state, and
  a turn emptied by an undo disappears rather than lingering with zero serves.
- A repeat tap within 300 ms is treated as a stray double-tap and ignored — two serves
  cannot physically occur that close together.

**Serve turns and the five-serve limit**

- Each serve renders as its own tally mark, grouped by turn, with a different colour per
  turn from a six-colour palette. Consecutive turns can never share a colour.
- Outcomes are distinguished by mark shape, not colour, so the board is readable without
  colour vision.
- Turns running past five serves are recorded in full and flagged. Nothing is ever capped,
  truncated, or silently corrected — referees miscount, and the record should show it.

**Roster**

- Up to 20 players, each with a name and a jersey number. Jersey numbers are text, so a
  leading zero survives.
- Only entered players are displayed; there are no placeholder rows.
- Editable at any time, including mid-game. Editing a name or number keeps every recorded
  serve attached to that player.
- Removing a player requires a second, deliberate tap and states that their recorded serves
  will be discarded.

**Statistics**

- Serves, serves in, in percentage, points, and turns taken — at turn, match, and game
  scope. Game totals are the sum of the three matches by construction.
- A player who attempted no serves shows a dash, never `0%` or `NaN`.
- Everything is derived from the recorded serves on read; no total is stored separately, so
  none can drift.

**Offline and install**

- Installs to the Home Screen and launches standalone, portrait-locked, with safe-area
  insets respected.
- A hand-written service worker precaches an explicit list of every file in the tree and
  serves cache-first, so after install the app issues no network requests at all.
- All data lives on the device in `localStorage` behind a single adapter. The in-progress
  game, current match, active server, and every serve survive a force-quit.
- A storage failure raises a visible warning and keeps recording in memory rather than
  discarding serves silently.

**Mobile-first**

- The phone in portrait is the only supported form factor, not an adaptation of a wider
  layout. Outcome controls sit in the thumb zone; every control is at least 44 pt; double-tap
  zoom, pinch zoom, and pull-to-refresh are suppressed.

### Known limitations

- The opponent's score is deliberately not tracked, so the app cannot determine the
  two-point margin on its own. It shows points earned on serve, flags when that figure
  reaches 21, and leaves ending the match to the operator reading the scoreboard.
- Only the current game is reviewable. Completed games are retained on the device, but there
  is no cross-game reporting, export, or sharing yet.

### Technical notes

- No runtime dependencies, no bundler, no backend. The repository root is the deployed
  artifact, which is what keeps the service worker's precache list auditable by reading it.
- State is an append-only event log reduced by a pure function. Imports point one direction
  only: `ui → state → domain`.
- 177 tests. Unit coverage of the whole domain and every render function; the storage
  adapter exercised against a real `Storage`; a journey test that drives the real UI
  against a real DOM; and a check that the service worker precaches every shipped file,
  because a missing entry there fails only on a phone in airplane mode.
- Specification, plan, and validation scenarios live in
  `specs/001-volleyball-serve-tracker/`.
