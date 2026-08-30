// Generates the app icons with no third-party dependency: PNG is encoded here directly
// from Node's built-in zlib. Run with `npm run icons` after changing the artwork.
import { deflateSync } from 'node:zlib'
import { writeFileSync, mkdirSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const OUTPUT_DIR = resolve(dirname(fileURLToPath(import.meta.url)), '..', 'icons')

const BACKGROUND = [0x0b, 0x0f, 0x14]
const BALL = [0x22, 0xd3, 0xee]
const SEAM = [0x0b, 0x0f, 0x14]

// Kept well inside the maskable safe zone so a circular or squircle mask cannot clip it.
const BALL_RADIUS_RATIO = 0.34
const SEAM_WIDTH = 0.1

/** Colours one pixel of the icon. */
function pixelAt(x, y, size) {
  const centre = size / 2
  const dx = x + 0.5 - centre
  const dy = y + 0.5 - centre
  const distance = Math.hypot(dx, dy)
  const radius = size * BALL_RADIUS_RATIO

  if (distance > radius) return BACKGROUND

  // Three curved seams, bent by the distance from the centre so they read as a ball
  // rather than as flat spokes.
  const normalised = distance / radius
  const seam = Math.abs(Math.sin(3 * Math.atan2(dy, dx) + 3.2 * normalised))
  return seam < SEAM_WIDTH ? SEAM : BALL
}

/** Raw RGB scanlines, each prefixed with a zero filter byte, as PNG expects. */
function rasterise(size) {
  const stride = size * 3 + 1
  const raw = Buffer.alloc(stride * size)

  for (let y = 0; y < size; y += 1) {
    raw[y * stride] = 0
    for (let x = 0; x < size; x += 1) {
      const [r, g, b] = pixelAt(x, y, size)
      const offset = y * stride + 1 + x * 3
      raw[offset] = r
      raw[offset + 1] = g
      raw[offset + 2] = b
    }
  }
  return raw
}

const CRC_TABLE = Array.from({ length: 256 }, (unused, index) => {
  let value = index
  for (let bit = 0; bit < 8; bit += 1) {
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
  length.writeUInt32BE(data.length)

  const body = Buffer.concat([Buffer.from(type, 'ascii'), data])
  const crc = Buffer.alloc(4)
  crc.writeUInt32BE(crc32(body))

  return Buffer.concat([length, body, crc])
}

/** Encodes an 8-bit RGB PNG. */
function encodePng(size) {
  const header = Buffer.alloc(13)
  header.writeUInt32BE(size, 0)
  header.writeUInt32BE(size, 4)
  header[8] = 8 // bit depth
  header[9] = 2 // colour type: truecolour RGB
  header[10] = 0 // deflate
  header[11] = 0 // adaptive filtering
  header[12] = 0 // no interlace

  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', header),
    chunk('IDAT', deflateSync(rasterise(size), { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ])
}

mkdirSync(OUTPUT_DIR, { recursive: true })

for (const [name, size] of [['icon-192.png', 192], ['icon-512.png', 512], ['apple-touch-icon.png', 180]]) {
  const target = resolve(OUTPUT_DIR, name)
  writeFileSync(target, encodePng(size))
  console.log(`wrote ${name} (${size}x${size})`)
}
