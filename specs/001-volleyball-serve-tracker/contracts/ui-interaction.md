# Contract: UI Interaction

**Feature**: `001-volleyball-serve-tracker` | **Date**: 2026-08-29

Three screens. One of them — Track — is where the operator spends the entire match, and it is designed around a single question: *how few taps, and how little looking, does one serve cost?*

---

## Screens

| Screen | Purpose | When used |
|---|---|---|
| **Roster** | Add, edit, remove players | Before the whistle; occasionally mid-game |
| **Track** | Record serves | The whole match |
| **Stats** | Review per turn, per match, per game | Between matches and after |

Navigation is a fixed bottom bar. No nested navigation, no back stack — the operator can always reach Track in one tap from anywhere.

---

## Track screen layout (portrait, top to bottom)

```
┌────────────────────────────┐        ┌────────────────────────────┐
│ Match 2 of 3   ·  17 pts   │        │ Match 2 of 3   ·  17 pts   │
│                    [End]   │        │                    [End]   │
├────────────────────────────┤        ├────────────────────────────┤
│ #7 Rivera        ●●●●○     │        │ #7 Rivera        ●●●●○     │
│ #3 Okafor        ●●○ │ ●●● │        │ #3 Okafor        ●●○ │ ●●● │
│ #12 Bell         ●○        │        │ #12 Bell         ●○        │
│         (scrollable)       │        │         (scrollable)       │
├────────────────────────────┤        ├────────────────────────────┤
│ NOW SERVING #7 Rivera      │        │ NEXT SERVER                │
│              Change  Undo  │        │                      Undo  │
├────────────────────────────┤        ├────────────────────────────┤
│  ┌────────┐  ┌──────────┐  │        │ [1 Layna ][4 Tegan][5 Aria]│
│  │  OUT   │  │ IN — no  │  │        │ [7 Ellis ][11 Mar ][13 Ch ]│
│  └────────┘  │  point   │  │        │ [15 Madd ][25 Kyla][55 Au ]│
│  ┌─────────────────────┐   │        │                            │
│  │   IN — POINT        │   │        │                            │
│  └─────────────────────┘   │        │                            │
└────────────────────────────┘        └────────────────────────────┘
          SERVING                          BETWEEN SERVERS
```

The lower block is **either** the outcome controls **or** the picker — never both, never a
disabled copy of either. That swap is what tells the operator which state they are in.

**Why this order**: the controls the operator touches without looking are lowest and largest; the information they glance at is above. Reversing this would put the tally under the thumb and the buttons out of reach.

---

## Interaction contract

| Operator action | System response | Source |
|---|---|---|
| Tap a player in the picker | That player becomes active server; a new turn opens; the picker is replaced by the outcome controls | `FR-015`, `FR-025` |
| Tap a *different* player while a server is active | Previous turn closes without recording a serve; new turn opens | `FR-026` |
| Tap **IN — POINT** | Serve recorded; **same player stays active**; the outcome controls stay put | `FR-020` |
| Tap **IN — no point** | Serve recorded; turn closes; the picker replaces the outcome controls | `FR-021` |
| Tap **OUT** | Serve recorded; turn closes; the picker replaces the outcome controls | `FR-021` |
| Tap **Change** while serving | The picker replaces the outcome controls; the control becomes **Cancel** | `FR-026` |
| Tap **undo** | Last action reversed; every visible figure updates in the same frame | `FR-040` |
| Tap **undo** with nothing to undo | Control is disabled | Edge case |
| Tap **End Match** | Confirmation, then match freezes and match *n+1* opens | `FR-010`, `FR-012` |

### Between servers

The most important state on the screen, because recording a serve against the wrong player is the failure this design exists to prevent.

A turn can only end two ways — a serve that wins no point, or a different player being chosen — so this state needs no announcement. The three large outcome controls are **replaced** by the player picker in the same place. That swap is the signal, and it is readable across a court without reading a word.

| Requirement | |
|---|---|
| No control capable of recording a serve is present — not disabled, absent | `FR-022` |
| The picker occupies the place the outcome controls normally hold | `FR-022` |
| The status row label reads **Next server** and carries a colour cue | `FR-022` |
| The picker needs no scrolling to reach any player on a 20-player roster | `SC-001` |
| Undo remains available | `FR-040` |

### The dock

One thin status row over exactly one action block. The picker and the outcome controls are never shown together and never both hidden, so the dock holds close to one height and the outcome controls sit in the same place every time they exist.

| State | Status row | Action block |
|---|---|---|
| Serving | `NOW SERVING` · player · Change · Undo | Outcome controls |
| Between servers | `NEXT SERVER` · Undo | Player picker |
| Serving, changing server | `NOW SERVING` · player · Cancel · Undo | Player picker |

### Tap cost

| Sequence | Taps |
|---|---|
| Serve that wins a point | 1 |
| Serve that ends the turn, then next server selected | 2 |
| Full side-out sequence | ≤ 2 (`SC-001`) |

---

## Tally mark contract

| Property | Rule | Source |
|---|---|---|
| One mark = one serve | Never aggregated into a number in the tally row | `FR-031` |
| Colour = the turn | Never the outcome | `FR-032` |
| Turn separator | A visible divider between adjacent turns | `FR-032` |
| Outcome encoding | Shape, not colour: filled = point, hollow = in-no-point, struck-through = out | `FR-034` |
| Over-limit turn | Turn group carries a visible warning marker when it holds > 5 serves | `FR-030` |
| Per-turn counts | Each turn group shows its own `serves / in` figures | `FR-035` |
| Truncation | Never. A 9-serve turn renders 9 marks and wraps | `FR-029` |

---

## Roster screen contract

| Rule | Source |
|---|---|
| Exactly as many rows as there are players. Zero placeholder rows, ever | `FR-003` |
| An empty roster shows a single call to action, not an empty table | `FR-003` |
| The add control is hidden or disabled at 20 players, with the limit stated | `FR-002` |
| Name and number are editable in place, at any time, including mid-game | `FR-005` |
| Deleting a player with recorded serves requires explicit confirmation naming the consequence | `FR-006` |
| Number accepts a leading zero and is treated as text | Data model §1 |

---

## Stats screen contract

| Rule | Source |
|---|---|
| Three scopes selectable: turn, match, game | `FR-036`, `FR-037` |
| Columns: serves, in, in %, points, turns | `FR-036` |
| Players with no serves are shown as such, never with misleading zeros in the % column | `FR-039` |
| In-progress match figures update live as serves are recorded | `FR-038` |
| Table scrolls vertically only — never horizontally | `FR-050`, `SC-011` |

---

## Platform behaviour contract

Every rule here is verified **on the device**, not in a desktop browser.

| Rule | Source |
|---|---|
| Portrait only; rotation does not reflow the layout | `FR-045` |
| Every control ≥ 44 pt; the three outcome controls substantially larger | `FR-047` |
| Outcome controls sit in the lower third, reachable by the holding thumb | `FR-046`, `SC-010` |
| No hover, keyboard, or right-click dependency anywhere | `FR-048` |
| Double-tap zoom, pinch zoom, and pull-to-refresh all suppressed | `FR-049` |
| No horizontal scroll on any screen at any supported width | `FR-050` |
| Safe-area insets respected top and bottom | `FR-051` |
| Text and marks meet WCAG AA contrast | `FR-052` |
| Launches full-screen from the Home Screen with no browser chrome | `FR-053` |
| A visible, persistent warning appears if storage cannot be written | `FR-058` |
| Every control has a visible `:active` state — the operator confirms a tap peripherally | `SC-002` |
| A double-tap on an outcome control records exactly one serve | `FR-023` |
