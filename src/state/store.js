// The only stateful module. Holds the append-only event log, replays it into derived
// state after every change, and persists it. Undo is "drop the last event and replay",
// which is what makes restoring statistics and turn boundaries exact rather than
// something inverse logic has to get right.
import { replay, rejectionReason } from '../domain/reducer.js'
import { undoableCount } from '../domain/stats.js'
import { EVENT } from '../domain/events.js'

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

  // The armed half of a two-step substitution. Interaction state, not history: it is
  // never appended to the log and never persisted, so a reload or a crash cannot leave a
  // substitution half-made.
  let armedForSubstitution = null

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

      // A pending substitution cannot outlive the thing it was pending against.
      if (event.t === EVENT.END_MATCH || event.t === EVENT.SUBSTITUTE) armedForSubstitution = null

      commit([...events, event])
      return { accepted: true, reason: null }
    },

    /** Arms a player for substitution. Transient; never recorded. */
    armSubstitution(playerId) { armedForSubstitution = playerId },

    /** The player armed for substitution, or null. */
    pendingSubstitution: () => armedForSubstitution,

    /** Cancels an armed substitution without recording anything. */
    clearSubstitution() { armedForSubstitution = null },

    /**
     * Replaces the entire log, for restoring a backup. The caller is responsible for
     * having validated the events and for having confirmed with the operator first --
     * this discards everything currently recorded.
     */
    replaceAll(nextEvents) {
      armedForSubstitution = null
      commit(nextEvents.slice())
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
