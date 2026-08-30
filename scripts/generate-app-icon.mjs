// The native app icon: a player striking, and the ball above them.
//
// Drawn here rather than imported, for the same reason the web icons are: this project
// ships no dependencies, and an icon that can be regenerated from source is one that can be
// adjusted without hunting for whoever has the original file.
//
// The figure is built from circles and capsules -- thick line segments -- because that is
// what a silhouette of a person actually is at icon size. Every coordinate below is a
// fraction of the square, so the same drawing produces any size.
import { deflateSync } from 'node:zlib'
import { writeFileSync, mkdirSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))

// Pale blue behind, near-black in front: the same near-black the app itself is painted in,
// so the icon and the first screen agree with each other.
const BACKGROUND = [0xcf, 0xe6, 0xf5]
const FIGURE = [0x0b, 0x0f, 0x14]

// The ball sits clear of the hand. Touching, they read as one object -- a mallet -- and
// the whole point of the picture is the moment before the strike.
const BALL = { x: 0.740, y: 0.132, r: 0.100 }
const HEAD = { x: 0.393, y: 0.272, r: 0.079 }

// [fromX, fromY, toX, toY, halfThickness]
const LIMBS = [
  [0.404, 0.334, 0.428, 0.395, 0.034],  // neck
  [0.428, 0.395, 0.500, 0.570, 0.082],  // torso
  [0.492, 0.408, 0.590, 0.300, 0.040],  // upper arm, striking
  [0.590, 0.300, 0.632, 0.256, 0.036],  // forearm, striking
  [0.380, 0.425, 0.268, 0.395, 0.038],  // upper arm, balancing
  [0.268, 0.395, 0.163, 0.374, 0.034],  // forearm, balancing
  [0.466, 0.565, 0.340, 0.660, 0.058],  // thigh, leading
  [0.340, 0.660, 0.298, 0.800, 0.044],  // shin, leading
  [0.298, 0.800, 0.226, 0.828, 0.032],  // foot, leading
  [0.520, 0.565, 0.606, 0.686, 0.052],  // thigh, trailing
  [0.606, 0.686, 0.532, 0.816, 0.042],  // shin, trailing
  [0.532, 0.816, 0.462, 0.848, 0.030],  // foot, trailing
]

// Pulled very slightly in from the edges: an iOS icon is masked to a rounded square, and
// anything in the corners is the first thing to go.
const SCALE = 0.94
const OFFSET = 0.01

function place(x, y) {
  return [(x - 0.5) * SCALE + 0.5 + OFFSET, (y - 0.5) * SCALE + 0.5 + OFFSET]
}

/** True when the point lands on the player or the ball. */
function isInk(x, y) {
  const [ballX, ballY] = place(BALL.x, BALL.y)
  if ((x - ballX) ** 2 + (y - ballY) ** 2 <= (BALL.r * SCALE) ** 2) return true

  const [headX, headY] = place(HEAD.x, HEAD.y)
  if ((x - headX) ** 2 + (y - headY) ** 2 <= (HEAD.r * SCALE) ** 2) return true

  for (const [fromX, fromY, toX, toY, half] of LIMBS) {
    const [x1, y1] = place(fromX, fromY)
    const [x2, y2] = place(toX, toY)
    const dx = x2 - x1
    const dy = y2 - y1
    const along = Math.max(0, Math.min(1, ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)))
    const nearX = x1 + along * dx
    const nearY = y1 + along * dy
    if ((x - nearX) ** 2 + (y - nearY) ** 2 <= (half * SCALE) ** 2) return true
  }
  return false
}

// Four samples across and down per pixel. Without it the arms and the ball's edge come out
// as staircases, which is exactly what the eye notices on a home screen.
const SAMPLES = 4

/** One row of pixels, filtered for PNG. */
function rasterise(size) {
  const stride = size * 3
  const raw = Buffer.alloc(size * (stride + 1))

  for (let row = 0; row < size; row++) {
    const start = row * (stride + 1)
    raw[start] = 0 // no per-row filtering

    for (let column = 0; column < size; column++) {
      let hits = 0
      for (let sy = 0; sy < SAMPLES; sy++) {
        for (let sx = 0; sx < SAMPLES; sx++) {
          const x = (column + (sx + 0.5) / SAMPLES) / size
          const y = (row + (sy + 0.5) / SAMPLES) / size
          if (isInk(x, y)) hits += 1
        }
      }

      const ink = hits / (SAMPLES * SAMPLES)
      const at = start + 1 + column * 3
      for (let channel = 0; channel < 3; channel++) {
        raw[at + channel] = Math.round(BACKGROUND[channel] * (1 - ink) + FIGURE[channel] * ink)
      }
    }
  }
  return raw
}

// --- PNG encoding, the same as the web icons use --------------------------------

const CRC_TABLE = Array.from({ length: 256 }, (unused, index) => {
  let value = index
  for (let bit = 0; bit < 8; bit++) {
    value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1
  }
  return value >>> 0
})

function crc32(buffer) {
  let crc = 0xffffffff
  for (const byte of buffer) crc = CRC_TABLE[(crc ^ byte) & 0xff] ^ (crc >>> 8)
  return (crc ^ 0xffffffff) >>> 0
}

function chunk(type, data) {
  const length = Buffer.alloc(4)
  length.writeUInt32BE(data.length, 0)
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data])
  const crc = Buffer.alloc(4)
  crc.writeUInt32BE(crc32(body), 0)
  return Buffer.concat([length, body, crc])
}

function encodePng(size) {
  const header = Buffer.alloc(13)
  header.writeUInt32BE(size, 0)
  header.writeUInt32BE(size, 4)
  header[8] = 8  // bit depth
  header[9] = 2  // truecolour RGB
  header[10] = 0
  header[11] = 0
  header[12] = 0

  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', header),
    chunk('IDAT', deflateSync(rasterise(size), { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ])
}

// --- Writing ---------------------------------------------------------------------

// Xcode wants one 1024 image per app icon and makes every other size from it.
const TARGETS = [
  ['../ios/VBTracker/Assets.xcassets/AppIcon.appiconset', 'ios'],
  ['../ios/VBTrackerWatch/Assets.xcassets/AppIcon.appiconset', 'watchos'],
]

const CONTENTS = (platform) => JSON.stringify({
  images: [{ filename: 'icon-1024.png', idiom: 'universal', platform, size: '1024x1024' }],
  info: { author: 'xcode', version: 1 },
}, null, 2) + String.fromCharCode(10)

const png = encodePng(1024)

for (const [relative, platform] of TARGETS) {
  const directory = resolve(HERE, relative)
  mkdirSync(directory, { recursive: true })
  writeFileSync(resolve(directory, 'icon-1024.png'), png)
  writeFileSync(resolve(directory, 'Contents.json'), CONTENTS(platform))
  console.log(`wrote ${relative}/icon-1024.png`)
}
