# Feature Specification: Seasons, Career Players, and Game Context

**Feature Branch**: `feature/seasons-and-career`

**Created**: 2026-08-29

**Status**: Draft

**Input**: User description: "I want to import data from my previous games to be able to see a season stats screen. Possibly plug in the location and the team we played against. Also log wins and losses. Seasons named, but we have to know that the roster can change from season to season and be able to handle that. Build as career — this year I'm tracking a team because it's my daughter's first season and my wife is coaching. Next year she'll be on the school team with a different coach and my primary concern will be my daughter, not the whole team."

## Overview

The third release. The first two made the app good at recording a match. This one makes it good at holding a history.

Three things drive it, and they are really one thing.

The operator is tracking a team this season because his wife coaches it and his daughter plays. **Next season his daughter plays for a different team, under a different coach, wearing a different number.** She is the same child. So a player has to be a person who outlives any roster, and a jersey number has to belong to the season rather than to the player.

He also has **five games recorded on paper** before the app existed, and a season that is missing them is not a season. Those sheets hold serves in and serves out per player, at game level only — no points, no matches, no turns, because that detail was never written down.

And the sheets carry context the app throws away: **who was played, where, on which court, and how it went** — plus two lists per game, what went well and what to work on. That context is most of why a record is worth keeping.

The constraints of the first two releases carry over unchanged and are not restated here: phone-portrait only, offline-first with no network requests after install, all data on the device, single operator, opponent score untracked.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Keep this season's work (Priority: P1)

The operator updates the app. Every player, game, match, serve turn, and serve recorded so far is still there, now belonging to a season he did not have to create. Their jersey numbers are intact. He is asked nothing.

**Why this priority**: A real season is already recorded on the live app. Every other story in this release changes the shape of that data, so this must land first or the release costs him the thing it is meant to preserve.

**Independent Test**: Record games on the current release, upgrade, and confirm every figure at every scope is identical, with the existing roster now appearing as a season's players.

**Acceptance Scenarios**:

1. **Given** data recorded by the previous release, **When** the operator opens this one, **Then** every player, game, match, turn, and serve is present and every statistic reports the same figures as before.
2. **Given** that data is carried forward, **When** it is examined, **Then** each existing player is a career player, and the roster has become one season's list of players with their jersey numbers.
3. **Given** that data is carried forward, **When** the app opens, **Then** every existing game belongs to that season.
4. **Given** the carry-forward happens, **When** it does, **Then** the operator is asked nothing and loses nothing.
5. **Given** data written by a newer release, **When** the app opens, **Then** it explains, does not load it, and does not overwrite it.

---

### User Story 2 - Set up a season and who is on it (Priority: P1)

The operator names a season and the team it is played for, then builds its roster. For each player he either picks someone who already exists — a person he has recorded before — or adds someone new. Each player gets the number they wear **this** season.

Next year he creates a second season, for a different team, and adds his daughter to it from the existing people. Her new number is recorded there; her old number stays with the old season.

**Why this priority**: This is the change everything else rests on. Without it there is one roster forever and the same child becomes two people.

**Independent Test**: Create a season with nine players, then create a second season, add one of the same players with a different number, and confirm both seasons show the right number and the player is recognisably one person.

**Acceptance Scenarios**:

1. **Given** no seasons exist, **When** the operator creates one, **Then** it has a name and a team name and becomes the season new games belong to.
2. **Given** a season, **When** the operator adds a player, **Then** they may either pick an existing person or create a new one, and they give the number worn this season.
3. **Given** a player already in this season, **When** the operator adds them again, **Then** the app prevents it.
4. **Given** two players in the same season, **When** they are given the same number, **Then** the app warns but allows it, because numbers are occasionally duplicated in practice.
5. **Given** a player in two seasons with different numbers, **When** each season is viewed, **Then** each shows that season's number.
6. **Given** a player with recorded serves, **When** they are removed from a season, **Then** they leave that season's roster, the person continues to exist, and their recorded serves remain.
7. **Given** several seasons, **When** the operator switches the active season, **Then** new games belong to the newly active one and the other seasons are untouched.
8. **Given** a match in progress, **When** the operator tries to switch seasons, **Then** the app refuses and says the match must be ended first.
9. **Given** any season, **When** the operator renames it or its team, **Then** the change is reflected everywhere it appears.

