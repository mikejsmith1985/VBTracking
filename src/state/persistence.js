// The only module permitted to touch localStorage. Storage was chosen synchronous on
// purpose: every tap writes, and a synchronous write cannot interleave with the next tap.
// Swapping to IndexedDB later means editing this file and nothing else.

/** Where the event log lives. Versioned so a future format change is recognisable. */
export const STORAGE_KEY = 'vbtracking.eventlog'

/** The envelope format this build understands. */
export const SCHEMA_VERSION = 1

/**
 * Builds the storage adapter. Never throws: a failure is reported as a status or an
 * `ok: false` result so the operator can be told, rather than losing serves silently.
 */
export function createLocalStoragePersistence(storage = globalThis.localStorage) {
  return {
    /** Reads the stored log. Returns an empty log plus a status for anything unusable. */
    load() {
      let raw
      try {
        raw = storage.getItem(STORAGE_KEY)
      } catch {
        return { events: [], status: 'unavailable' }
      }

      if (!raw) return { events: [], status: 'ok' }

      let parsed
      try {
        parsed = JSON.parse(raw)
      } catch {
        return { events: [], status: 'corrupt' }
      }

      if (!parsed || typeof parsed !== 'object') return { events: [], status: 'corrupt' }
      if (parsed.schemaVersion !== SCHEMA_VERSION) return { events: [], status: 'unsupported-version' }
      if (!Array.isArray(parsed.events)) return { events: [], status: 'corrupt' }

      return { events: parsed.events, status: 'ok' }
    },

    /** Writes the whole log. Reports failure rather than throwing. */
    save(events) {
      try {
        storage.setItem(STORAGE_KEY, JSON.stringify({ schemaVersion: SCHEMA_VERSION, events }))
        return { ok: true }
      } catch {
        return { ok: false }
      }
    },

    /** Asks the browser not to evict this app's data. Best effort; never throws. */
    async requestPersistent() {
      const manager = globalThis.navigator?.storage
      if (!manager?.persist) return false
      try {
        return await manager.persist()
      } catch {
        return false
      }
    },
  }
}
