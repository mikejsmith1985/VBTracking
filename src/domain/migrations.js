// The stored-data version chain. Pure: it transforms an event array and knows nothing
// about storage, so every branch is testable without a browser.

/** The data format this build writes and understands. */
export const SCHEMA_VERSION = 3

/** The season a migrated log is gathered into. Renameable by the operator afterwards. */
export const MIGRATED_SEASON_ID = 'season-1'
const MIGRATED_SEASON_NAME = 'Season 1'
const MIGRATED_TEAM_NAME = 'My Team'

// The format releases 1 and 2 were played under. Recorded so a later release can vary it
// without touching stored data.
const LEGACY_FORMAT = { matchesPerGame: 3, targetScore: 21, playersOnCourt: 6 }

/** Events that describe roster membership or game ownership, and so need a season. */
const NEEDS_SEASON = new Set(['ADD_PLAYER', 'EDIT_PLAYER', 'REMOVE_PLAYER', 'START_GAME'])

/**
 * 1 -> 2: release 002 only added event types, so a release-001 log is already valid.
 * Kept as the proof that the chain runs.
 */
function migrateOneToTwo(events) {
  return events.slice()
}

/**
 * 2 -> 3: the first migration that does real work.
 *
 * Deliberately ADDITIVE. It prepends one season and stamps a field onto the events that
 * now need one. It renames nothing, splits nothing, and moves no event other than by the
 * single prepend.
 *
 * The tidier migration would decompose each ADD_PLAYER into a career player plus a season
 * membership -- two events where there was one. It matches the new model exactly and it is
 * far riskier: every index shifts, so a bug becomes silent corruption of the only real
 * season anyone has recorded, rather than a visibly wrong number.
 *
 * An ended match becomes `undecided`, never `lost`. Silence is not a defeat, and a record
 * that assumed otherwise would be wrong about games already played.
 */
function migrateTwoToThree(events) {
  const season = {
    t: 'CREATE_SEASON',
    id: MIGRATED_SEASON_ID,
    name: MIGRATED_SEASON_NAME,
    team: MIGRATED_TEAM_NAME,
    format: { ...LEGACY_FORMAT },
  }

  const stamped = events.map((event) => {
    if (NEEDS_SEASON.has(event.t)) return { ...event, seasonId: MIGRATED_SEASON_ID }
    if (event.t === 'END_MATCH') return { ...event, result: 'undecided' }
    return event
  })

  return [season, ...stamped]
}

/**
 * Ordered steps. MIGRATIONS[n] upgrades a log at version n to version n+1.
 * Every step is pure and must return a new array.
 */
export const MIGRATIONS = Object.freeze({
  1: migrateOneToTwo,
  2: migrateTwoToThree,
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
