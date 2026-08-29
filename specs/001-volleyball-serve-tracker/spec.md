# Feature Specification: Volleyball Serve Tracker

**Feature Branch**: `feature/volleyball-serve-tracker`

**Created**: 2026-08-29

**Status**: Draft

**Input**: User description: "Volleyball serve tracking application. Roster of up to 20 people. Each game consists of 3 matches to 21 using rally scoring. Fill out roster and tap to record a serve. Track total serves, total serves IN, total points earned, and how many times a person rotates into the serving position. A person could serve up to 5 serves before rotating out, then come back for a second serving session. Sometimes the ref miscounts and a server gets more than 5 consecutive serves — that must still be tracked. Each serve turn should be visually distinguished, likely by color in a tally system. Track serves per turn, per match, and per game. Must run offline on iOS."

## Overview

A single-purpose, offline-first mobile application used courtside on an iPhone to record volleyball serve outcomes in real time and report serving performance per player, per serve turn, per match, and per game.

The operator is a coach, parent, or bench statistician standing at the sideline, holding the phone in one hand, watching live play. Every design decision defers to that context: the app must be usable at a glance, with one thumb, with no network, and with no opportunity to correct a mistake later.

**This is a mobile-first application.** The iPhone portrait viewport is the design target, not an adaptation of a larger layout. Any behavior that only works with a mouse, a keyboard, a hover state, a wide screen, or a network connection is out of scope by definition.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Set up the team roster (Priority: P1)

Before the first game, the operator enters the team's players so they can be tapped quickly during play. Each player has a name and a jersey number. The roster holds up to 20 players, but a team of 9 shows exactly 9 entries — never blank filler rows.

The roster is saved on the device and reused for every future game without re-entry. It can be corrected mid-game when a player is added late or a number was typed wrong.

**Why this priority**: Nothing can be recorded without a roster. It is the entry point to every other capability, and it is the only screen the operator uses before the whistle, when there is time to type.

**Independent Test**: Add nine players with names and numbers, close the app entirely, reopen it, and confirm all nine appear in order with no empty rows and no data loss.

**Acceptance Scenarios**:

1. **Given** an empty roster, **When** the operator adds a player with a name and jersey number, **Then** that player appears in the roster list and is immediately available to select as a server.
2. **Given** a roster containing 9 players, **When** the operator views the roster, **Then** exactly 9 player entries are displayed and no empty or placeholder rows are shown.
3. **Given** a roster containing 20 players, **When** the operator attempts to add a 21st, **Then** the app prevents the addition and explains that 20 is the maximum.
4. **Given** a saved roster, **When** the app is fully closed and reopened, **Then** the roster is restored exactly as it was.
5. **Given** a game already in progress, **When** the operator edits a player's name or number, **Then** the change is reflected everywhere that player appears, and all previously recorded serves for that player remain attached to them.
6. **Given** a player who has already recorded serves in the current game, **When** the operator attempts to delete that player, **Then** the app warns that recorded serves will be lost and requires confirmation.

---

### User Story 2 - Record serves during live play (Priority: P1)

During a match the operator taps the serving player, then taps one of three outcome buttons for each serve: **OUT**, **IN — no point**, or **IN — POINT**. That is the entire interaction loop, and it must be completable without looking away from the court for more than a moment.

A serve turn ends automatically when a serve does not win the point, because in rally scoring any lost rally surrenders the serve. A serve turn also ends when the operator taps a different player, which signals the previous server's turn is over.

Every recorded action can be undone. Mis-taps are inevitable at the speed of live play, and an unrecoverable mis-tap would corrupt the whole match record.

**Why this priority**: This is the product. Every other capability exists to serve or report on this loop.

**Independent Test**: Record a sequence of serves for two players through several side-outs, undo the last three actions, and confirm the app returns exactly to its prior state each time.

**Acceptance Scenarios**:

