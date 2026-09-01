// The two native app icons, written from the shared neon renderer.
//
// The drawing lives in `neon-icon.mjs`, which the web app's icons come from too -- they were
// two scripts once and drifted into two different pictures. Run with `node
// scripts/generate-app-icon.mjs` after changing the artwork or the look.
import { writeFileSync, mkdirSync } from 'node:fs'
import { dirname, resolve, relative } from 'node:path'
import { fileURLToPath } from 'node:url'
import { neonIcon } from './neon-icon.mjs'

const HERE = dirname(fileURLToPath(import.meta.url))

// Xcode wants one 1024 image per app icon and makes every other size from it. The frame
// follows what each platform crops to: a squircle on the phone, a circle on the watch.
const TARGETS = [
  ['../ios/VBTracker/Assets.xcassets/AppIcon.appiconset', 'ios', 'rounded'],
  ['../ios/VBTrackerWatch/Assets.xcassets/AppIcon.appiconset', 'watchos', 'circle'],
]

const CONTENTS = (platform) => `${JSON.stringify({
  images: [{ filename: 'icon-1024.png', idiom: 'universal', platform, size: '1024x1024' }],
  info: { author: 'xcode', version: 1 },
}, null, 2)}\n`

for (const [directory, platform, frame] of TARGETS) {
  const target = resolve(HERE, directory)
  mkdirSync(target, { recursive: true })
  writeFileSync(resolve(target, 'icon-1024.png'), neonIcon({ frame }))
  writeFileSync(resolve(target, 'Contents.json'), CONTENTS(platform))
  console.log(`wrote ${relative(resolve(HERE, '..'), target)}/icon-1024.png`)
}
