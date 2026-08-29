# Feature Specification: Native iOS App with a watchOS Companion

**Feature Branch**: `004-native-ios-and-watch`

**Created**: 2026-08-29

**Status**: Ready for planning — clarifications resolved 2026-08-29

**Input**: User description: "Volleyball Serve Tracker v4 — native iOS app with a watchOS companion. The watch is the reason: six boxes laid out as the court, active server bottom-right, rotation clockwise, each box showing jersey number, serve-in percentage and points, and the on-deck server's box biggest so the coach can decide whether to substitute before that player serves."

## Overview

The fourth release, and the first that is not a web page.

Three releases built an app that records a match well and holds a season honestly. It is in use for a real season. What it cannot do is put the court where the coach can see it. **The tracker holds the phone; the coach is on the sideline with her hands full.** The one decision that has to be made in seconds — substitute now, before this player serves — is currently made by shouting across a gym at whoever is holding the phone.

So the watch is not a companion view of the app. **The watch is the reason for the release.** It shows six boxes laid out as the court, and it makes one thing unmissable: who serves next, and how they have been serving. Everything else in this release exists to get that court onto a wrist without losing a season of recorded data on the way.

Two things are non-negotiable and set the shape of everything below:

- **The season already recorded must survive the move.** One real season sits in the shipped web app on the operator's phone, including five games transcribed from paper sheets. A migration that loses it, or silently changes a figure, has failed no matter what else works.
- **The gym has no usable network.** Every release so far has been offline-first; going native must not quietly introduce a dependency on connectivity for anything that happens during a match.

The behaviour of releases 001–003 carries over unchanged and is not restated here as new requirements. It is restated only where the move to two devices changes what it means. That behaviour includes: the append-only event log with replay-based undo; statistics derived on read and never stored; a jersey number belonging to a season membership rather than to a player; a figure never recorded rendering as a dash rather than a zero; seasons, game context, per-match results, split notes, and games copied from paper; rotation of six with auto-advance; substitution taking the outgoing player's exact slot; the five-serve limit with its alert; turns over five recorded in full and flagged; and serve-by-serve correction of any past game.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The coach reads the court from her wrist (Priority: P1)

The coach is standing at the sideline during a match. She raises her wrist and sees six boxes arranged the way her players are actually standing: three across the front, three across the back, with the player currently serving in the bottom-right box. Each box carries that player's number, how much of their serving has landed in, and how many points they have won on serve. One box — the player who takes the serve next — is larger and plainer than the others, because that is the player she may want to pull. She decides, calls the substitution, and looks back at the court.

**Why this priority**: This is the entire reason for the release. Every other story in it is either what the watch needs to work or what must not be lost on the way.

**Independent Test**: With a match in progress on the phone, raise the watch and read the six numbers, the serve-in percentages and the points without touching either device; confirm the on-deck player is identifiable at a glance and that the arrangement matches where the players are standing.

**Acceptance Scenarios**:

1. **Given** a match in progress with six players on court, **When** the coach raises her wrist, **Then** she sees six boxes in the court's own arrangement, with the current server in the bottom-right box.
2. **Given** a serve turn ends and the rotation advances, **When** the coach next looks at the watch, **Then** every box has moved one place clockwise: the player who was serving now occupies the bottom-middle box, and the player who was top-right now occupies the bottom-right serving box.
3. **Given** any player on court, **When** the coach reads their box, **Then** it shows their jersey number, their serve-in percentage, and the points they have won on serve.
4. **Given** a player who has not served yet in the game, **When** the coach reads their box, **Then** the percentage shows as a dash rather than as zero or as 100%.
5. **Given** six boxes on screen, **When** the coach glances at the watch, **Then** the box of the player who serves next is visibly the largest and most legible box on the screen.
6. **Given** a substitution is made, **When** the incoming player takes the outgoing player's slot, **Then** the watch shows the incoming player in that exact box.

---

### User Story 2 - The season already recorded comes across intact (Priority: P1)

The operator installs the native app. Their existing season — the roster, every game tracked serve by serve, the five games copied from paper, the notes, the results — is in the new app, reading exactly as it did in the web app. No figure has changed. Nothing has to be retyped.

**Why this priority**: A real, irreplaceable season is at stake. If this fails, the release cannot ship at all, whatever else it does.

