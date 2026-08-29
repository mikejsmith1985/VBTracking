// The offline guarantee rests entirely on the service worker's precache list being
// complete. A file added to the tree but forgotten here fails only on a phone in airplane
// mode, long after the mistake -- so it is checked here instead.
import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'
import { join, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const REPO_ROOT = resolve(fileURLToPath(new URL('../../', import.meta.url)))

// Directories whose every file is served to the browser and must therefore be cached.
const SHIPPED_DIRS = ['src', 'styles', 'icons']
const SHIPPED_ROOT_FILES = ['index.html', 'manifest.webmanifest']

const source = readFileSync(join(REPO_ROOT, 'sw.js'), 'utf8')

/** The precache list as the service worker actually declares it. */
function precacheList() {
  const block = source.match(/const PRECACHE = \[([\s\S]*?)\]/)
  expect(block, 'sw.js must declare a PRECACHE array').toBeTruthy()
  return [...block[1].matchAll(/'([^']+)'/g)].map((match) => match[1])
}

function filesUnder(directory) {
  return readdirSync(join(REPO_ROOT, directory), { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) return filesUnder(path)
    return [relative(REPO_ROOT, join(REPO_ROOT, path)).split('\\').join('/')]
  })
}

describe('precache list', () => {
  const precache = precacheList()

  it('caches every file that ships to the browser', () => {
    const shipped = [...SHIPPED_ROOT_FILES, ...SHIPPED_DIRS.flatMap(filesUnder)]
    const missing = shipped.filter((file) => !precache.includes(`./${file}`))
    expect(missing, `not precached: ${missing.join(', ')}`).toEqual([])
  })

  it('caches the app shell so a cold offline launch resolves', () => {
    expect(precache).toContain('./')
    expect(precache).toContain('./index.html')
  })

  it('lists nothing twice', () => {
    expect(new Set(precache).size).toBe(precache.length)
  })

  it('uses only relative paths, because Pages serves from a subpath', () => {
    const absolute = precache.filter((path) => path.startsWith('/') || path.includes('://'))
    expect(absolute, `root-absolute paths break install and offline: ${absolute}`).toEqual([])
  })
})

describe('caching strategy', () => {
  it('serves a cache hit without consulting the network (FR-055)', () => {
    expect(source).toMatch(/if \(cached\) return cached/)
  })

  it('falls back to the app shell for an unrecognised navigation', () => {
    expect(source).toContain("event.request.mode === 'navigate'")
  })

  it('versions the cache and deletes older ones on activate', () => {
    expect(source).toMatch(/const CACHE = 'vbtracking-v\d+'/)
    expect(source).toContain('caches.delete')
  })

  it('ignores non-GET requests', () => {
    expect(source).toContain("event.request.method !== 'GET'")
  })
})
