// Service worker. Cache-first against an explicit precache list, so that after install
// the app makes no network requests at all (FR-055). The list below is the actual file
// tree -- there is no build step and no generated manifest, so it can be read and checked
// by a human, which is the whole reason this project ships no bundler.

// Bump on every release. A new version fully replaces the old rather than serving a mix.
const CACHE = 'vbtracking-v5'

const PRECACHE = [
  './',
  './index.html',
  './manifest.webmanifest',
  './styles/app.css',
  './styles/v3.css',
  './src/ui/app.js',
  './src/ui/html.js',
  './src/ui/screens/track.js',
  './src/ui/screens/lineup.js',
  './src/ui/screens/season.js',
  './src/ui/screens/career.js',
  './src/ui/screens/gameform.js',
  './src/ui/screens/roster.js',
  './src/ui/screens/stats.js',
  './src/ui/components/tally.js',
  './src/ui/components/statstable.js',
  './src/ui/components/chip.js',
  './src/state/store.js',
  './src/state/persistence.js',
  './src/state/backup.js',
  './src/state/historical-import.js',
  './src/domain/events.js',
  './src/domain/reducer.js',
  './src/domain/stats.js',
  './src/domain/palette.js',
  './src/domain/migrations.js',
  './src/domain/aggregate.js',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/apple-touch-icon.png',
]

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE)
      .then((cache) => cache.addAll(PRECACHE))
      .then(() => self.skipWaiting()),
  )
})

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((names) => Promise.all(names.filter((name) => name !== CACHE).map((name) => caches.delete(name))))
      .then(() => self.clients.claim()),
  )
})

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return

  event.respondWith(
    caches.match(event.request).then((cached) => {
      // A cache hit is served without touching the network at all -- not "network first
      // with a fallback". That is what makes the zero-request claim true rather than likely.
      if (cached) return cached

      // A navigation the cache does not recognise (a deep link, a stale URL) still has to
      // resolve offline, so it falls back to the app shell.
      if (event.request.mode === 'navigate') {
        return caches.match('./index.html').then((shell) => shell ?? fetch(event.request))
      }

      return fetch(event.request).catch(() => Response.error())
    }),
  )
})