**Independent Test**: Take the recorded season out of the shipped web app, bring it into the native app, and compare every per-player, per-match, per-game and per-season figure against the web app side by side.

**Acceptance Scenarios**:

1. **Given** a season recorded in the web app, **When** it is brought into the native app, **Then** every player, season membership, jersey number, game, match, serve turn, serve, result and note is present.
2. **Given** the same season in both apps, **When** the same statistic is read in each, **Then** the two agree exactly, including which figures are dashes.
3. **Given** a game copied from paper, **When** it is read in the native app, **Then** it still reports serves in and out only, and still shows dashes for points, turns and time on court.
4. **Given** the data has been brought across, **When** the operator undoes an action recorded before the move, **Then** undo behaves as it did in the web app.
5. **Given** a transfer that cannot be completed, **When** it fails, **Then** nothing on either side has been changed and the operator is told plainly what happened.

---

### User Story 3 - The tracker records a match on the phone (Priority: P1)

The operator tracks a match on the native phone app exactly as they did on the web: pick the six on court, tap the outcome of each serve, watch the rotation hand the serve on by itself, substitute with two taps, and be told loudly when a server has taken their five.

**Why this priority**: The watch shows what the phone records. Without the recording loop there is nothing to show, and this is the loop that runs a hundred times a match.

**Independent Test**: Track a full three-match game on the phone with no network, and confirm the recorded figures match a paper tally kept alongside it.

**Acceptance Scenarios**:

1. **Given** a match in progress, **When** the operator records a serve outcome, **Then** the figures and the tally update immediately and the rotation advances when the turn ends.
2. **Given** a serve recorded by mistake, **When** the operator undoes, **Then** exactly one operator action is reversed, including any rotation advance it caused.
3. **Given** aeroplane mode with no network of any kind, **When** a whole game is tracked, **Then** nothing fails, and nothing waits on a connection.
4. **Given** a server has taken five serves, **When** the fifth is recorded, **Then** the phone raises the same unmissable alert it does today.

---

### User Story 4 - The record can still be corrected afterwards (Priority: P2)

After the game, the operator opens any game already played — not only the one being tracked — and fixes what was mis-entered: a serve recorded as a point that was not, a turn credited to the wrong player, a turn that never happened, or a turn that happened and was missed.

**Why this priority**: Mis-entry is normal at the speed a match runs, and a record that cannot be corrected stops being trusted. It is P2 only because a match can be tracked without it.

**Independent Test**: Mis-enter a game deliberately, then correct every kind of mistake and confirm the season figures follow.

**Acceptance Scenarios**:

1. **Given** any game in the season, **When** the operator opens its serve record, **Then** every turn is listed in the order it happened, with its serves.
2. **Given** a turn on screen, **When** the operator changes a serve outcome, adds or removes a serve, reassigns the turn, deletes it, or adds a turn missed at the time, **Then** the change is recorded, every derived figure follows, and the change can be undone.

---

### User Story 5 - The rest of the season is all still there (Priority: P2)

Seasons, rosters, career players across seasons, games entered from paper, backups, and the statistics screens are all present in the native app.

**Why this priority**: This is the accumulated value of three releases. It is P2 because it is used between games rather than during one.

**Independent Test**: Walk every screen of the web app and find its counterpart in the native app, with the same figures.

**Acceptance Scenarios**:

1. **Given** a season with games, **When** the operator reads it, **Then** they see per-player totals, the win-loss record, and the breakdown by opponent.
2. **Given** a player who appears in more than one season, **When** the operator opens them, **Then** they see that player's figures season by season.
3. **Given** any point in the season, **When** the operator asks for a backup, **Then** they get a file they keep, which can restore everything.

---

### User Story 6 - The watch and the phone stay in step (Priority: P2)

The watch reflects what the phone records within a rally, and when the two lose contact — the phone in a bag, the watch out of range — the watch says so plainly rather than showing figures that are quietly out of date.

**Why this priority**: A watch that shows stale figures without saying so is worse than a watch that shows nothing: the coach would substitute on a percentage that has since changed.

**Independent Test**: Record serves on the phone and watch the wrist follow; then separate the devices and confirm the watch marks what it is showing as no longer current.

**Acceptance Scenarios**:

1. **Given** a match in progress, **When** the operator records a serve on the phone, **Then** the watch shows the updated figures without the coach touching it.
2. **Given** the devices have lost contact, **When** the coach raises her wrist, **Then** the watch still shows the last known court, clearly marked as not current, with how long ago it was current.
3. **Given** contact is restored, **When** the two reconnect, **Then** the watch catches up without the coach doing anything, and without any recorded serve being lost or duplicated.

---

### User Story 7 - The coach records from the wrist (Priority: P2)

The tracker is not there — pulled away, or handing out water. The coach taps the outcome of
each serve on her wrist: in and won the point, in and lost it, or out. Nothing is lost, and
when she looks at the phone afterwards the serves are simply there, indistinguishable from
the ones tapped on the phone.

**Why this priority**: It removes the single point of failure in the whole arrangement — one
person holding one phone. It is P2 because the phone can always do it, and a watch that only
shows the court already delivers the release's reason for existing.

**Independent Test**: Put the phone down, record a whole serve turn from the watch, and
confirm the phone's record is identical to one recorded on the phone.

**Acceptance Scenarios**:

1. **Given** a match in progress, **When** the coach records a serve outcome on the watch,
   **Then** it appears in the phone's record and is indistinguishable from a phone-recorded serve.
2. **Given** a serve recorded on the watch, **When** the operator undoes on the phone,
   **Then** exactly that one serve is reversed, along with any rotation advance it caused.
3. **Given** the devices are out of contact, **When** the coach records serves on the watch,
   **Then** the watch says plainly that they have not reached the phone yet, and sends them
   in order, exactly once, when contact returns.
4. **Given** a server has taken their five, **When** the fifth serve is recorded from either
   device, **Then** the coach feels it on her wrist without having to be looking at anything.
5. **Given** a wrist moving through an ordinary gym evening, **When** no one intends to record,
   **Then** nothing is recorded by accident.

---

### Edge Cases

- **Fewer than six players available.** A team with five present cannot fill a court. The watch must show the court honestly rather than inventing a sixth player or collapsing to five boxes that misstate where people are standing.
- **No lineup set.** The operator can track without a rotation, picking each server by hand. The watch cannot say who is on deck, and must say that rather than guess.
- **An off-order server.** The referee lets someone serve out of turn. The court on the wrist must not silently reorder itself; the recorded position is what it shows.
- **A player who has served nothing yet.** Their percentage is not zero — it does not exist. It must read as a dash on the watch exactly as it does on the phone.
- **A turn running past five serves.** Recorded in full and flagged; the watch must not cap or hide the extra serves.
- **The watch is not paired, not installed, or not worn.** The phone app must be fully usable on its own; nothing in the tracking loop may wait on a watch.
- **The same serve recorded twice**, once on each device, by two people trying to be helpful. One record of a match cannot silently double-count; a duplicate must be visible and removable.
- **The watch records while out of contact and the phone records too.** The phone holds the truth, so the watch's queued serves land after the phone's — which may not be the order they were taken in. The record must be correctable, and must never be silently wrong.
- **The same game open on both devices.** Two devices must never produce two divergent records of one match.
- **Migration run twice.** Bringing the same web-app data across a second time must not duplicate a season, a player or a game.
- **The phone's battery dies mid-match.** Everything recorded up to that moment must survive, and the match must be resumable exactly where it stopped.
- **A substitution made between the coach reading the watch and the serve being taken.** The watch must reflect it before the next serve, or the coach's decision is made on the wrong player.

## Requirements *(mandatory)*

### Functional Requirements

#### The court on the wrist

- **FR-001**: The watch MUST show the six players on court as six boxes arranged as the court is: three in a front row and three in a back row.
- **FR-002**: The watch MUST place the player currently serving in the bottom-right box.
- **FR-003**: The watch MUST advance the arrangement clockwise as the rotation advances: the player who has just served moves to the bottom-middle box, and the player who was in the top-right box moves into the bottom-right serving box.
- **FR-004**: Each box MUST show that player's jersey number, their serve-in percentage, and the points they have won while serving.
- **FR-005**: The box of the player who takes the serve next MUST be the largest and most legible element on the watch screen.
- **FR-006**: A figure that has not been recorded MUST show as a dash on the watch, never as zero and never as a full percentage.
- **FR-007**: The watch MUST show which scope its figures cover (this match, or this game), and MUST label it so the coach cannot mistake one for the other.
- **FR-008**: The watch MUST reflect a substitution by showing the incoming player in the outgoing player's exact box.
- **FR-009**: When no rotation has been set, the watch MUST say that it cannot name the next server rather than presenting one.
- **FR-010**: When fewer than six players are on court, the watch MUST show the positions that are empty as empty.
- **FR-011**: The watch view MUST be readable at arm's length, in a gym, by someone who is not wearing reading glasses — including the on-deck box being distinguishable without reading it.

