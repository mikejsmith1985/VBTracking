# Phase 0 Research: Seasons, Career Players, and Game Context

**Feature**: `003-seasons-and-career` | **Date**: 2026-08-29

---

## R-001: How to migrate a roster into a season without rewriting history

**Decision**: The `2 → 3` migration is **additive**. It prepends one `CREATE_SEASON` event and stamps a `seasonId` onto the four existing events that need one — `ADD_PLAYER`, `EDIT_PLAYER`, `REMOVE_PLAYER`, `START_GAME`. No existing event is renamed, split, or removed.

**Rationale**: The obvious migration is to *decompose* each `ADD_PLAYER {id, name, number}` into a career player plus a season membership — two events where there was one. It is tempting because it matches the new model exactly, and it is the riskier option by a wide margin: every event index shifts, so any bug is a silent corruption of a real recorded season rather than a visible failure.

Adding a field changes no event's identity and no event's position. The fixture test then compares old and new replays figure by figure, and a mistake shows up as a wrong number rather than as a wrong shape.

The cost is that `ADD_PLAYER` now means two things — *create the person if they are new* and *add them to this season with this number*. That is genuinely what the operator's action means, so the event is honest; it is only the name that is now slightly narrow.

**Alternatives considered**:

| Option | Rejected because |
|---|---|
| Decompose into `CREATE_PLAYER` + `ADD_TO_SEASON` | Every index shifts. A migration bug becomes silent corruption of the only real season recorded. |
| Leave events untouched; infer an implicit season in the reducer | Nothing on disk says which season a game belongs to, so a second season could never be added without the migration this avoids. |
| Version the reducer and keep two code paths | Two rulebooks, forever, diverging. |

---

## R-002: Where a jersey number lives

**Decision**: On the **season membership**, never on the player. A `Player` is `{ id, name }`. A membership is `{ seasonId, playerId, number }`.

**Rationale**: This is the release's reason for existing, and it is not obvious until the second season arrives. Next year the operator's daughter plays for a different team, under a different coach, wearing a different number. She is the same child.

Put the number on the person and one of two things happens: either the number is overwritten each season and last season's tally board becomes a lie, or a second person is created and every year-over-year comparison silently breaks. Both failures are quiet, and both are discovered long after the data is gone.

**Consequence**: every place that renders a number must resolve it through a season. There is one such place already (`playerLabel`), so this is a contained change rather than a diffuse one.

---

## R-003: Representing games that were never tracked

**Decision**: A `Game` carries a `kind` of `tracked` or `historical`. A historical game holds per-player `{ in, out }` totals and has no matches, turns, or serves.

**Rationale**: The alternative — synthesising fake serve turns so historical games look like tracked ones — was rejected outright. It would make every downstream consumer correct by accident and would report turn counts that never happened. Fabricating structure to keep a type uniform is how a statistics feature starts lying.

Keeping them a distinct kind forces every consumer to decide what to do about the absence, which is the point.

**The honesty requirement follows from this** (`FR-044`, `FR-045`): serves, serves in, and serve-in percentage span both kinds; points, turns taken, and turns on court are labelled *tracked games only*. A figure that was never recorded is shown as not recorded — never as a zero, which would report worse figures than the players earned.

---

## R-004: Where derived statistics get their scope

**Decision**: One aggregation function, taking a list of games and returning per-player figures plus a coverage marker saying how many of those games were tracked. Season, career, and single-game views all call it with different game lists.

**Rationale**: Season and career are the same question asked over different sets. Writing them separately would put the tracked-versus-historical rule in two places, and it is exactly the rule that must not drift.

The coverage marker is what lets the UI label honestly without each screen re-deriving whether points are meaningful.

---

## R-005: Match results

**Decision**: `END_MATCH` carries a result of `won`, `lost`, or `undecided`. A game's result is derived from its matches.

**Rationale**: The opponent's score is still not tracked, so the app cannot know. One tap while ending a match is the whole cost, and it is taken at the moment the operator certainly knows the answer.

**Undecided is not a loss.** A match ended without a marked result — the operator was busy, or the game was abandoned — must not silently count against the team. Deriving a game as won only when more matches were won than lost, and undecided when neither, keeps a partial record honest.

`END_MATCH` gaining a field is additive, so an existing ended match migrates to `undecided` and no past match is retroactively declared a loss.

---

## R-006: Importing a batch of historical games

**Decision**: A single JSON file holding a season block and a list of games, imported in one action. Players are matched **by name against the active season's roster**, and an unknown name aborts the entire import.

**Rationale**: The operator has five games on paper. A form would be fifteen minutes of typing and a fresh chance to fat-finger a number that took a season to earn; a file is one tap, and it was transcribed once, carefully, against the totals written on each sheet.

Matching by name rather than by id is deliberate: the file is written by a person reading handwriting, and ids are meaningless to them. Aborting on an unknown name rather than creating a player prevents a typo from quietly adding a tenth person to a nine-player squad.

**All-or-nothing** (`FR-041`): a partial import leaves the operator unable to tell what landed. Refusing wholesale is recoverable; a half-applied import is not.

---

## R-007: Where seasons live in the interface

**Decision**: A fourth tab, **Season**, holding the season's statistics, its record, its per-opponent breakdown, and the controls for seasons and rosters. The Roster tab becomes the active season's roster.

**Rationale**: Four tabs is the practical limit for a phone bottom bar, and this is the fourth. Career belongs inside it — reached by tapping a player — rather than as a fifth tab, because it is read about one person at a time.

Roster stays where the operator already looks for it. It simply now edits the active season's membership rather than a standalone list, which is what it always meant.

---

## R-008: Testing approach

Unchanged in structure from the previous releases. New coverage concentrates on the migration, because it is the only part of this release that can destroy something already recorded.

| Layer | New coverage |
|---|---|
| Unit | Season and membership rules, per-season numbers, career aggregation, historical entries, result derivation, coverage labelling, import parsing |
| Integration | Migration against the committed **release-001 fixture** and a newly captured **release-002 fixture**, asserting every figure identical |
| Device | The season and career screens at phone width; a real import of the five transcribed games |

**A release-002 fixture is captured before any release-003 code exists**, exactly as the release-001 one was. Two fixtures mean the chain is proven from both of its real starting points, not just the oldest.
