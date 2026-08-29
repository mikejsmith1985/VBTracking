// The only stateful module. Holds the append-only event log, replays it into derived
// state after every change, and persists it. Undo is "drop the last event and replay",
// which is what makes restoring statistics and turn boundaries exact rather than
// something inverse logic has to get right.
import { replay, rejectionReason } from '../domain/reducer.js'
import { undoableCount } from '../domain/stats.js'

/**
 * Creates the application store over a storage adapter.
 * The adapter is injected so the store can be unit-tested without a browser.
 */
export function createStore(persistence) {
  const loaded = persistence.load()
  const listeners = new Set()

  let events = loaded.events
  let state = replay(events)
  let status = loaded.status

  function commit(nextEvents) {
    events = nextEvents
    state = replay(events)
    const result = persistence.save(events)
    if (status === 'ok' || result.ok) status = result.ok ? 'ok' : 'unavailable'
    for (const listener of listeners) listener(state)
  }

  return {
    /** Current derived state. Never mutate it. */
    getState: () => state,

    /** A copy of the event log. */
    getEvents: () => events.slice(),

    /** Appends an event if the rules accept it, reporting why when they do not. */
    dispatch(event) {
      const reason = rejectionReason(state, event)
      if (reason) return { accepted: false, reason }
      commit([...events, event])
      return { accepted: true, reason: null }
    },

    /** Removes the most recent undoable event and replays. */
    undo() {
      if (undoableCount(events) === 0) return { undone: false }
      commit(events.slice(0, -1))
      return { undone: true }
    },

    /** True when there is an event that may still be undone in the current match. */
    canUndo: () => undoableCount(events) > 0,

    /** Registers a listener, returning a function that removes it. */
    subscribe(listener) {
      listeners.add(listener)
      return () => listeners.delete(listener)
    },

    /** 'ok' | 'unavailable' | 'corrupt' | 'unsupported-version' */
    storageStatus: () => status,

    /** Asks the browser to keep this app's data. Best effort. */
    requestPersistent: () => persistence.requestPersistent?.() ?? Promise.resolve(false),
  }
}
