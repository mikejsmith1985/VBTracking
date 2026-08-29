# Contract: UI Interaction additions

**Feature**: `002-rotation-and-subs` | **Date**: 2026-08-29

Extends `specs/001-volleyball-serve-tracker/contracts/ui-interaction.md`, which remains in force — including the rule that gives this release most of its screen: **the dock holds a status row over exactly one action block**, the outcome controls or the picker, never both and never a dimmed copy of either.

---

## What the rotation changes about the dock

With a lineup set, a serve turn ends and the next server is already chosen. The dock therefore stays on the **outcome controls** through a side-out instead of swapping to the picker.

| State | Status row | Action block |
|---|---|---|
| Serving, lineup set | `NOW SERVING` · number · name · Change · Undo | Outcome controls |
| Serving, no lineup | Same | Outcome controls |
| Between servers, **no lineup only** | `NEXT SERVER` · Undo | Picker |
| Changing server, or substituting | `NOW SERVING` · … · Cancel · Undo | Picker |

**The picker stops appearing during normal play.** That is the one-tap side-out: record the outcome, and the next server is already there. The picker returns only when the operator asks for it, or when there is no lineup to advance.

| Sequence | Taps before | Taps now |
|---|---|---|
| Serve that wins a point | 1 | 1 |
| Full side-out | 2 | **1** |
| Side-out with an override | 2 | 2 |

---

## The current server must be unmissable

The app now chooses the server, so a wrong one is the app's mistake and the operator has to catch it. `FR-020` and `SC-009` are the load-bearing requirements of this release.

| Rule | Source |
|---|---|
| The status row shows the server's **jersey number at display size** plus their full name | `FR-020` |
| The server is identifiable from arm's length in under 2 seconds | `SC-009` |
| A turn served from outside the lineup is marked, on the status row and on the tally board | `FR-023` |
| Changing server is always one tap away via **Change** | `FR-021` |

---

## Lineup setup

Shown when a match opens, before the first serve. Skippable.

| Rule | Source |
|---|---|
| The operator picks six players and orders them | `FR-009` |
| Confirmation is blocked below or above six, stating how many are needed | `FR-010` |
| A player already chosen cannot be chosen twice | `FR-010` |
| The operator taps which position serves first | `FR-013` |
| Matches 2 and 3 open prefilled from the previous match, editable | `FR-012` |
| **Skip** starts the match with no lineup and release-001 behaviour | `FR-014` |
| A roster under six offers no lineup at all, and says why | `FR-014` |
| The lineup is viewable during the match, in serving order, with the next server marked | `FR-015` |
| During a match the lineup is read-only; changes go through a substitution | `FR-016` |

---

## Substitution gesture

| Operator action | System response | Source |
|---|---|---|
| Tap a lineup player twice in quick succession | That chip is visibly **armed** for substitution | `FR-026` |
| Then tap a player not in the lineup | They take the armed player's position; the rotation follows | `FR-027`, `FR-028` |
| Then tap a player already in the lineup | Refused, with a reason. The arm stays | `FR-030` |
| Then tap the same player again | Nothing recorded; the arm clears | Edge case |
| Tap anything that is not a player | The arm clears silently | `FR-032` |
| End the match while armed | The arm is discarded, never applied | `FR-033` |
| Undo after a substitution | The outgoing player returns to their position | `FR-035` |

The armed state must be **obvious and escapable** — it borrows the two-step confirmation pattern the operator already meets when ending a match and discarding a game.

---

## Player chips

| Rule | Source |
|---|---|
| A chip shows the **jersey number only**, typographically large | `FR-047` |
| No name is truncated anywhere; where it does not fit, it is omitted | `FR-048` |
| A player with no number stays identifiable and selectable | `FR-049` |
| Full name and number appear on the tally board and every statistics view | `FR-050` |
| All twenty players are reachable with no horizontal scrolling | `FR-051` |

---

## Backup and restore

Lives on the Stats screen beside **Discard this game** — destructive and administrative, far from anything tapped during a rally.

| Rule | Source |
|---|---|
| **Export** produces the file in one action | `FR-038` |
| Export works with nothing recorded | `FR-039` |
| **Import** opens a file picker | `FR-040` |
| Import states that everything stored will be replaced, and needs a second deliberate tap | `FR-041` |
| A refused import reports why in plain words and changes nothing | `FR-043`, `FR-046` |
| Import during a live match names that the in-progress match is replaced too | Edge case |

---

## Statistics additions

| Rule | Source |
|---|---|
| Each match lists its substitutions: who came off, who came on, and when | `FR-053` |
| Per player, turns on court — counting turns they were in the lineup for, served or not | `FR-054` |
| Every release-001 figure is unchanged | `FR-052` |

---

## Platform behaviour

Release 001's platform contract applies unchanged. Two additions, both verified **on the device**:

| Rule | Source |
|---|---|
| The double-tap substitution gesture works on touch and does not trigger zoom | `FR-026`, `FR-049` |
| Export reaches a file the operator can keep — the iOS share sheet, not a silent failure | `FR-038` |
