# Feature Specification: Rotation, Substitutions, and Durable Data

**Feature Branch**: `feature/rotation-and-subs`

**Created**: 2026-08-29

**Status**: Draft

**Input**: User description: "Data persistence so I can safely update the app without losing information. Each player button could just have a larger number in it instead of number and name. Allowing a rotation so next server could be automated. A sub button — double tap a player then tap the person taking their place, with tracking. This should be per match rotation setup, as by default 3 different players sit out an entire match, making each rotation per match unique."

## Overview

The second release of the courtside serve tracker. It builds on the shipped first release and changes nothing about its context: a phone held in one hand at the sideline, no network, all data on the device.

Three things change.

**The rotation becomes known to the app.** A match gets an ordered lineup of the six players on court. Because a volleyball team only rotates when it wins the serve back, the next server after any of the team's turns is simply the next name in that order — fully derivable, with no extra input. A side-out drops from two taps to one.

**Substitutions become recordable.** A player leaving and another taking their exact place in the serve order is how a lineup actually changes during play. Until the app knows about it, an automated rotation would quietly start attributing serves to someone who is on the bench.

**The data becomes durable.** The operator is about to record games that matter. Upgrading the app must not cost them, and a lost phone should not either.

The first release's constraints carry over unchanged and are not restated as requirements here: phone-portrait only, offline-first with no network requests after install, all data local, installable and launched standalone.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Keep everything already recorded (Priority: P1)

The operator has recorded real games. They update the app. Every roster, every game, every serve is still there afterwards, without being asked to do anything.

**Why this priority**: The operator will not trust the app with a season if an update can cost them a match. Nothing else in this release is worth having if this fails, and every other story writes data in the new shape, so this must land first.

**Independent Test**: Record a game on the previous release, upgrade to this one, and confirm every player, game, match, serve turn, and statistic is identical to before the upgrade.

**Acceptance Scenarios**:

1. **Given** data recorded by the previous release, **When** the operator opens this release for the first time, **Then** every roster, game, match, serve turn, and serve is present and every statistic reports the same figures as before.
2. **Given** data recorded by the previous release, **When** it is carried forward, **Then** the operator is not asked to confirm, migrate, or re-enter anything.
3. **Given** data already carried forward once, **When** the app is opened again, **Then** it loads normally and is not carried forward a second time.
4. **Given** data written by a release **newer** than the one running, **When** the app opens, **Then** it explains that the data is from a newer version, does not load it, and does not overwrite it.
5. **Given** stored data that is corrupt or unreadable, **When** the app opens, **Then** it says so plainly and does not silently discard or partially apply it.

---

### User Story 2 - Set the lineup for a match (Priority: P1)

Before a match the operator picks the six players on court and puts them in serving order. With nine on the roster, three sit out — and who sits out changes every match, so this is set per match rather than per game.

Setting up the second and third matches starts from the previous match's lineup, because it is usually close, and edits from there.

**Why this priority**: The automated rotation has nothing to work from without it. It is also the only new setup the operator does before the whistle, when there is time.

**Independent Test**: Set a lineup of six for match 1, play it, end it, and confirm match 2 opens prefilled with match 1's lineup and is editable before the first serve.

**Acceptance Scenarios**:

1. **Given** a roster of nine, **When** the operator sets a lineup, **Then** they choose exactly six players and place them in serving order.
2. **Given** a lineup being built, **When** fewer or more than six players are chosen, **Then** the lineup cannot be confirmed and the app says how many are needed.
3. **Given** a lineup being built, **When** the operator tries to add the same player twice, **Then** the app prevents it.
4. **Given** a confirmed lineup, **When** the operator picks which position serves first, **Then** that player becomes the first server of the match.
5. **Given** match 1 has ended, **When** match 2 begins, **Then** its lineup is prefilled from match 1 and can be edited before the first serve.
6. **Given** a match in progress, **When** the operator opens the lineup, **Then** they can see it, and any change takes effect through a substitution rather than by silently rewriting history.
7. **Given** a roster of fewer than six players, **When** the operator starts a match, **Then** the match is playable with no lineup and the app behaves exactly as the previous release did.
8. **Given** a match with no lineup set, **When** serves are recorded, **Then** the operator picks each server manually and nothing is automated.