---

### User Story 3 - Record who, where, and how it went (Priority: P1)

Before or after a game, the operator records the opposing team, the location, the court, and the date. When a match ends he marks it won or lost — one tap, because the app still does not know the opponent's score. The game's result follows from its matches.

**Why this priority**: Serve figures without an opponent are a number without a story. This is the context that makes a season worth reading, and it is on every paper sheet he has kept.

**Independent Test**: Record two games on the same date against different opponents, mark match results, and confirm both games stay distinct and each shows the right result.

**Acceptance Scenarios**:

1. **Given** a game, **When** the operator sets its date, opponent, location, and court, **Then** all four are recorded and shown wherever the game appears.
2. **Given** a game already played, **When** the operator corrects any of that context, **Then** the correction applies and nothing else about the game changes.
3. **Given** two games on the same date against different opponents, **When** both are recorded, **Then** they remain separate games and neither overwrites the other.
4. **Given** a match being ended, **When** the operator marks it won or lost, **Then** that result is recorded against the match.
5. **Given** a match ended without a result being marked, **When** it is viewed, **Then** it shows as having no recorded result rather than as a loss.
6. **Given** a game whose matches have results, **When** the game result is shown, **Then** it is won when more matches were won than lost, lost when more were lost, and drawn or undecided otherwise.
7. **Given** a season with several games, **When** its record is shown, **Then** it gives wins and losses, and a breakdown by opponent.

---

### User Story 4 - Enter the games recorded on paper (Priority: P2)

The operator has five games on paper from before the app existed. Each has, per player, serves in and serves out, at game level. He records them so the season is complete.

He can type one in, or import a prepared batch so a stack of old sheets needs no typing at all.

**Why this priority**: The season is incomplete without them, and incompleteness is what makes a season screen not worth opening. It follows the structural work because those games need a season to belong to.

**Independent Test**: Import five prepared historical games, and confirm each appears in the season with the right opponent, date, and per-player serve figures, and that season totals include them.

**Acceptance Scenarios**:

1. **Given** a season, **When** the operator adds a historical game, **Then** he records the same context as any game plus, per player, serves in and serves out.
2. **Given** a historical game, **When** it is saved, **Then** it appears in the season alongside tracked games.
3. **Given** a prepared batch of historical games, **When** the operator imports it, **Then** every game in it is added with its context and figures, without typing.
4. **Given** an import batch naming a player not on the season roster, **When** it is imported, **Then** the app says which player is unknown and imports nothing.
5. **Given** a malformed or unreadable batch, **When** it is imported, **Then** the app refuses with a plain explanation and changes nothing already recorded.
6. **Given** a historical game, **When** its figures are viewed, **Then** serves, serves in, and serve-in percentage are shown, and points, turns, and time on court are shown as not recorded rather than as zero.
7. **Given** a historical game, **When** the operator corrects a figure, **Then** the correction applies and totals follow.
8. **Given** a historical game, **When** the operator opens the tracking screen, **Then** it is not offered for serve-by-serve recording, because that detail does not exist for it.

---

### User Story 5 - Read the season (Priority: P2)

One screen for the whole season: every player's serving across every game, the team's record, and how it went against each opponent. Top scorer and top serve percentage are worked out by the app rather than by hand at the end of each sheet.

**Why this priority**: This is the payoff for the whole release, but it is read between seasons rather than during a match, so it follows the recording work.

**Independent Test**: With a season of five historical and one tracked game, confirm every per-player season total equals the sum of that player's games, and the record matches the game results.

**Acceptance Scenarios**:

