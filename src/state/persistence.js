// The only module permitted to touch localStorage. Storage was chosen synchronous on
// purpose: every tap writes, and a synchronous write cannot interleave with the next tap.
// Swapping to IndexedDB later means editing this file and nothing else.
import { SCHEMA_VERSION, migrate } from '../domain/migrations.js'

/** Where the event log lives. */
export const STORAGE_KEY = 'vbtracking.eventlog'

export { SCHEMA_VERSION }

/**
 * Builds the storage adapter. Never throws: a failure is reported as a status or an
 * `ok: false` result so the operator can be told, rather than losing serves silently.
 */
export function createLocalStoragePersistence(storage = globalThis.localStorage) {
  /** Writes the whole log stamped with the current version. Reports failure, never throws. */
  function save(events) {
    try {
      storage.setItem(STORAGE_KEY, JSON.stringify({ schemaVersion: SCHEMA_VERSION, events }))
      return { ok: true }
    } catch {
      return { ok: false }
    }
  }

  return {
    /**
     * Reads the stored log, carrying an older format forward rather than refusing it --
     * refusing is how a released schema change would cost someone their season.
     */
    load() {
      let raw
      try {
        raw = storage.getItem(STORAGE_KEY)
      } catch {
        return empty('unavailable')
      }

      if (!raw) return { events: [], status: 'ok', migratedFrom: null }

      let parsed
      try {
        parsed = JSON.parse(raw)
      } catch {
        return empty('corrupt')
      }

      if (!parsed || typeof parsed !== 'object') return empty('corrupt')
      if (!Array.isArray(parsed.events)) return empty('corrupt')

      const storedVersion = parsed.schemaVersion
      if (storedVersion === SCHEMA_VERSION) {
        return { events: parsed.events, status: 'ok', migratedFrom: null }
      }

      const carried = migrate(parsed.events, storedVersion)
      if (!carried.ok) {
        return empty(Number.isInteger(storedVersion) && storedVersion > SCHEMA_VERSION
          ? 'unsupported-version'
          : 'corrupt')
      }

      // Stamp the carried-forward log so the next load takes the direct path. A failed
      // write-back is not fatal: the app runs from what it read and the original is left
      // exactly as it was, which is never worse than not having tried.
      save(carried.events)

      return { events: carried.events, status: 'ok', migratedFrom: storedVersion }
    },

    save,

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

function empty(status) {
  return { events: [], status, migratedFrom: null }
}