---

### User Story 3 - Let the rotation pick the next server (Priority: P1)

A serve turn ends. The app moves to the next player in the lineup and makes them the server, without being asked. The operator records the next serve straight away.

The operator can always override by choosing someone else, and the rotation continues from there.

**Why this priority**: This is the release's headline: it halves the cost of the most frequent sequence in a match.

**Independent Test**: With a lineup set, record a full rotation of six serve turns using only outcome taps, and confirm the servers match the lineup order exactly.

**Acceptance Scenarios**:

1. **Given** a lineup is set and a serve turn ends, **When** the app advances, **Then** the next player in lineup order becomes the active server with no operator action.
2. **Given** the last player in the lineup has just served, **When** the turn ends, **Then** the rotation wraps to the first player.
3. **Given** the rotation has advanced, **When** the operator looks at the screen, **Then** the current server is unmistakable at arm's length so a wrong one is caught before a serve is recorded.
4. **Given** the rotation has advanced to the wrong player, **When** the operator taps a different player, **Then** that player becomes the server and the rotation continues from that player's position.
5. **Given** the operator taps a player who is not in the lineup, **When** the serve is recorded, **Then** it is recorded normally and the turn is marked as served by someone outside the lineup.
6. **Given** an automatic advance has happened, **When** the operator undoes, **Then** the serve that ended the turn and the advance it caused are both reversed in a single undo — undo reverses what the operator did, not what the app did in response.
7. **Given** no lineup is set, **When** a serve turn ends, **Then** nothing advances and the operator picks the next server, as in the previous release.

---

### User Story 4 - Substitute a player (Priority: P2)

A player comes off and another takes their place. The operator double-taps the player leaving, then taps the player coming on. The incoming player takes the outgoing player's exact position in the serving order, so the rotation carries on correctly.

**Why this priority**: Without it, an automated rotation goes wrong the first time the coach makes a change — it would keep naming a player who is sitting on the bench. It follows the rotation itself because it only matters once the rotation exists.

**Independent Test**: Substitute a player mid-match, then play through a full rotation and confirm the incoming player serves in the outgoing player's slot while the outgoing player's recorded serves are untouched.

**Acceptance Scenarios**:

1. **Given** a lineup is set, **When** the operator double-taps a player in it and then taps a player who is not, **Then** the incoming player replaces the outgoing player in that exact lineup position.
2. **Given** a substitution has been made, **When** the rotation next reaches that position, **Then** the incoming player is made the server.
3. **Given** a substitution has been made, **When** statistics are viewed, **Then** every serve the outgoing player recorded before coming off is still theirs and still counted.
4. **Given** the operator double-taps a player, **When** they then tap a player already in the lineup, **Then** the app refuses and explains that the incoming player is already on court.
5. **Given** the operator double-taps a player, **When** they tap anywhere that is not a player, **Then** the pending substitution is cancelled and nothing is recorded.
6. **Given** a substitution has been made, **When** the operator undoes, **Then** the outgoing player returns to their lineup position and the rotation continues as before.
7. **Given** the substituted-out player is the current server, **When** the substitution is made, **Then** the incoming player becomes the current server.
8. **Given** substitutions have been made, **When** the operator views match statistics, **Then** each substitution is listed with who came off, who came on, and at which point in the match.

---

### User Story 5 - Back up and restore (Priority: P2)

The operator saves everything to a file, in one action. If the phone is lost, replaced, or wiped, they restore from that file and carry on.

**Why this priority**: The upgrade path in User Story 1 protects against app updates. This protects against everything else, and it is the only way data survives a lost phone. It is used between games rather than during one, so it follows the in-match work.

**Independent Test**: Export a file, clear all app data, import the file, and confirm every roster, game, and serve returns exactly as it was.

**Acceptance Scenarios**:

1. **Given** recorded data, **When** the operator exports, **Then** a single file containing everything is produced in one action.
2. **Given** an exported file, **When** the operator imports it, **Then** every roster, game, match, serve turn, and serve is restored and every statistic matches the source.
3. **Given** existing data on the device, **When** the operator imports, **Then** the app states that importing replaces everything currently stored and requires explicit confirmation before proceeding.
4. **Given** a file that is corrupt, truncated, or not an export of this app, **When** the operator imports it, **Then** the app refuses with a plain explanation and existing data is left completely untouched.
5. **Given** a file exported by a newer version of the app, **When** the operator imports it, **Then** the app refuses and says why, without partially applying it.
6. **Given** a file exported by an older version, **When** the operator imports it, **Then** it is carried forward and loaded, exactly as stored data is.
7. **Given** an import has failed for any reason, **When** the operator returns to the app, **Then** everything that was there before the attempt is still there.

---

### User Story 6 - Read the player buttons at a glance (Priority: P3)

Player selection buttons show one large jersey number. A truncated name is not readable at arm's length; a number is, and the number is what the operator is scanning for anyway.

**Why this priority**: A clear improvement, but the app is usable without it, and the automated rotation reduces how often these buttons are touched at all.

**Independent Test**: With a twenty-player roster, confirm every player button shows a large legible number and that no name is truncated anywhere on the screen.

**Acceptance Scenarios**:

1. **Given** any player selection button, **When** it is displayed, **Then** it shows the player's jersey number at a size legible at arm's length, and no truncated name.
2. **Given** a player with no jersey number, **When** their button is displayed, **Then** they are still identifiable rather than blank.
3. **Given** the tally board or any statistics view, **When** a player appears, **Then** their full name and number are both shown, untruncated.
4. **Given** a roster of twenty, **When** the picker is displayed, **Then** every player is reachable without horizontal scrolling.

---

### Edge Cases

- **A substitute for the current server.** The player being replaced is mid-turn as the active server. The incoming player takes over as server; serves already recorded in that turn stay with the outgoing player.
- **Substituting a player back in.** A player who came off is later substituted back on, into any position. Their earlier and later serve turns are both counted, and their turns-taken total reflects both spells.
- **The same player substituted for themselves.** The operator double-taps a player then taps that same player. Nothing is recorded and the pending substitution clears.
- **Off-lineup server.** The operator picks someone not in the lineup, usually because a substitution happened on court that has not been recorded yet. The serve records normally and the turn is marked as off-lineup, so it can be spotted and corrected rather than silently absorbed.
- **Rotation drift after a referee miscount.** A server takes more turns than the rotation expects. The operator overrides by tapping the correct player, and the rotation continues from there without a reset.
- **Undo across a match boundary.** Undo is triggered immediately after a match ends. It does not reach into the ended match, and it does not undo that match's lineup.
- **Ending a match mid-substitution.** A substitution is pending — one player double-tapped, no replacement chosen — when the match ends. The pending substitution is discarded, not applied.
- **A lineup player removed from the roster.** A player in an active lineup is deleted from the roster. The deletion confirmation states that they are on court, and the lineup position is left empty rather than silently filled.
- **Fewer than six players available.** The roster cannot fill a lineup. The match is playable with manual server selection and no automation, rather than blocked.
- **Import while a match is in progress.** The operator imports during a live match. The confirmation names that the in-progress match will be replaced too.
- **Export with nothing recorded.** The operator exports an empty app. A valid, importable file is still produced.
- **Storage unavailable during migration.** Data carried forward cannot be written back. The app reports it, keeps working from what it read, and does not destroy the original.

## Requirements *(mandatory)*

### Functional Requirements

#### Carrying data forward

- **FR-001**: System MUST load and preserve all data written by any previously released version, without the operator being asked to act.
- **FR-002**: System MUST record which version of the data format it has stored, so a later release can recognise it.
- **FR-003**: System MUST carry data forward on load, in order, through every intervening format version.
- **FR-004**: System MUST NOT carry the same stored data forward more than once.
- **FR-005**: System MUST refuse to load data written by a newer version than itself, explain why, and leave that data unmodified.
- **FR-006**: System MUST report corrupt or unreadable stored data plainly and MUST NOT partially apply it.
- **FR-007**: System MUST preserve the exact statistics of carried-forward data — every serve, turn, and total identical to before.
- **FR-008**: System MUST continue operating from the data it read when carried-forward data cannot be written back, and MUST NOT destroy the original.

