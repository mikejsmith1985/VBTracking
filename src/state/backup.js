// Builds and parses the backup file. This module only produces and reads a payload --
// delivering it to the operator (the iOS share sheet, a download) and reading one back
// (a file input) are interface concerns and live in src/ui/. Keeping the rules here means
// they are testable in Node, with no browser and no file system.
import { SCHEMA_VERSION, migrate } from '../domain/migrations.js'

/** Marks a file as one of ours, so an unrelated JSON file is refused rather than loaded. */
export const EXPORT_MARKER = 'vbtracking'

/**
 * Builds the export payload. `now` is a parameter rather than read from the clock so the
 * module stays pure and its output is reproducible in a test.
 */
export function buildExport(events, now = new Date()) {
  return JSON.stringify({
    app: EXPORT_MARKER,
    schemaVersion: SCHEMA_VERSION,
    exportedAt: now.toISOString(),
    events,
  }, null, 2)
}

/** A filename the operator can recognise among several backups. */
export function exportFilename(now = new Date()) {
  return `vbtracking-backup-${now.toISOString().slice(0, 10)}.json`
}

/**
 * Reads an export payload. Never throws: every failure is a returned reason, because a
 * bad file must leave the operator's existing data completely untouched.
 */
export function parseImport(text) {
  let parsed
  try {
    parsed = JSON.parse(text)
  } catch {
    return failure('That file is not readable. It may be damaged or incomplete.')
  }

  if (!parsed || typeof parsed !== 'object') {
    return failure('That file is not a Serve Tracker backup.')
  }
  if (parsed.app !== EXPORT_MARKER) {
    return failure('That file is not a Serve Tracker backup.')
  }
  if (!Array.isArray(parsed.events)) {
    return failure('That backup has no recorded data in it.')
  }

  const carried = migrate(parsed.events, parsed.schemaVersion)
  if (!carried.ok) return failure(carried.reason)

  return { events: carried.events, ok: true, reason: null, exportedAt: parsed.exportedAt ?? null }
}

function failure(reason) {
  return { events: [], ok: false, reason, exportedAt: null }
}