1. **Given** a match in progress with no active server, **When** the operator taps a player, **Then** that player becomes the active server, a new serve turn begins for them, and the three serve outcome buttons become available.
2. **Given** an active server, **When** the operator records **IN — POINT**, **Then** the serve is counted as a serve, as a serve in, and as a point earned; the same player remains the active server; and their current turn continues.
3. **Given** an active server, **When** the operator records **IN — no point**, **Then** the serve is counted as a serve and as a serve in but earns no point, the current serve turn ends, and the app returns to awaiting selection of the next server.
4. **Given** an active server, **When** the operator records **OUT**, **Then** the serve is counted as a serve but not as a serve in and earns no point, the current serve turn ends, and the app returns to awaiting selection of the next server.
5. **Given** an active server mid-turn, **When** the operator taps a different player, **Then** the current server's turn is ended without recording a serve, and a new turn begins for the newly tapped player.
6. **Given** any recorded serve, **When** the operator triggers undo, **Then** the most recent action is reversed, every derived statistic updates accordingly, and turn boundaries are restored to their prior state.
7. **Given** an undo that reverses the first serve of a turn, **When** the undo completes, **Then** that empty turn is removed rather than left as a zero-serve turn.
8. **Given** the app is awaiting the next server, **When** the operator views the screen, **Then** it is unambiguous that a side-out occurred and no serve can be recorded until a server is selected.

---

### User Story 3 - Operate offline on a phone, one-handed (Priority: P1)

The app is installed to the iPhone Home Screen and launched like any other app. It runs in a gymnasium with no usable network. It must work identically in airplane mode as it does on Wi-Fi, because the operator has no way to know or fix connectivity mid-match.

The operator holds the phone in one hand and taps with that hand's thumb while standing and watching play.

**Why this priority**: A tracker that stalls or loses data when the signal drops is worse than a paper tally sheet. Offline operation is a correctness requirement, not a convenience.

**Independent Test**: Install the app, enable airplane mode, force-quit, relaunch, complete a full three-match game, and confirm every screen and every statistic works and persists with no network access at any point.

**Acceptance Scenarios**:

1. **Given** the app has been installed to the Home Screen, **When** it is launched with the device in airplane mode, **Then** it starts and every screen functions normally.
2. **Given** the app is running with no network, **When** the operator records serves and ends matches, **Then** all data is saved on the device and survives a force-quit and relaunch.
3. **Given** the app is launched from the Home Screen, **When** it opens, **Then** it fills the screen without browser address bars or navigation chrome.
4. **Given** the phone is held in portrait, **When** the device is rotated, **Then** the interface remains in portrait and does not reflow into a landscape layout.
5. **Given** the operator is holding the phone one-handed, **When** they record a serve, **Then** the serve outcome controls are reachable in the lower portion of the screen without repositioning their grip.
6. **Given** any interactive control, **When** it is measured, **Then** it meets or exceeds the platform minimum touch target size, and the three serve outcome buttons are substantially larger than that minimum.
7. **Given** the operator taps rapidly or imprecisely, **When** taps land on or near controls, **Then** the page does not zoom, scroll horizontally, or trigger a pull-to-refresh.
8. **Given** a device with a notch or home indicator, **When** any screen is displayed, **Then** no control or content is obscured by system UI.

---

### User Story 4 - See serve turns distinguished at a glance (Priority: P2)

Each serve is shown as a tally mark. Every serve turn is drawn in a different color from a repeating palette, so a player who served twice in a match shows two visually distinct clusters rather than one undifferentiated run of marks.

The league expects a server to rotate out after 5 consecutive serves, but referees miscount. A turn that runs past 5 serves is recorded in full and marked as unusual — never truncated, never silently corrected.

**Why this priority**: The raw counts are usable without this, but distinguishing turns visually is the operator's stated reason for tracking turns at all, and the over-5 flag is how miscounts get caught while the game is still running.

**Independent Test**: Record two separate serve turns for the same player in one match, confirm the two turns render in different colors, then record a turn of 7 serves and confirm all 7 marks appear and the turn is visibly flagged.

**Acceptance Scenarios**:

1. **Given** a player has taken two serve turns in a match, **When** their tally is displayed, **Then** the marks from each turn are shown in different colors and are visually grouped by turn.
2. **Given** consecutive serve turns anywhere in a match, **When** their tallies are displayed, **Then** no two adjacent turns share the same color.
3. **Given** more serve turns in a match than the palette has colors, **When** the palette is exhausted, **Then** colors repeat from the start without adjacent turns colliding.
4. **Given** a serve turn reaches 6 or more serves, **When** the tally is displayed, **Then** that turn is visibly flagged as exceeding the expected 5-serve limit and every serve in it remains recorded.
5. **Given** any serve turn, **When** it is displayed, **Then** the number of serves and the number of serves in for that specific turn are readable without navigating away.
6. **Given** a tally mark, **When** it is displayed, **Then** the serve outcome it represents is distinguishable from the other two outcomes by more than color alone.

---

### User Story 5 - Review statistics per match and per game (Priority: P2)