1. **Given** a season with games, **When** its statistics are viewed, **Then** each player shows serves, serves in, and serve-in percentage across every game of the season.
2. **Given** a season mixing tracked and historical games, **When** totals are shown, **Then** serves and serves in span every game, and points and turns are labelled as covering tracked games only.
3. **Given** a season, **When** its record is shown, **Then** wins and losses are given, along with a breakdown by opponent.
4. **Given** any single game, **When** it is viewed, **Then** the app names its top scorer and top serve percentage without the operator working them out.
5. **Given** a player who played no games in a season, **When** the season is viewed, **Then** they are shown as having no games rather than with zeroes.
6. **Given** a season's figures, **When** compared with the sum of its games, **Then** they agree exactly.

---

### User Story 6 - Keep the notes (Priority: P2)

Every paper sheet carries two lists: what went well, and what to work on. The operator keeps that on every game, and reads it back later.

**Why this priority**: It is on every single sheet he has kept, which is a stronger statement of what he values than anything he could say. It follows the figures only because figures are what the app already holds.

**Independent Test**: Add notes to a game, close the app, reopen, and confirm they are attached to that game wherever it appears.

**Acceptance Scenarios**:

1. **Given** any game, tracked or historical, **When** the operator writes notes, **Then** they are saved against that game.
2. **Given** a game with notes, **When** it appears anywhere, **Then** its notes are available with it.
3. **Given** notes, **When** the operator edits them at any later time, **Then** the edit is kept.
4. **Given** notes of several paragraphs, **When** they are displayed, **Then** the whole text is readable without truncation.

---

### User Story 7 - Follow a player across seasons (Priority: P3)

One player, every season they have played, side by side. This is the reason career identity exists: next season the operator's interest is one child rather than a squad.

**Why this priority**: It becomes valuable when there is a second season to compare against, which is months away. The identity work that makes it possible lands now; the screen can follow.

**Independent Test**: With one player in two seasons, confirm the career view shows both seasons separately with the right number for each, plus a combined total.

**Acceptance Scenarios**:

1. **Given** a player in more than one season, **When** their career is viewed, **Then** each season is listed separately with that season's team and number.
2. **Given** a player in more than one season, **When** their career is viewed, **Then** a combined total across all seasons is shown.
3. **Given** a player in one season only, **When** their career is viewed, **Then** it shows that season without implying others are missing.
4. **Given** a career total spanning tracked and historical games, **When** it is shown, **Then** the same honesty applies: points and turns are labelled as tracked games only.

---

### Edge Cases

- **The same person entered twice.** The operator creates a new person who already exists. The app cannot know, but when adding to a season it offers existing people first so the mistake is hard to make.
- **A number reused within a season.** Two players are given the same number. Warned, allowed, and both remain identifiable by name.
- **A number reused across seasons by different people.** Entirely normal and must not confuse anything — number belongs to the season membership, not the person.
- **A player removed from a season mid-game.** The removal warns that they are on court, as it already does, and their recorded serves survive.
- **Deleting a person who has recorded data.** Refused. They can be removed from a season, but the person is not deleted while any game references them.
- **Switching seasons with a match in progress.** Refused, with the reason.
- **A season with no games.** Its screen says so plainly rather than showing a table of zeroes.
- **A historical game listing a player who is not on that season's roster.** The import names the unknown player and imports nothing, rather than silently creating someone.
- **A historical game with all zeroes.** Valid — a game where nobody served in is a real, if grim, record.
- **A match ended without a result.** Counts toward neither wins nor losses, and the game result says undecided rather than guessing.
- **Two games, same date, same opponent.** Legitimate — a double-header. Both are kept and distinguishable by court or by the order they were entered.
- **Notes on a game that is later discarded.** They go with it; discarding a game is already confirmed and already destructive.
- **Correcting a historical figure to a negative number.** Refused; serves in and serves out cannot be negative.

## Requirements *(mandatory)*

### Functional Requirements

#### Carrying this season's work forward

- **FR-001**: System MUST load all data written by any previous release without the operator being asked to act.
- **FR-002**: System MUST turn the existing single roster into one season's list of players, preserving each player's jersey number as that season's number.
- **FR-003**: System MUST make every existing player a career player that can later join further seasons.
- **FR-004**: System MUST attach every existing game to that season.
- **FR-005**: System MUST preserve the exact statistics of carried-forward data — every serve, turn, and total identical to before.
- **FR-006**: System MUST refuse data written by a newer release, explain, and leave it unmodified.