#### Match lineup

- **FR-009**: Operators MUST be able to set, for each match, an ordered lineup of exactly six players drawn from the roster.
- **FR-010**: System MUST prevent a lineup from being confirmed unless it holds exactly six distinct players, and MUST state what is needed.
- **FR-011**: System MUST treat the lineup as belonging to a single match, not to the game.
- **FR-012**: System MUST prefill a new match's lineup from the previous match of the same game, editable before the first serve.
- **FR-013**: Operators MUST be able to choose which lineup position serves first in a match.
- **FR-014**: System MUST allow a match to be played with no lineup, behaving as the previous release did, with manual server selection and no automation.
- **FR-015**: System MUST make the current lineup and serving order viewable during a match.
- **FR-016**: System MUST change an in-progress match's lineup only through a substitution, never by rewriting the lineup already used.
- **FR-017**: System MUST state, when a player being removed from the roster is in an active lineup, that they are on court.

#### Automatic rotation

- **FR-018**: System MUST make the next player in lineup order the active server when a serve turn ends and a lineup is set, with no operator action.
- **FR-019**: System MUST wrap the rotation from the last lineup position back to the first.
- **FR-020**: System MUST display the active server so that a wrong one is identifiable at arm's length before a serve is recorded.
- **FR-021**: Operators MUST be able to override the rotation by choosing any player, at any time.
- **FR-022**: System MUST continue the rotation from the overriding player's lineup position after an override.
- **FR-023**: System MUST record a serve by a player who is not in the lineup, and MUST mark that turn as served from outside the lineup.
- **FR-024**: System MUST reverse an automatic advance together with the operator action that triggered it, in a single undo.
- **FR-025**: System MUST NOT advance the rotation when no lineup is set.

#### Substitutions

- **FR-026**: Operators MUST be able to substitute by double-tapping the outgoing player and then tapping the incoming player.
- **FR-027**: System MUST place the incoming player in the outgoing player's exact lineup position.
- **FR-028**: System MUST use the incoming player when the rotation next reaches that position.
- **FR-029**: System MUST keep every serve recorded by the outgoing player attributed to them, and counted, after they leave.
- **FR-030**: System MUST refuse a substitution whose incoming player is already in the lineup, and explain why.
- **FR-031**: System MUST refuse a substitution whose incoming player is not on the roster.
- **FR-032**: System MUST cancel a pending substitution when the operator taps anything that is not a player.
- **FR-033**: System MUST discard, never apply, a pending substitution when the match ends.
- **FR-034**: System MUST make the incoming player the active server when the outgoing player was serving.
- **FR-035**: Operators MUST be able to undo a substitution, restoring the outgoing player to their position.
- **FR-036**: System MUST record each substitution with the outgoing player, the incoming player, and the point in the match at which it happened.
- **FR-037**: System MUST allow a player who came off to be substituted back on later.

#### Backup and restore

- **FR-038**: Operators MUST be able to export all stored data to a single file in one action.
- **FR-039**: System MUST produce a valid, importable file even when nothing has been recorded.
- **FR-040**: Operators MUST be able to import a previously exported file.
- **FR-041**: System MUST state that importing replaces everything currently stored, and MUST require explicit confirmation before proceeding.
- **FR-042**: System MUST restore every roster, game, match, serve turn, and serve from an imported file, with statistics identical to the source.
- **FR-043**: System MUST refuse a corrupt, truncated, or unrecognised file with a plain explanation, leaving existing data untouched.
- **FR-044**: System MUST refuse a file exported by a newer version, explaining why, without partially applying it.
- **FR-045**: System MUST carry a file exported by an older version forward on import, as it does stored data.
- **FR-046**: System MUST leave all pre-existing data intact when an import fails for any reason.

#### Player buttons

