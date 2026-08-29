// The version shown on screen and the service worker's cache name decide the same thing:
// what a device is actually running. If they disagree, the badge lies at exactly the
// moment it is being trusted.
import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { APP_VERSION } from '../../src/ui/version.js'

const sw = readFileSync('sw.js', 'utf8')

describe('APP_VERSION', () => {
  it('is a version, not a placeholder', () => {
    expect(APP_VERSION).toMatch(/^v\d+$/)
  })

  it('matches the service worker cache name exactly', () => {
    const cache = sw.match(/const CACHE = 'vbtracking-(v\d+)'/)?.[1]
    expect(cache, 'sw.js must declare a versioned cache').toBeTruthy()
    expect(APP_VERSION, 'the badge would otherwise lie about what is running').toBe(cache)
  })

  it('is precached, or the badge would not survive going offline', () => {
    expect(sw).toContain("'./src/ui/version.js'")
  })
})

describe('the update path', () => {
  const app = readFileSync('src/ui/app.js', 'utf8')

  it('reloads once when a new worker takes over, so a fix lands on the first launch', () => {
    expect(app).toContain("addEventListener('controllerchange'")
    expect(app).toContain('window.location.reload()')
  })

  it('guards against reloading in a loop', () => {
    expect(app).toMatch(/if \(reloading\) return/)
  })

  it('sets no accept filter on the file picker, so iOS files stay selectable', () => {
    expect(app).toContain("removeAttribute('accept')")
    expect(app).not.toMatch(/input\.accept\s*=/)
  })
})