#### Career players

- **FR-007**: System MUST hold a player as a person, identified by name, who exists independently of any season, team, or roster.
- **FR-008**: System MUST allow the same player to belong to any number of seasons.
- **FR-009**: System MUST keep every statistic a player has recorded associated with them across all seasons.
- **FR-010**: System MUST NOT delete a player who is referenced by any recorded game.
- **FR-011**: Operators MUST be able to correct a player's name, with the correction reflected in every season and every statistic.

#### Seasons

- **FR-012**: Operators MUST be able to create a season with a name and a team name.
- **FR-013**: System MUST treat exactly one season as active, and new games MUST belong to it.
- **FR-014**: Operators MUST be able to switch the active season, and to rename any season or its team.
- **FR-015**: System MUST refuse to switch the active season while a match is in progress, and say why.
- **FR-016**: System MUST record with each season the format it was played under — matches per game, the score a match is played to, and the number of players on court — so a later release can vary these without changing stored data.
- **FR-017**: System MUST NOT offer these format values for editing in this release.

#### Season rosters

- **FR-018**: Operators MUST be able to add a player to a season either by choosing an existing person or by creating a new one.
- **FR-019**: System MUST record the jersey number as belonging to the season's roster entry, not to the person.
- **FR-020**: System MUST prevent the same person being added to one season twice.
- **FR-021**: System MUST warn, but allow, when two players in one season share a number.
- **FR-022**: System MUST show each season's own number for a player who appears in several seasons.
- **FR-023**: Operators MUST be able to remove a player from a season without deleting the person or their recorded serves.

#### Game context

- **FR-024**: System MUST record, for every game, the date played, the opposing team, the location, and the court.
- **FR-025**: Operators MUST be able to enter or correct any of that context at any time, including after the game is finished.
- **FR-026**: System MUST keep two games played on the same date as distinct games.
- **FR-027**: System MUST show a game's context wherever the game appears.

#### Results

- **FR-028**: Operators MUST be able to mark a match won or lost when ending it, in a single action.
- **FR-029**: System MUST record a match with no marked result as undecided, never as a loss.
- **FR-030**: System MUST derive a game's result from its matches: won when more were won than lost, lost when more were lost, and undecided otherwise.
- **FR-031**: System MUST report a season's record as wins and losses, and MUST break it down by opponent.

#### Notes

- **FR-032**: System MUST hold free-text notes against every game, tracked or historical.
- **FR-033**: Operators MUST be able to write and edit notes at any time.
- **FR-034**: System MUST display notes in full, without truncation, wherever the game is shown.

#### Historical games

- **FR-035**: Operators MUST be able to record a game as a historical entry holding, per player, serves in and serves out at game level.
- **FR-036**: System MUST give historical games the same context and notes as tracked games.
- **FR-037**: System MUST NOT offer serve-by-serve recording for a historical game.
- **FR-038**: Operators MUST be able to correct a historical game's figures, with totals following.
- **FR-039**: System MUST refuse a negative serve count.
- **FR-040**: Operators MUST be able to import a prepared batch of historical games without typing them.
- **FR-041**: System MUST refuse an import naming a player who is not on the season's roster, name that player, and import nothing.
- **FR-042**: System MUST refuse a malformed import with a plain explanation, leaving all recorded data untouched.

#### Statistics and how they are labelled

- **FR-043**: System MUST report, for a season and per player, serves, serves in, and serve-in percentage across every game of that season.
- **FR-044**: System MUST label points, turns taken, and turns on court as covering tracked games only.
- **FR-045**: System MUST show a figure that was never recorded as not recorded, never as zero.
- **FR-046**: System MUST report, for any game, its top scorer and its top serve percentage.
- **FR-047**: System MUST use the operator's meaning of "score" — serves landed in — and MUST label the existing points figure distinctly, so the two cannot be mistaken for each other.
- **FR-048**: System MUST report a player's figures across every season they appear in, with each season listed separately and a combined total.
- **FR-049**: System MUST show a player with no games in a season as having none rather than as zeroes.
- **FR-050**: System MUST make a season's totals equal the sum of that season's games.
- **FR-051**: System MUST continue to report everything the previous releases reported, unchanged.

