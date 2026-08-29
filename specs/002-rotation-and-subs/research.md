# Phase 0 Research: Rotation, Substitutions, and Durable Data

**Feature**: `002-rotation-and-subs` | **Date**: 2026-08-29

Decisions taken before design. Every `NEEDS CLARIFICATION` from Technical Context is resolved.

---

## R-001: Where the automatic advance lives

**Decision**: **In the reducer.** When a recorded serve closes a turn and the match has a lineup, the same state transition opens the next turn for the next player in rotation. No new event is appended.

**Rationale**: This is the decision the whole feature hangs on, and the alternative is subtly wrong.

The obvious approach is for the UI to notice a turn closed and dispatch a `SELECT_SERVER`. That fails three ways:

1. **It puts a rule in `src/ui/`.** "Who serves next" is a rule of volleyball. The layer contract from release 001 says a rule in the UI is a defect, because it cannot be unit-tested and drifts from the reducer.
2. **It breaks undo.** Two events for one operator action means undo takes two taps to reverse one tap. `FR-024` requires one undo to reverse the operator's action *and* the advance it caused.
3. **It makes replay a UI concern.** Replaying a stored log would not re-trigger the UI's reaction, so a replayed log and a live log would diverge — fatal for an event-sourced design.

Putting it in the reducer makes all three disappear. The advance is part of the `RECORD_SERVE` transition, so it replays identically, and popping that one event removes the serve and the advance together. `FR-024` is satisfied structurally rather than by handling.

**Alternatives considered**:

| Option | Rejected because |
|---|---|
| UI dispatches a second `SELECT_SERVER` | The three failures above. |
| A dedicated `ADVANCE_ROTATION` event | Same undo-arity problem, plus a log entry for something the operator never did. |
| Derive the active server at read time without opening a turn | The open turn is what makes a serve recordable; deriving it separately would create two sources of truth for who is serving. |

---

## R-002: How the rotation pointer survives replay and undo

**Decision**: Each serve turn records the **lineup position** it was served from (`0`–`5`, or `null` when the server was not in the lineup). The next position is the last non-null position plus one, wrapping.

**Rationale**: A stored pointer would be a second piece of state to keep in step with the turn list — exactly the class of bug release 001's design eliminated for the active server. Deriving the pointer from the turns means undo cannot leave it stale, because there is nothing to leave stale.

Recording the position rather than the player also survives substitutions correctly: positions are stable, occupants are not. A turn served from position 3 stays position 3 after the player at position 3 is replaced.

**The `null` case matters.** An off-lineup server (`FR-023`) has no position. Skipping nulls when looking backwards means one off-lineup turn does not derail the rotation — it resumes from the last position that was genuinely in the lineup.

---

## R-003: Representing a lineup that changes during a match

**Decision**: The match stores the **starting** lineup as given, and the current lineup is derived by applying that match's substitutions in order during replay. Each serve turn additionally records a **snapshot** of the six occupants at the moment it opened.

**Rationale**: Two different questions need two different answers, and conflating them is where this gets tangled.

- *Who serves next?* Needs the lineup **as it stands now** — derived, so a substitution takes effect immediately.
- *How many turns was this player on court for?* (`FR-054`) Needs the lineup **as it stood then**. Recomputing that by replaying substitutions up to each turn is possible but turns a simple count into a fold over history.

A six-id snapshot per turn costs roughly 240 ids across a full match — nothing at this scale — and makes `FR-054` a filter instead of a reconstruction. Statistics stay derived-on-read, as release 001 requires.

**Alternatives considered**: storing only the starting lineup and reconstructing occupancy per turn. Correct, but every consumer of turns-on-court would have to re-derive it, and each is a chance to get it wrong.

---

## R-004: Substituting the player who is currently serving

**Decision**: Close the outgoing player's open turn, keeping the serves already in it, and open a new turn for the incoming player at the same lineup position.

**Rationale**: `FR-029` and `FR-034` pull in opposite directions — serves already recorded stay with the outgoing player, but the incoming player must become the active server. Rewriting the open turn's `playerId` would satisfy the second and violate the first, silently reassigning serves to someone who did not take them.

Closing and reopening satisfies both, and it is also true to what happened: two players served, so there were two turns. The existing rule that a zero-serve turn is discarded handles the case where the substitution lands before the outgoing player served at all.