A game is three matches. The operator reviews serving performance for a single serve turn, for a whole match, and for the game as a whole. Reported per player: total serves, total serves in, serve-in percentage, total points earned, and the number of serve turns taken.

**Why this priority**: The reporting is the payoff, but it is consumed after play rather than during it, so it can follow the recording loop.

**Independent Test**: Complete three matches with known serve sequences, then verify that each per-match statistic matches a hand tally and that the game totals equal the sum of the three matches.

**Acceptance Scenarios**:

1. **Given** a match with recorded serves, **When** the operator views match statistics, **Then** each player who served shows total serves, serves in, serve-in percentage, points earned, and turns taken for that match.
2. **Given** a completed game of three matches, **When** the operator views game statistics, **Then** each player's totals equal the sum of their three per-match totals.
3. **Given** a player who did not serve in a match, **When** match statistics are displayed, **Then** that player is either omitted or clearly shown as having no serves, and never shown with misleading values.
4. **Given** a player with zero serves, **When** serve-in percentage is displayed, **Then** the app shows a non-numeric indicator rather than a division-by-zero result.
5. **Given** a match in progress, **When** the operator views statistics, **Then** the figures reflect every serve recorded so far in that match.
6. **Given** a match reaches the target score, **When** the operator views the match, **Then** the app indicates the target has been reached but does not end the match automatically.
7. **Given** a match the operator considers finished, **When** they end the match explicitly, **Then** its statistics are frozen and the next match of the game begins.
8. **Given** three matches have ended, **When** the operator views the game, **Then** the game is complete and no fourth match can be started within it.

---

### Edge Cases

- **Mis-tapped server.** The operator taps the wrong player and immediately realizes it. Undo must return the app to awaiting-server state with no orphaned empty turn left behind.
- **Turn ended by player switch with zero serves.** A player is selected and then a different player is selected before any serve is recorded. No zero-serve turn should be persisted or counted toward turns taken.
- **Referee miscount.** A server takes 7 consecutive serves. All 7 are recorded, the turn is flagged, and no statistic is capped at 5.
- **Same player serves back-to-back turns.** A player's turn ends on a side-out and the same player is later selected again in the same match. This counts as two turns, colored differently, and both count toward their turns-taken total.
- **Match ends mid-turn.** The operator ends the match while a server is active. The in-progress turn is closed and retained with the serves it already has.
- **Score passes the target without a two-point margin.** The app indicates the target is reached but never forces the match to end, because play continues until the margin is met and only the operator knows the opponent's score.
- **Player deleted mid-game.** Deleting a player with recorded serves requires confirmation, because their match history is destroyed with them.
- **App killed mid-match.** The operating system terminates the app between serves. On relaunch, the current game, match, active server, and every recorded serve are restored.
- **Storage unavailable or full.** The device refuses to persist data. The operator is told plainly that recording is not being saved, rather than the app silently discarding serves.
- **Undo at the start of a match.** Undo is triggered when nothing has been recorded in the current match. The app does nothing and does not reach backward into a previous, already-frozen match.
- **Repeated rapid taps.** The operator double-taps an outcome button. Only one serve is recorded per deliberate tap.
- **Roster reduced below the players in an active game.** A roster edit removes players while a game is running. Recorded statistics for the affected players are handled per the deletion confirmation, and no other player's data is disturbed.

## Requirements *(mandatory)*

### Functional Requirements

#### Roster

- **FR-001**: System MUST allow the operator to create a roster of players, where each player has a name and a jersey number.
- **FR-002**: System MUST limit a roster to a maximum of 20 players and prevent adding beyond that limit with a clear explanation.
- **FR-003**: System MUST display only players that have actually been entered, and MUST NOT render empty, placeholder, or filler player entries.
- **FR-004**: System MUST persist the roster on the device so it is available in future sessions without re-entry.
- **FR-005**: Operators MUST be able to add, edit, and remove players at any time, including while a game is in progress.
- **FR-006**: System MUST require explicit confirmation before removing a player who has recorded serves in the current game, stating that their recorded data will be lost.
- **FR-007**: System MUST preserve the association between a player and their recorded serves when that player's name or number is edited.

#### Game and match structure