### Key Entities

- **Player**: A person. Identified by name, and by nothing that belongs to a team or a season. Exists independently of every roster and outlives all of them. Carries their whole recorded history.
- **Season**: A named period of play for a named team. Holds the roster for that period and the format played under. Exactly one is active at a time.
- **Season Membership**: One player's place in one season, carrying the jersey number worn that season. This is where a number lives — never on the player.
- **Game**: One outing, belonging to one season. Carries a date, an opposing team, a location, a court, notes, and a result derived from its matches. Is either tracked serve by serve or recorded historically.
- **Historical Game Entry**: One player's serves in and serves out for one historical game. Game level only; no matches, turns, or points, because that detail was never recorded.
- **Match Result**: Whether one match was won or lost, or is undecided.
- **Season Statistics**: Per-player figures across a season, plus the team's record and its breakdown by opponent. Derived, never stored.
- **Career Statistics**: One player's figures across every season they appear in, each season separately and combined. Derived, never stored.

Entities from previous releases — Roster, Match, Serve Turn, Serve, Lineup, Substitution, Serve Statistics — carry over. **Roster** is superseded by Season Membership: the standalone roster becomes the first season's list.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of data recorded on the previous release survives the upgrade with identical figures, and appears as one season, with no operator action.
- **SC-002**: A player appearing in two seasons with different numbers shows the correct number in each, and their combined figures equal the sum of both seasons.
- **SC-003**: An operator builds a nine-player season roster in under 3 minutes, and adds an existing player to a second season in under 20 seconds.
- **SC-004**: Five prepared historical games are imported in a single action, with no figures typed.
- **SC-005**: Every season total equals the sum of that season's games, with no discrepancy.
- **SC-006**: A rejected import leaves 100% of recorded data intact.
- **SC-007**: No figure that was never recorded is ever displayed as a zero.
- **SC-008**: An operator marks a match result in one tap while ending it.
- **SC-009**: An operator reads a season's record and its per-opponent breakdown from one screen, without navigating away.
- **SC-010**: An operator identifies any game's top scorer and top serve percentage without calculating anything.
- **SC-011**: Notes written on a game are retrievable in full after the app is closed and reopened, in 100% of trials.

## Assumptions

- **Everything from the first two releases still holds.** Phone-portrait only, offline-first, all data local, a single operator on one device, opponent score untracked, event-sourced state with replay-based undo. These are not restated as requirements.
- **A player is identified by name, by a person who knows them.** There is no attempt to detect that two entries are the same child; the operator is a parent with nine players and knows exactly who is who. Adding to a season offers existing people first, which is enough to prevent duplicates in practice.
- **Numbers may repeat within a season.** Rare, but real, and refusing it would be the app telling the operator his own roster is wrong. Warn and allow.
- **Historical games hold serves only.** Serves in and serves out per player, at game level. Points, matches, and turns are absent because the paper never had them — not because they are zero.
- **Match results are marked, not computed.** The opponent's score remains untracked, so the app cannot know who won. One tap when ending a match is the whole cost.
- **A season's format is recorded but fixed.** Matches per game, target score, and players on court are stored with each season at their current values. Storing them costs almost nothing and removes a future migration; making them editable now would be building for a customer who does not exist.
- **The native rewrite is coming, and the export file is what crosses over.** This shapes the release: the data model is made general because data outlives code, while features stay specific to the actual need, because this code is slated for replacement.
- **A starred player is out of scope here.** Following one child rather than a squad matters from next season. The career identity that makes it possible lands now; the screen that leads with her can follow.
- **Cross-season team records are out of scope.** A season has a record. There is no all-time team record, because the team changes.