- **FR-047**: System MUST show only the jersey number on player selection buttons, at a size legible at arm's length.
- **FR-048**: System MUST NOT truncate a player's name anywhere on screen; where a name does not fit, it is not shown rather than cut off.
- **FR-049**: System MUST keep each player identifiable on a selection button when they have no jersey number.
- **FR-050**: System MUST show full name and jersey number together on the tally board and in every statistics view.
- **FR-051**: System MUST make every player on a twenty-player roster reachable without horizontal scrolling.

#### Statistics

- **FR-052**: System MUST report everything the previous release reported, unchanged.
- **FR-053**: System MUST report the substitutions made in each match.
- **FR-054**: System MUST report, per player, the number of serve turns that elapsed while they were in the lineup.

### Key Entities

- **Lineup**: The ordered list of exactly six players on court for one match, in serving order. Belongs to exactly one match. Positions are stable; who occupies a position changes only by substitution.
- **Lineup Position**: One of the six ordered slots in a lineup. Holds one player at a time and retains its place in the serving order across substitutions.
- **Rotation Pointer**: Which lineup position serves next. Set when the first server of the match is chosen, advanced by one whenever a serve turn ends, wrapping at the end, and moved by an override.
- **Substitution**: One exchange of an outgoing player for an incoming one at a lineup position, at a point within a match. Belongs to exactly one match.
- **Data Format Version**: The version of the stored data shape. Recorded with the data and used to decide whether it is carried forward, loaded as-is, or refused.
- **Export File**: A single file holding everything stored, plus its data format version. Sufficient on its own to restore the app completely.

Entities from the previous release — Player, Roster, Game, Match, Serve Turn, Serve, Serve Statistics — are unchanged.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of data recorded on the previous release is present and identical after upgrading, with no operator action required.
- **SC-002**: A side-out is recorded in a single tap when a lineup is set, down from two.
- **SC-003**: An operator records a full rotation of six serve turns using only outcome taps, and every server matches the lineup order.
- **SC-004**: An operator sets a six-player lineup in under 45 seconds, and prefilled lineups for matches 2 and 3 in under 20 seconds each.
- **SC-005**: A substitution is completed in two taps and is reflected in the rotation immediately.
- **SC-006**: 100% of a substituted-out player's recorded serves remain attributed to them and counted.
- **SC-007**: An operator exports, wipes the app, imports, and finds every figure identical to before, in 100% of trials.
- **SC-008**: A rejected import leaves 100% of pre-existing data intact.
- **SC-009**: An observer identifies the current server correctly from arm's length in under 2 seconds.
- **SC-010**: Every player on a twenty-player roster is reachable without horizontal scrolling or zooming.
- **SC-011**: Any single operator action, including one that triggered an automatic advance, is fully reversed by one undo.

## Assumptions

- **Everything from the previous release still holds.** Phone-portrait only, offline-first with no network requests after install, all data local, single operator on a single device, opponent score untracked. These are not restated as requirements.
- **Six on court.** Confirmed by the stakeholder. Formats with a different number on court are out of scope.
- **The team rotates only on winning the serve back.** This is what makes the next server derivable from lineup order alone, and it is why no extra input is needed per rotation.
- **Automatic advance is unconditional.** Confirmed by the stakeholder: only a substitution changes who serves next, so the app advances without asking. Override remains one tap for the cases where reality disagrees.
- **Substitution limits are not enforced.** Leagues cap substitutions differently and the cap is the referee's to keep. Substitutions are recorded and counted so the operator can watch the number, but the app never blocks one.
- **A substitution is a lineup change, not a roster change.** Both players stay on the roster throughout.
- **Position numbers are not modelled.** The lineup is a serving order. Court positions, front and back row, and libero rules are out of scope.
- **Import replaces rather than merges.** Merging two histories has no unambiguous meaning, and a restore is the actual need.
- **Export is a file the operator keeps.** The app does not send it anywhere; there is no account and no sync, consistent with the offline-first constraint.
- **Backup is manual.** The operator chooses when to export. There is no automatic or scheduled backup.
- **Cross-game reporting remains out of scope.** As in the previous release, completed games are retained but there is no trend reporting across games.
