// The stored-data version chain. Pure: it transforms an event array and knows nothing
// about storage, so every branch is testable without a browser.
//
// Release 002 only ADDS event types, so a release-001 log is already a valid release-002
// log and the 1 -> 2 step does nothing. Building the chain anyway is the point: the
// mechanism has to exist before a release needs it to do real work, and today's identity
// step is the test case proving it runs.

/** The data format this build writes and understands. */
export const SCHEMA_VERSION = 2

/**
 * Ordered steps. MIGRATIONS[n] upgrades a log at version n to version n+1.
 * Every step is pure and must return a new array.
 */
export const MIGRATIONS = Object.freeze({
  // 1 -> 2: release 002 adds SET_LINEUP, SUBSTITUTE and CLEAR_LINEUP. Every release-001
  // event keeps its exact shape and meaning, so nothing needs rewriting.
  1: (events) => events.slice(),
})

/**
 * Carries an event log forward from `fromVersion` to the current version.
 * Never throws: a failure is a returned reason, because a corrupt or future log must not
 * take down the app on startup.
 */
export function migrate(events, fromVersion, options = {}) {
  const migrations = options.migrations ?? MIGRATIONS
  const targetVersion = options.targetVersion ?? SCHEMA_VERSION

  if (!Number.isInteger(fromVersion) || fromVersion < 1) {
    return failure(`Stored data has an unrecognised version (${String(fromVersion)}).`)
  }
  if (fromVersion > targetVersion) {
    return failure('Stored data was written by a newer version of this app.')
  }

  let carried = events.slice()
  for (let version = fromVersion; version < targetVersion; version += 1) {
    const step = migrations[version]
    if (typeof step !== 'function') {
      return failure(`No way to carry data forward from version ${version}.`)
    }
    carried = step(carried)
  }

  return { events: carried, ok: true, reason: null }
}

function failure(reason) {
  return { events: [], ok: false, reason }
}