- **FR-008**: System MUST organize play as a game consisting of exactly three matches.
- **FR-009**: System MUST treat a match as played to a target of 21 points under rally scoring, with a required winning margin of two points.
- **FR-010**: System MUST NOT end a match automatically; ending a match MUST be an explicit operator action.
- **FR-011**: System MUST display a clear visual indication once the target score has been reached, without blocking further recording.
- **FR-012**: System MUST freeze a match's statistics when it is ended and advance to the next match in the game.
- **FR-013**: System MUST prevent starting a fourth match within a game that already has three ended matches.
- **FR-014**: System MUST NOT require or record the opposing team's score.

#### Serve recording

- **FR-015**: Operators MUST be able to designate the active server by tapping a player from the roster.
- **FR-016**: System MUST record each serve with exactly one of three outcomes: out, in without a point, or in with a point.
- **FR-017**: System MUST count every recorded serve toward the serving player's total serves.
- **FR-018**: System MUST count a serve toward total serves in when its outcome is in with a point or in without a point.
- **FR-019**: System MUST count a serve toward points earned only when its outcome is in with a point.
- **FR-020**: System MUST keep the same player as the active server after a serve that earns a point.
- **FR-021**: System MUST end the active serve turn after any serve that does not earn a point, and return to awaiting selection of the next server.
- **FR-022**: System MUST make the awaiting-next-server state visually unmistakable and MUST NOT accept a serve outcome while in that state.
- **FR-023**: System MUST prevent a single tap from recording more than one serve.

#### Serve turns

- **FR-024**: System MUST group consecutive serves by the same player into a single serve turn.
- **FR-025**: System MUST begin a new serve turn when a player is designated as active server.
- **FR-026**: System MUST end the current serve turn when the operator designates a different player as active server, without recording a serve for that transition.
- **FR-027**: System MUST NOT persist or count a serve turn that contains zero serves.
- **FR-028**: System MUST count the number of serve turns each player takes, per match and per game.
- **FR-029**: System MUST record every serve in a turn regardless of how many serves the turn contains, and MUST NOT cap, truncate, or discard serves beyond the expected limit of five.
- **FR-030**: System MUST visually flag any serve turn containing more than five serves as exceeding the expected rotation limit.

#### Visual representation

- **FR-031**: System MUST represent each recorded serve as an individual tally mark.
- **FR-032**: System MUST assign each serve turn a color from a repeating palette so that tally marks are grouped by turn.
- **FR-033**: System MUST ensure that two consecutive serve turns are never assigned the same color.
- **FR-034**: System MUST distinguish the three serve outcomes by a means other than color alone.
- **FR-035**: System MUST display the serve count and serves-in count for each individual serve turn, not only aggregate totals.

#### Statistics

- **FR-036**: System MUST report, per player and per match: total serves, total serves in, serve-in percentage, total points earned, and total serve turns taken.
- **FR-037**: System MUST report the same statistics aggregated across all three matches of a game.
- **FR-038**: System MUST update in-progress match statistics immediately as serves are recorded.
- **FR-039**: System MUST display a non-numeric indicator rather than an error or zero when serve-in percentage is undefined because no serves were attempted.

#### Correction

- **FR-040**: Operators MUST be able to undo the most recent recorded action at any point during a match.
- **FR-041**: System MUST restore all derived statistics and all serve turn boundaries to their exact prior state when an action is undone.
- **FR-042**: System MUST remove a serve turn that becomes empty as a result of an undo.
- **FR-043**: System MUST NOT allow undo to modify a match that has already been ended.

#### Mobile-first interaction

- **FR-044**: System MUST be designed for a phone screen held in portrait orientation as its primary and only target form factor.
- **FR-045**: System MUST remain in portrait orientation regardless of device rotation.
- **FR-046**: System MUST place the serve outcome controls within one-thumb reach in the lower portion of the screen.
- **FR-047**: System MUST size every interactive control at or above the platform minimum touch target size, and MUST size the serve outcome controls substantially larger than that minimum.
- **FR-048**: System MUST NOT depend on hover, right-click, keyboard input, or any other non-touch interaction for any capability.
- **FR-049**: System MUST suppress double-tap zoom, pinch zoom, and pull-to-refresh so that imprecise taps cannot disrupt the interface.
- **FR-050**: System MUST present all content without requiring horizontal scrolling or zooming to read.
- **FR-051**: System MUST respect device safe areas so that no content or control is obscured by a notch, status bar, or home indicator.
- **FR-052**: System MUST remain legible under bright gymnasium lighting, with high contrast between text, tally marks, and their backgrounds.

#### Offline operation and installation

