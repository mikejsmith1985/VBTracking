// The web app's icons, written from the same neon renderer as the native ones.
//
// They used to be a drawn volleyball, computed here, while the native apps carried the
// player and the ball -- the same product wearing two faces depending on how it was
// installed. Run with `npm run icons` after changing the artwork or the look.
//
// The frame differs by where the icon ends up. `icon-512` is declared `maskable`, and a
// maskable icon may be cropped to a circle of 80% of its width, so a rounded rectangle would
// lose its corners -- those two get the circle. The Apple touch icon is cropped to the same
// squircle as the native app, and gets the same rounded frame, so the web app and the native
// app sit side by side on an iPhone home screen looking like one thing.
import { writeFileSync, mkdirSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { neonIcon } from './neon-icon.mjs'

const OUTPUT_DIR = resolve(dirname(fileURLToPath(import.meta.url)), '..', 'icons')

const ICONS = [
  ['icon-192.png', 192, 'circle'],
  ['icon-512.png', 512, 'circle'],
  ['apple-touch-icon.png', 180, 'rounded'],
]

mkdirSync(OUTPUT_DIR, { recursive: true })
for (const [name, size, frame] of ICONS) {
  writeFileSync(resolve(OUTPUT_DIR, name), neonIcon({ frame, size }))
  console.log(`wrote icons/${name} (${size}x${size})`)
}