---

## R-005: Carrying stored data forward

**Decision**: An ordered migration chain. The loader compares the stored version to the current one and applies each step in sequence. Version 1 → 2 is an identity step.

**Rationale**: Release 002 only **adds** event types; it changes no existing event's shape. A release-001 log is therefore already a valid release-002 log, and the migration has nothing to do.

The chain is still built now, and this is the point: the *mechanism* is what protects the stakeholder, not this particular step. Release 003 will change a shape, and the difference between a one-line migration and a stranded season is whether the chain exists before it is needed. Today's identity step is the test case that proves it runs.

| Stored version | Behaviour |
|---|---|
| Newer than current | Refused, explained, left untouched (`FR-005`) |
| Older than current | Each step applied in order, then replayed (`FR-003`) |
| Current | Loaded directly |
| Unparseable | Reported, nothing applied (`FR-006`) |

**Not re-migrated** (`FR-004`): the carried-forward log is written back stamped with the current version, so the next load takes the direct path. If that write fails, the app keeps running from what it read and leaves the original alone (`FR-008`) — a failed write must never be worse than not trying.

---

## R-006: Getting a backup file off the phone

**Decision**: Offer the file through the **Web Share API** when the device supports sharing files, and fall back to a download link. Import through a standard file input.

**Rationale**: A plain `<a download>` is the reflex, and on an installed iOS web app it is the weakest option — downloads from standalone mode are inconsistent across iOS versions and can fail with no visible error, which is the worst possible outcome for a backup feature.

`navigator.share({ files: [...] })` opens the native share sheet, where **Save to Files**, AirDrop, and Messages are all one tap. It is the path an iPhone user already knows, and it works in standalone mode. The download link remains for desktop and for any browser without file sharing.

Import needs no such care: `<input type="file">` opens the Files picker on iOS and works everywhere.

**Verification note**: sharing is a device behaviour. It is checked on the phone (`quickstart.md` V2-6), not in a desktop browser.

---

## R-007: The double-tap substitution gesture

**Decision**: Two taps on the same player chip within a short window arm a substitution; the next tap on a different chip completes it. Implemented by counting taps in the existing click handler — no `dblclick`, no gesture library.

**Rationale**: `dblclick` is unreliable on touch and interacts badly with the double-tap-zoom suppression already in place from release 001. Counting taps on the same target inside a time window is a few lines, testable as a pure state machine, and behaves identically on touch and mouse.

The armed state must be **visible and escapable**: the armed chip is marked, and a tap on anything that is not a player clears it (`FR-032`). This matches the two-step confirmation pattern already used for ending a match and discarding a game, so the operator has met it before.

**Risk, accepted**: a fast double-tap intended as two separate selections would arm a substitution instead. Selecting the same player twice in a row is meaningless — the second tap would open a zero-serve turn that the reducer discards — so nothing is lost, and the armed state is visible and one tap from cleared.

---

## R-008: Player buttons showing only a number

**Decision**: The chip shows the jersey number alone, typographically large. Players with no number show a dash placeholder and remain selectable.

**Rationale**: The current chip truncates most names to three characters plus an ellipsis, which is not a name and not readable at arm's length. The number is what the operator scans for and is legible at a glance.

The narrower chip is a second gain: more per row means fewer rows, and the picker occupies less of the screen — continuing the space recovery from the last release.

Full names stay everywhere the space exists (`FR-050`): the tally board and every statistics view.

---

## R-009: Testing approach

**Decision**: Extends release 001's three layers unchanged. New coverage concentrates on the reducer, because that is where every rule in this feature now lives.

| Layer | New coverage |
|---|---|
| Unit | Rotation advance and wrap, off-lineup turns, lineup validation, substitution at a position, substituting the active server, undo across an automatic advance, migration chain |
| Integration | Migration against a **real** stored release-001 log; export/import round trip against real storage |
| Device | Share-sheet export, file-picker import, and one-tap side-outs on the phone — none of which a desktop browser proves |

**The migration test is the one that matters.** A literal release-001 log is committed as a fixture and loaded by the release-002 code, asserting every figure is identical. Without a fixture, the test would be written against the format as remembered rather than as shipped.
