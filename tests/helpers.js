// Shared builders for the test suites. Keeps each test focused on the rule it proves
// rather than on the ceremony of constructing an event log.
import { replay } from '../src/domain/reducer.js'
import * as E from '../src/domain/events.js'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

/** Builds derived state from the events given, in order. Nested arrays are flattened. */
export function build(...events) {
  return replay(events.flat(Infinity))
}

/** Produces ADD_PLAYER events for `count` players, ids p1..pN. */
export function roster(count) {
  return Array.from({ length: count }, (unused, index) =>
    E.addPlayer(`p${index + 1}`, `Player ${index + 1}`, String(index + 1)),
  )
}

/** Produces a serve turn for one player: `pointCount` points followed by a closing serve. */
export function turn(playerId, pointCount, closingOutcome = E.OUTCOME.OUT) {
  return [
    E.selectServer(playerId),
    ...Array.from({ length: pointCount }, () => E.recordServe(E.OUTCOME.IN_POINT)),
    E.recordServe(closingOutcome),
  ]
}

/** An in-memory stand-in for the storage adapter, for unit-testing the store. */
export function memoryPersistence() {
  let savedEvents = []
  return {
    load: () => ({ events: savedEvents.slice(), status: 'ok' }),
    save: (events) => {
      savedEvents = events.slice()
      return { ok: true }
    },
    requestPersistent: async () => true,
  }
}

/**
 * The app's own shell, read from index.html rather than copied into each test.
 *
 * A hand-copied shell drifts: a container added to the page for a new screen is missing
 * here, and every UI test dies on it at once -- which says the tests are out of date, not
 * that the app is broken. Reading the real file is the only version that cannot drift.
 */
export function appShell() {
  // Resolved from the working directory: under jsdom, import.meta.url is not a file URL.
  const html = readFileSync(join(process.cwd(), 'index.html'), 'utf8')
  const body = html.match(/<div class="app">[\s\S]*?<\/div>\s*<script/)
  if (!body) throw new Error('index.html no longer contains the app shell')
  return body[0].replace(/<script$/, '')
}
