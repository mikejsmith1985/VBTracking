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
┌────────────────────────────┐
│ Match 2 of 3   ·  17 pts   │  ← header: match position, points on serve,
│                    [End]   │     target badge when ≥21, End Match
├────────────────────────────┤
│ #7 Rivera        ●●●●○     │  ← tally board, scrolls vertically.
│ #3 Okafor        ●●○ │ ●●● │     one row per player who has served.
│ #12 Bell         ●○        │     │ separates turns; colour = turn.
│                            │
│         (scrollable)       │
├────────────────────────────┤
│  NOW SERVING               │  ← server strip: current server, or the
│  #7  RIVERA        [undo]  │     side-out prompt. Always visible.
├────────────────────────────┤
│  ┌────────┐  ┌──────────┐  │
│  │  OUT   │  │ IN — no  │  │  ← outcome controls. Thumb zone.
│  └────────┘  │  point   │  │     Disabled and dimmed when no
│  ┌─────────────────────┐   │     server is selected.
│  │   IN — POINT        │   │
│  └─────────────────────┘   │
└────────────────────────────┘
```

**Why this order**: the controls the operator touches without looking are lowest and largest; the information they glance at is above. Reversing this would put the tally under the thumb and the buttons out of reach.

---

## Interaction contract

| Operator action | System response | Source |
|---|---|---|
| Tap a player in the tally board or picker | That player becomes active server; a new turn opens; outcome controls enable | `FR-015`, `FR-025` |
| Tap a *different* player while a server is active | Previous turn closes without recording a serve; new turn opens | `FR-026` |
| Tap **IN — POINT** | Serve recorded; **same player stays active**; controls stay enabled | `FR-020` |
| Tap **IN — no point** | Serve recorded; turn closes; screen enters side-out state | `FR-021` |
| Tap **OUT** | Serve recorded; turn closes; screen enters side-out state | `FR-021` |
| Tap an outcome control in side-out state | Nothing. Controls are disabled, not merely ignored | `FR-022` |
| Tap **undo** | Last action reversed; every visible figure updates in the same frame | `FR-040` |
| Tap **undo** with nothing to undo | Control is disabled | Edge case |
| Tap **End Match** | Confirmation, then match freezes and match *n+1* opens | `FR-010`, `FR-012` |

### Side-out state

The most important visual state on the screen, because recording a serve against the wrong player is the failure this design exists to prevent.

| Requirement | |
|---|---|
| The server strip reads **SIDE OUT — select next server** | `FR-022` |
| All three outcome controls are `disabled`, dimmed, and non-interactive | `FR-022` |
| The state is distinguishable at arm's length without reading | `SC-002` |
| The player picker is immediately reachable without scrolling | `SC-001` |

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