- **FR-053**: System MUST be installable to the phone's Home Screen and launchable as a standalone app without visible browser chrome.
- **FR-054**: System MUST function completely with no network connection available, with no capability degraded or unavailable.
- **FR-055**: System MUST NOT make any network request during normal operation after installation.
- **FR-056**: System MUST store all data locally on the device.
- **FR-057**: System MUST restore the in-progress game, match, active server, and all recorded serves after the app is closed, terminated, or relaunched.
- **FR-058**: System MUST notify the operator explicitly if data cannot be saved, rather than discarding recorded serves silently.

### Key Entities

- **Player**: A person on the team who can serve. Has a name and a jersey number. Belongs to exactly one roster. Persists across games.
- **Roster**: The ordered collection of players available to select as servers. Holds between zero and twenty players. Persists on the device between sessions.
- **Game**: A single outing consisting of exactly three matches. Aggregates statistics across its matches.
- **Match**: One of the three contests within a game, played to a target of 21 with a two-point margin. Contains an ordered sequence of serve turns. Is either in progress or ended; ended matches are immutable.
- **Serve Turn**: A single continuous session of one player occupying the serving position within one match. Belongs to exactly one player and one match. Has an ordinal position within the match, an assigned display color, and an ordered sequence of serves. Is flagged when it contains more than five serves. Never contains zero serves.
- **Serve**: One recorded serve attempt. Belongs to exactly one serve turn. Has exactly one outcome: out, in without a point, or in with a point.
- **Serve Statistics**: Derived figures — total serves, serves in, serve-in percentage, points earned, and turns taken — computed at serve turn, match, and game scope. Never stored independently of the serves they derive from.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An operator can record a serve outcome in a single tap, and a complete side-out sequence in no more than two taps, while watching live play.
- **SC-002**: An operator can record every serve of a full three-match game without ever looking away from the court for more than two seconds per action.
- **SC-003**: The app completes a full three-match game with the device in airplane mode from launch to finish, with zero capabilities unavailable and zero data lost.
- **SC-004**: All recorded data survives a force-quit and relaunch at any point during a game, in 100% of trials.
- **SC-005**: An operator can enter a roster of 12 players in under 3 minutes on a phone keyboard.
- **SC-006**: Every per-match and per-game statistic matches an independent hand tally of the same serve sequence exactly, with no discrepancy.
- **SC-007**: A player's separate serve turns within one match are correctly identified as distinct by an observer looking at the tally display for under 5 seconds.
- **SC-008**: 100% of serves in turns exceeding five serves are retained and reported, and every such turn is flagged.
- **SC-009**: Any mis-tap can be fully reversed by an operator within 3 seconds of making it.
- **SC-010**: Every interactive control is operable with the thumb of the hand holding the phone, without a second hand and without changing grip.
- **SC-011**: No screen requires horizontal scrolling, zooming, or rotation to read or operate on a phone in portrait.

## Assumptions

- **Mobile-first is binding, not aspirational.** The phone in portrait is the only supported form factor. Larger screens are not a target, and no capability may be reserved for them.
- **Offline-first, not offline-tolerant.** The app is assumed to run with no network at all times. Network availability is never a precondition for any behavior, and airplane mode is the primary test condition rather than an edge case.
- **Single operator, single device.** One person records for one team on one phone. There is no multi-user access, no account, no sign-in, and no synchronization between devices.
- **Local storage only.** All data lives on the device. There is no server, no backup, and no cloud restore; losing or wiping the device loses the data.
- **The operator's own team only.** Serves are recorded exclusively for the roster's players. The opposing team is not modeled in any form.
- **Match score visibility.** Because the opponent's score is not tracked, the app cannot determine on its own when the two-point margin has been met. The target-reached indicator is advisory, and the operator decides when a match is actually over using the official scoreboard.
- **Turn end follows rally scoring.** Any serve that does not earn a point is assumed to surrender the serve, and therefore ends the serve turn. This is what makes automatic turn detection possible without additional input.
- **The five-serve limit is a league expectation, not a rule the app enforces.** It exists in the app only as a flag for spotting referee miscounts, and never as a constraint on what can be recorded.
- **Statistics are always derived.** Totals are computed from the recorded serves rather than stored separately, so undo and edits cannot leave figures out of step with the underlying record.
- **Data volume is small.** A game is at most a few hundred serves, so no pagination, archiving, or performance tiering is needed.
- **Game history beyond the current game is out of scope for the first release.** The roster persists; completed games are retained on the device but no cross-game trend reporting, export, or sharing is included.
