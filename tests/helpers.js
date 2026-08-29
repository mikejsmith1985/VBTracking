// Shared builders for the test suites. Keeps each test focused on the rule it proves
// rather than on the ceremony of constructing an event log.
import { replay } from '../src/domain/reducer.js'
import * as E from '../src/domain/events.js'

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