#### The link between the devices

- **FR-012**: What the phone records MUST reach the watch without the coach touching the watch.
- **FR-013**: The watch MUST show the last known court when contact with the phone is lost, marked plainly as not current, with how long ago it was current.
- **FR-014**: The two devices MUST recover from a loss of contact on their own, without losing or duplicating any recorded serve.
- **FR-015**: The phone app MUST be fully usable with no watch present, paired, or installed.
- **FR-016**: The link between the devices MUST work with no internet connection and no mobile signal.
- **FR-017**: The watch is the one paired to the phone doing the recording. The release MUST NOT depend on reaching a second person's phone; whoever wears the watch during a match is wearing the watch paired to the tracking phone.
- **FR-018**: The watch MUST be able to record a serve outcome — in and won the point, in and lost it, or out — as well as show the court.
- **FR-019**: Exactly one device MUST hold the truth for a match: the phone. A serve recorded on the watch MUST reach the phone's record, and MUST be indistinguishable there from a serve recorded on the phone.
- **FR-020**: A serve recorded on the watch while the two are out of contact MUST reach the phone when contact returns, in the order it was taken, exactly once.
- **FR-021**: A serve recorded on the watch MUST be undoable on the phone like any other, and one undo MUST still reverse exactly one operator action.
- **FR-022**: The watch MUST show whether the serve it just recorded has reached the phone, so a serve recorded out of contact is never assumed to be safe.
- **FR-023**: The watch MUST raise the five-serve limit on the wrist — felt as well as seen — so the coach knows the rotation is about to move without looking at anything.
- **FR-024**: Recording on the watch MUST take one deliberate action per serve, and MUST NOT be triggerable by an accidental wrist movement.

#### Bringing the recorded season across

- **FR-025**: The native app MUST import a season recorded by the shipped web app, with every player, membership, jersey number, game, match, serve turn, serve, result, and note preserved.
- **FR-026**: Every statistic derived after the import MUST equal the statistic the web app derives from the same data, including which figures are dashes.
- **FR-027**: Undo MUST continue to work across data brought in from the web app.
- **FR-028**: An import that cannot complete MUST leave the device exactly as it was, and MUST say plainly why.
- **FR-029**: Importing the same data twice MUST NOT duplicate a season, a player, a game, or a serve.
- **FR-030**: The operator MUST be able to get their data back out of the native app in a form that can be kept as a backup and restored.

#### What the phone must still do

- **FR-031**: The native phone app MUST preserve every behaviour of releases 001–003 named in the Overview, including the recording loop, the rotation, substitutions, the five-serve alert, corrections to past games, seasons, career players, games from paper, and the statistics screens.
- **FR-032**: Recorded data MUST survive an app update, a device restart, and the app being force-quit mid-match.
- **FR-033**: Everything that happens during a match MUST work with no network of any kind.
- **FR-034**: A match interrupted by the app closing MUST resume exactly where it stopped, with nothing recorded before the interruption lost.

#### What ships when

The release lands in two phases. The second is committed, not conditional: the season it
serves is already under way, and an app that only half-holds a season is worse than one
that holds none.

- **FR-035**: Phase one MUST deliver the match-day core: tracking a match on the phone, the
  court on the wrist, recording from the wrist, and the migration of the recorded season.
- **FR-036**: Phase one MUST NOT be shipped without the migration. An app that can track
  tonight's game but cannot hold the season already recorded would split the record in two.
- **FR-037**: Phase two MUST bring the remaining behaviour of releases 001–003 to parity —
  seasons, career statistics, games entered from paper, and serve-by-serve correction of a
  past game — and MUST be complete before the current season ends.
- **FR-038**: Between the two phases, the web app MUST remain able to read and correct the
  same season, so nothing recorded natively is unreachable while parity is being built.

