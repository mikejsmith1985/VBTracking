# Changelog

All notable changes to this project are recorded here.

## [Unreleased]

### Added

- **An import file holding games 1–4 only**, at `import/paper-games-1-4.json`. The 29 August
  game is already tracked in the app, so importing the complete five-game transcription
  would count it twice. The full five-game file stays as the record of what the sheets said.
  Both are covered by tests: every game must parse, every player must resolve against the
  roster, and every total must still reconcile with the figures written on the paper.
- **Any game can be discarded from its own record**, not only the one in progress. A game
  entered twice — the same match tracked live and also imported from paper — would
  otherwise count twice in the season with no way to undo it. Two taps, and the
  consequence is stated before the second.

### Added

- **The running version is shown** at the bottom of the Season screen. Nine releases went
  out in a day with no way for whoever was holding the phone to tell a broken fix from a
  stale copy. Now there is.
- **A new version lands on the first launch, not the second.** The page reloads itself once
  when a new service worker takes over. Waiting for a second launch looks exactly like a fix
  that did not work, and cost a round of "it is still broken" every release.
- **Games can be pasted instead of imported from a file.** On iOS, saving a JSON file from
  Safari lands it as `.json.txt`; opening it, selecting all and pasting is both shorter and
  harder to get wrong than the file round trip.

### Fixed

- The version badge module was briefly emptied by a bad in-place edit during this change.
  The test asserting it matches the service worker cache caught it at once — which is why
  that test checks agreement rather than mere existence.
- **The import no longer demands that two people typed a name the same way.** The roster is
  typed on a phone before a match; the file is transcribed from handwriting afterwards.
  Requiring "Layna" and "Layna Blankenship" to agree character for character is a rule the
  data cannot keep. Names are now matched by full name, then through the jersey number the
  file declares, then by first name.
- Ambiguity is still refused rather than guessed: if two players answer to one first name,
  the import stops and says so. Putting a serve against the wrong child is worse than asking.
- A failed match now **names the roster it was matched against**, so the mismatch can be
  seen instead of guessed at.
- **The file picker refused the file iOS had just saved.** It filtered on
  `application/json`, and iOS names the download `.json.txt` — so the file was greyed out
  and could not be chosen at all. The picker now sets no `accept` attribute at all, not even
  an empty one. The parser reads the
  contents and refuses anything that is not ours with a plain reason, so a guess at an
  extension must never be what stands between the operator and their own data.
- **Every submit button in the app was broken.** Save, Create, Add player and the game
  form did nothing when pressed. A click on anything without an action triggered a full
  redraw, which destroyed and rebuilt the form before the browser's own submit event could
  fire. Pressing Enter in a field still worked, which is why it went unnoticed. A stray tap
  now redraws only when it actually changed something, and never from inside a form.
- The whole test suite missed it because every form test dispatched a `submit` event
  directly, sailing straight past the click handler. Forms are now driven by **clicking the
  button a thumb would land on**; with the bug reintroduced, 10 of those 13 tests fail.
- **The Season screen no longer drifts off the right edge of a phone.** The season name,
  team and Save button sat on one row; a grid child defaults to `min-width: auto`, so the
  inputs refused to shrink below their own content and pushed Save off-screen entirely.
  The button now sits beneath the two fields, and every grid that holds text was given the
  `min-width: 0` it needed.
- **Stacked buttons no longer touch.** "Enter a game by hand" and "Import a batch of games"
  ran flush together and read as a single control. Eight points between them, and headings
  that follow a paragraph now have room to read as a new section.
- Checked at 393 px — an iPhone's logical width — across all seven screens: nothing extends
  past the right edge and nothing scrolls sideways.

### Changed

- Airplane-mode verification is no longer a release gate, at the stakeholder's decision: a
  native iOS app is expected before connectivity in a gymnasium matters. The app remains
  offline-capable — the service worker and the precache-completeness test are unchanged —
  but offline behaviour is no longer proven on the device before shipping.

### Added — Seasons, Career Players, and Game Context (`feature/seasons-and-career`)

**A player is now a person, and the number belongs to the season**

- A player is a career identity that outlives every roster. The jersey number moved onto
  the season's roster entry, where it belongs — next year the same child plays for a
  different team wearing a different number, and she is still the same child.
- Seasons have a name and a team. A player joins one either from the people already
  recorded or as someone new. Removing them from a season no longer deletes anything:
  the person stays, and every serve they recorded stays theirs.
- Switching seasons is refused while a game is under way, and says so.
- A season records the format it was played under, so a later release can vary matches per
  game or players on court without touching stored data.

**Everything already recorded became a season, with nothing lost**

- The first migration that does real work. It prepends one season and stamps a field onto
  the events that now need one. It renames nothing and splits nothing: the tidier migration
  shifts every index, which turns a bug into silent corruption of the only real season
  anyone has recorded.
- Proven against two committed fixtures — a release-001 log and a release-002 log, the
  latter carrying lineups, a rotation and a substitution — replaying to identical figures.
- No past match was retroactively declared lost. They are all undecided, because silence
  is not a defeat.

**Who was played, where, and how it went**

- Every game records a date, an opposing team, a location and a court, editable at any
  time including long after the game.
- Ending a match asks how it went, in the same tap. The game's result follows from its
  matches. An unmarked match counts toward neither side.
