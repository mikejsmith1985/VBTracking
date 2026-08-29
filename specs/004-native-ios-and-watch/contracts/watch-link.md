# Contract: The link between the phone and the watch

**Feature**: `specs/004-native-ios-and-watch/`

Two directions, two different guarantees, because they want opposite things. Out goes a
picture where only the newest one matters. Back come events, where every one matters and none
may arrive twice.

---

## Phone → watch: the court snapshot

**Channel**: `updateApplicationContext` — latest wins, coalescing, delivered when the watch
next wakes. Plus `sendMessage` while the watch is reachable, for the seconds that matter
during a rally.

**Payload**

```json
{
  "sequence": 412,
  "capturedAt": "2026-08-29T18:04:11Z",
  "scope": "match",
  "scopeLabel": "Match 2",
  "servingPosition": 3,
  "positions": [
    { "court": 1, "number": "7",  "inPercentage": 0.62, "points": 4, "isServing": true,  "isOnDeck": false },
    { "court": 2, "number": "12", "inPercentage": null, "points": 0, "isServing": false, "isOnDeck": true  },
    { "court": 3, "number": "4",  "inPercentage": 0.80, "points": 2, "isServing": false, "isOnDeck": false },
    { "court": 4, "number": "15", "inPercentage": 0.50, "points": 1, "isServing": false, "isOnDeck": false },
    { "court": 5, "number": "3",  "inPercentage": 0.75, "points": 3, "isServing": false, "isOnDeck": false },
    { "court": 6, "number": null, "inPercentage": null, "points": null, "isServing": false, "isOnDeck": false }
  ]
}
```

**Rules**

| Rule | Why |
|---|---|
| `sequence` increases by one per snapshot; the watch discards anything not newer than it holds | Snapshots can arrive out of order; the older one must never win |
| `inPercentage` is `null`, not `0`, when nothing has been served | A dash on the wrist, exactly as on the phone (FR-006) |
| `points` is `null` where points were never recorded | Same rule, same reason |
| `number: null` means nobody is standing in that position | A short bench is shown as short, not hidden (FR-010) |
| No `isOnDeck` at all when there is no lineup | The watch says it cannot name the next server rather than presenting one (FR-009) |
| The snapshot carries figures, not the log | The watch draws six boxes; it has no use for a season |
| A snapshot is sent after every event that changes the court | Including substitutions, so the coach's decision is never one serve out of date |

**Staleness**: the watch shows how long ago `capturedAt` was, and marks itself not-current
once contact has been lost beyond the threshold. A quietly stale court is worse than a blank
one — the coach would substitute on a percentage that has since moved (FR-013).

---

## Watch → phone: recorded events

**Channel**: `transferUserInfo` — queued, FIFO, delivered even when the phone app is not
running, and it survives the watch going out of range and coming back.

**Payload**

```json
{
  "events": [
    { "id": "c41a…", "t": "RECORD_SERVE", "outcome": "OUT", "recordedAt": "2026-08-29T18:04:19Z" }
  ]
}
```

**Rules**

| Rule | Why |
|---|---|
| The `id` is made on the watch, when the coach taps | It is the identity of that tap, not of its delivery |
| The phone ignores an `id` it already holds | Delivery may retry; the record may not double (FR-020) |
| Events are appended to the phone's log unchanged | A watch-recorded serve is indistinguishable from a phone-recorded one (FR-019) |
| The phone applies its own rules to them | A serve the reducer rejects is rejected the same way whichever device sent it |
| The watch keeps an event until the phone confirms it | `pendingCount` is what the wrist shows, so a serve recorded out of range is never assumed safe (FR-022) |
| Ordering is the queue's order, not a timestamp's | `recordedAt` is for the operator to read, never for resolving conflicts |

**When the two disagree**: they do not. The phone holds the truth (FR-019). The watch sends
what it recorded; the phone decides what the record is. If a serve is recorded on both
devices, the result is two serves in the record — visible, and removable with the correction
tools that already exist. This is deliberate: silently merging two people's taps would mean
guessing which one was real.

---

## What the link may never do

- **Block the phone.** Nothing in the recording loop waits on the watch, or on the link
  (FR-015). A phone with no watch paired behaves identically.
- **Need a network.** WatchConnectivity is local. There is no internet in the gym (FR-016).
- **Lose a serve.** An event queued on the watch is delivered or still pending; it is never
  dropped.
- **Record by accident.** Recording is a button. Never a gesture, never the crown, never a
  raise-to-wake side effect (FR-024).

---

## Testing this without two devices

The connectivity session sits behind a small protocol, and the tests drive a fake:

| Test | Fake behaviour |
|---|---|
| Snapshot reaches the watch | Delivers immediately |
| Out-of-order snapshots | Delivers `sequence` 5 then 4; the watch keeps 5 |
| Out of contact | Drops everything, then reconnects and flushes |
| Duplicate delivery | Delivers the same event twice; the log holds it once |
| Pending count | Queues without confirming; the wrist shows what has not landed |

The real session is exercised on the interface layer, on a real watch, in a real gym — which
is the only place the 3-second figure in SC-002 means anything.
