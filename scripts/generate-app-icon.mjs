// The native app icon: the player striking, and the ball above them.
//
// The shape is the artwork the stakeholder chose, not a redrawing of it. It lives beside
// this script as `assets/app-icon-figure.png` -- a traced silhouette, white on black, at
// icon size -- and this script paints it: figure colour through the white, background
// colour through the black.
//
// Kept as a mask rather than a finished icon so the two colours stay adjustable without
// re-tracing, and so the watch and the phone cannot drift apart. `assets/app-icon-source.jpg`
// is the original the mask was traced from, committed so the trace can be redone.
//
// No image library: the mask is a plain 8-bit greyscale PNG, which is a zlib stream of
// filtered rows, and Node can inflate that on its own.
import { deflateSync, inflateSync } from 'node:zlib'
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { dirname, resolve, relative } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))

// Pale blue behind, near-black in front: the same near-black the app itself is painted in,
// so the icon and the first screen agree with each other.
const BACKGROUND = [0xcf, 0xe6, 0xf5]
const FIGURE = [0x0b, 0x0f, 0x14]

/** The bytes of one PNG chunk, length and CRC included. */
function chunk(type, body) {
  const head = Buffer.alloc(4)
  head.writeUInt32BE(body.length)
  const typed = Buffer.concat([Buffer.from(type, 'ascii'), body])
  const crc = Buffer.alloc(4)
  crc.writeUInt32BE(crc32(typed) >>> 0)
  return Buffer.concat([head, typed, crc])
}

const CRC_TABLE = Array.from({ length: 256 }, (_, index) => {
  let value = index
  for (let bit = 0; bit < 8; bit += 1) {
    value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1
  }
  return value >>> 0
})

function crc32(buffer) {
  let value = 0xffffffff
  for (const byte of buffer) value = CRC_TABLE[(value ^ byte) & 0xff] ^ (value >>> 8)
  return (value ^ 0xffffffff) >>> 0
}

const SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])

/**
 * Reads an 8-bit greyscale PNG into one byte per pixel.
 *
 * Only the shape this project's own mask has: no interlacing, no palette, no alpha. A file
 * that is anything else is rejected loudly rather than drawn wrongly.
 */
function decodeGreyscalePng(bytes) {
  if (!bytes.subarray(0, 8).equals(SIGNATURE)) throw new Error('not a PNG')

  let offset = 8
  let width = 0
  let height = 0
  const parts = []

  while (offset < bytes.length) {
    const length = bytes.readUInt32BE(offset)
    const type = bytes.toString('ascii', offset + 4, offset + 8)
    const body = bytes.subarray(offset + 8, offset + 8 + length)
    offset += 12 + length

    if (type === 'IHDR') {
      width = body.readUInt32BE(0)
      height = body.readUInt32BE(4)
      const depth = body[8]
      const colourType = body[9]
      const interlace = body[12]
      if (depth !== 8 || colourType !== 0 || interlace !== 0) {
        throw new Error(`mask must be 8-bit greyscale and not interlaced (got depth ${depth}, colour ${colourType}, interlace ${interlace})`)
      }
    } else if (type === 'IDAT') {
      parts.push(Buffer.from(body))
    } else if (type === 'IEND') {
      break
    }
  }

  return { width, height, pixels: unfilter(inflateSync(Buffer.concat(parts)), width, height) }
}

/**
 * Undoes the per-row filters PNG applies before compressing.
 *
 * Each row starts with a filter byte saying how it was encoded against the row above and
 * the pixel to the left; reversing that is what turns the stream back into pixels.
 */
function unfilter(raw, width, height) {
  const pixels = Buffer.alloc(width * height)
  let source = 0

  for (let row = 0; row < height; row += 1) {
    const filter = raw[source]
    source += 1
    const line = row * width
    const above = line - width

    for (let column = 0; column < width; column += 1) {
      const value = raw[source + column]
      const left = column > 0 ? pixels[line + column - 1] : 0
      const up = row > 0 ? pixels[above + column] : 0
      const upLeft = row > 0 && column > 0 ? pixels[above + column - 1] : 0

      let restored
      switch (filter) {
        case 0: restored = value; break
        case 1: restored = value + left; break
        case 2: restored = value + up; break
        case 3: restored = value + ((left + up) >> 1); break
        case 4: restored = value + paeth(left, up, upLeft); break
        default: throw new Error(`unknown PNG filter ${filter}`)
      }
      pixels[line + column] = restored & 0xff
    }
    source += width
  }
  return pixels
}

function paeth(left, up, upLeft) {
  const estimate = left + up - upLeft
  const toLeft = Math.abs(estimate - left)
  const toUp = Math.abs(estimate - up)
  const toUpLeft = Math.abs(estimate - upLeft)
  if (toLeft <= toUp && toLeft <= toUpLeft) return left
  return toUp <= toUpLeft ? up : upLeft
}

/** Paints the mask: background where it is black, figure where it is white. */
function encodePng(mask) {
  const { width, height, pixels } = mask
  const stride = width * 3
  const raw = Buffer.alloc((stride + 1) * height)

  for (let row = 0; row < height; row += 1) {
    const start = row * (stride + 1)
    raw[start] = 0
    for (let column = 0; column < width; column += 1) {
      // The mask is anti-aliased, so its greys are the edge of the silhouette. Mixing the
      // two colours by that grey is what keeps the outline smooth at every size Xcode
      // resamples this to.
      const weight = pixels[row * width + column] / 255
      const at = start + 1 + column * 3
      for (let channel = 0; channel < 3; channel += 1) {
        raw[at + channel] = Math.round(BACKGROUND[channel] * (1 - weight) + FIGURE[channel] * weight)
      }
    }
  }

  const header = Buffer.alloc(13)
  header.writeUInt32BE(width, 0)
  header.writeUInt32BE(height, 4)
  header[8] = 8
  header[9] = 2

  return Buffer.concat([
    SIGNATURE,
    chunk('IHDR', header),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ])
}

// Xcode wants one 1024 image per app icon and makes every other size from it.
const TARGETS = [
  ['../ios/VBTracker/Assets.xcassets/AppIcon.appiconset', 'ios'],
  ['../ios/VBTrackerWatch/Assets.xcassets/AppIcon.appiconset', 'watchos'],
]

const CONTENTS = (platform) => `${JSON.stringify({
  images: [{ filename: 'icon-1024.png', idiom: 'universal', platform, size: '1024x1024' }],
  info: { author: 'xcode', version: 1 },
}, null, 2)}\n`

const mask = decodeGreyscalePng(readFileSync(resolve(HERE, '../assets/app-icon-figure.png')))
if (mask.width !== 1024 || mask.height !== 1024) {
  throw new Error(`mask must be 1024x1024 (got ${mask.width}x${mask.height})`)
}

const png = encodePng(mask)

for (const [directory, platform] of TARGETS) {
  const target = resolve(HERE, directory)
  mkdirSync(target, { recursive: true })
  writeFileSync(resolve(target, 'icon-1024.png'), png)
  writeFileSync(resolve(target, 'Contents.json'), CONTENTS(platform))
  console.log(`wrote ${relative(resolve(HERE, '..'), target)}/icon-1024.png`)
}