- The Season screen gives a win-loss record and a breakdown by opponent.
- Notes on every game — what went well, what to work on — because that is on every paper
  sheet, which is a stronger statement of what matters than anything anyone could say.

**The games from before the app existed**

- A game can be entered from paper: per player, serves in and serves out, at game level.
- A prepared batch imports in one action. Players are matched by name against the season's
  roster, and an unknown name aborts the whole import naming that player — a typo must not
  quietly invent a tenth person on a nine-player squad.
- All or nothing. A partial import would leave the operator unable to tell what landed.

**Statistics that admit what they do not know**

- Serves, serves in and serve percentage span every game. Points, turns and time on court
  cover the tracked games only, and the table says so in as many words.
- A figure that was never recorded shows as a dash. Never a zero — a zero would say the
  player served and won nothing, and would report worse figures than they earned.
- A career view: one player across every season, each with its own team and number, plus a
  combined total.
- Top scorer and top serve percentage are computed rather than tallied by hand at the
  bottom of a page.

### Added — Rotation, Substitutions, and Durable Data (`feature/rotation-and-subs`)

**Your data survives the upgrade**

- Games recorded on the previous release load unchanged, with nothing to confirm or
  re-enter. Verified against a log written by the shipped release-001 build and kept as a
  test fixture, so the check is against the format as shipped rather than as remembered.
- Stored data now carries a version and is carried forward on load through an ordered
  migration chain. The 1 to 2 step does nothing, because this release only adds event
  types — the point is that the mechanism is proven to run before a release needs it to do
  real work.
- Data written by a newer version is refused, explained, and left untouched rather than
  loaded or overwritten.
- If the carried-forward log cannot be written back, the app keeps running from what it
  read and leaves the original alone. A failed write is never worse than not trying.

**Backup and restore**

- **Save a backup file** on the Stats screen, in one action. On a phone it opens the
  native share sheet, so Save to Files is one tap; elsewhere it downloads.
- **Restore from a backup** replaces everything on the device, after a second deliberate
  tap that says so.
- A damaged, truncated, or unrelated file is refused with a plain explanation and changes
  nothing. A backup from a newer version is refused; one from an older version is carried
  forward like any stored data.

**The rotation serves for you**

- A match takes an ordered lineup of the six on court. It is per match, not per game — with
  nine on the roster three sit out, and who sits out changes every match. Matches 2 and 3
  open prefilled from the previous match, editable before the first serve.
- When a turn ends, the next player in the order becomes the server with no action taken.
  **A side-out is now one tap instead of two**, and the dock stays on the outcome controls
  instead of swapping to the picker.
- One undo still reverses one operator action: the serve and the advance it caused are
  reversed together. The advance is part of the serve transition rather than an event of
  its own, so this holds by construction.
- Any player can be chosen to override the order, and the rotation carries on from them.
- Serving from outside the lineup — usually a substitution not yet entered — is recorded
  and marked rather than refused, and it takes over the position that was due, so the order
  does not lag by one for the rest of the match.
- A lineup is optional. Below six players, or after skipping, the app behaves exactly as
  the previous release did.

**Substitutions**

- Double-tap a player on court, then tap whoever replaces them. They take that exact slot
  in the serving order, and the rotation follows.
- Serves already recorded stay with the player who took them, including when the
  substitution replaces the player mid-turn.
- Refused when the incoming player is already on court, is not on the roster, or is the
  same player. Undoable. A player who came off can come back on.
- Each match lists its substitutions: who came off, who came on, and at what point.

**Reading at arm's length**

- Player buttons now show one large jersey number instead of a number and a clipped name.
  Three characters and an ellipsis was never a name; the number is what you scan for.
  Full names stay on the tally board and in every statistics view.
- The current server is shown at display size, because the app chooses them now and a wrong
  one is the app's mistake to make obvious.
- New statistic: turns on court, counting turns a player was in the lineup for whether or
  not they served — which distinguishes sitting out from never reaching the service slot.

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

**Discarding a game**

- A game and every serve in it can be thrown away from the Stats screen, which is where
  test data gets noticed and is safely away from anything tapped during a rally.
- Two deliberate taps, with the consequence stated before the second. The roster survives.
- Discarding is an event like any other, so it replays deterministically and no statistic
  anywhere still counts the discarded game.

### Changed

- **The side-out announcement is gone.** A turn can only end two ways — a serve that wins
  no point, or a different player being chosen — so the state needs no banner. The dock is
  now a thin status row over exactly one action block: the outcome controls, or the player
  picker. Never both, and never a dimmed copy of either.
- Between servers, the picker stands where the outcome controls normally are. That swap is
  the signal, readable across a court without reading a word, and it makes recording a
  serve against the wrong player structurally impossible rather than merely discouraged —
  no control capable of recording one exists.
- **168 px returned to the tally board** between servers: the dock fell from 381 px to
  213 px on a 430 px viewport with a 9-player roster. The two states now differ by 12 px,
  so the outcome controls land in the same place every time they appear.
- Tapping **Change** while serving swaps the outcome controls for the picker and becomes
  **Cancel**, keeping the one-action-block rule intact.
- Outcome control captions now read "turn ends" rather than "side out".

### Fixed

- A player selected as server no longer appears on the tally board with an empty turn box
  and a `0 served` line before they have served. A just-opened turn holds no serves yet;
  drawing it read as a mistake, and the status row already names the current server.

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