#### Fit for other people's teams

- **FR-039**: Nothing in the release may assume one team, one coach, one season, or one family: the app MUST behave correctly for an operator with several seasons and several teams.
- **FR-040**: All recorded data MUST stay on the operator's own devices; nothing may be sent anywhere without the operator asking for it.
- **FR-041**: The app MUST NOT require an account, a sign-in, or a network round trip to record a match.

### Key Entities

The entities of releases 001–003 are unchanged: **Player** (a career identity), **Season** (a name, a team, a format, and a roster of memberships), **Season Membership** (a player and the number they wore that season), **Game** (tracked serve by serve, or copied from paper, with date, opponent, location, court, result and notes), **Match**, **Serve Turn**, **Serve**, and the **Event Log** they are all replayed from.

This release adds:

- **Court View**: what the watch shows — six positions, each holding at most one player, with the serving position and the on-deck position identified. Derived on read from the match, never stored.
- **Device Link**: the relationship between the recording device and the watching device, carrying how current the watching device's picture is and whether the two are in contact.
- **Migration**: a one-time move of a recorded season from the web app into the native app, which either completes in full or changes nothing.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A coach can name the player who serves next, and say whether their serving has been good, within 2 seconds of raising her wrist, without touching either device.
- **SC-002**: A serve recorded on the phone is visible on the watch before the next serve is taken — within 3 seconds under normal conditions.
- **SC-003**: 100% of the operator's existing recorded season transfers, with every derived figure identical to the web app's; verified figure by figure against a season containing both tracked and paper games.
- **SC-004**: A full three-match game can be tracked with the device in aeroplane mode, start to finish, with no failure and no waiting.
- **SC-005**: A serve outcome can still be recorded in a single tap, and one undo still reverses exactly one operator action.
- **SC-006**: When the devices lose contact, the coach can tell within 2 seconds that what she is looking at is not current.
- **SC-007**: A match interrupted by the app being force-quit resumes with zero recorded serves lost.
- **SC-008**: The on-deck player's box is identified correctly by a first-time reader on their first attempt, without instruction, in 9 out of 10 attempts.
- **SC-009**: Nothing the app does during a match requires an account, a sign-in, or a network request.
- **SC-010**: A serve recorded on the watch reaches the phone's record within 3 seconds of contact, exactly once, and reads there identically to a serve recorded on the phone.
- **SC-011**: A serve can be recorded from the wrist in one deliberate action, and no serve is recorded by accident across a full evening of ordinary wrist movement.
- **SC-012**: Phase one ships with the migration included — an app that can track a match but not hold the season already recorded is not shippable.
- **SC-013**: Phase two reaches parity with releases 001–003 before the current season ends, with every screen of the web app having a counterpart.

## Assumptions

- **The Apple identity conventions are already fixed** by the operator's global instructions: the bundle prefix, the App Group derived from the bundle id, and the App Store Connect credentials held in the vault. This release follows them rather than inventing new ones.
- **The route the data takes across is the backup file the web app already produces.** The shipped web app can export its whole event log as a file through the iOS share sheet, and the native app can read that file. This needs no new capability on the web side, and it works with no network. If a faster route exists it is an optimisation, not a requirement.
- **The watch shows the current match by default.** Game-scope and season-scope figures are more useful sitting down than standing up; the coach's decision is about how this player has served today.
- **Serve-in percentage on the watch is scoped to the current game**, not to the season or career — the coach is deciding about this evening.
- **The first native release ships to the operator's own devices** through TestFlight. Public App Store submission is not a deliverable of this release, but nothing in it may make submission harder later.
- **The watch and the phone are two hands of one operation, not two independent recorders.** Both can record, but the phone always holds the truth, and two people recording the same serve is a mistake to be made visible rather than a case to be merged cleverly.
- **The watch is paired to the tracking phone.** Whoever wears it during a match wears the watch belonging to the phone doing the recording. Reaching a second person's phone is explicitly out of scope for this release.
- **The web app keeps running** and is not withdrawn when the native app ships. The operator's season is mid-flight; two working copies is a safety net, not a maintenance burden, for one season.
- **The opponent's score is still not tracked.** Match results stay a single tap by the person who can see the scoreboard, exactly as in release 003.
