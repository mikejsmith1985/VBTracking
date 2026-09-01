// Drawing the app's mark as a neon sign, at whatever size is asked for.
//
// One renderer, used by every icon this project ships: the two native app icons and the
// three the web app installs with. They were drawn by two different scripts once and drifted
// into two different pictures, which is exactly the thing a shared module stops.
//
// The shape is the artwork the stakeholder chose, not a redrawing of it. It lives in
// `assets/app-icon-figure.png` -- a traced silhouette, white on black, at icon size -- and
// this lights it: a bright tube along the edge of the shape, a coloured halo bleeding off
// it, a dim fill inside, and a frame around the tile. All of it on black, because that is
// what makes a neon sign read as one.
//
// The frame follows the shape the icon will be cropped to. A rounded rectangle is right for
// a home screen; a circle is right for a watch face, and for anything declared `maskable`,
// where a browser may crop to a circle of 80% of the width and a rounded rectangle would
// lose its corners.
//
// Every size is rendered at 1024 and then averaged down. Rendering a glow directly at 192
// gives a blur radius of five pixels and a halo that looks like a smudge; averaging a large
// one down keeps it smooth.
//
// No image library: the mask is a plain 8-bit greyscale PNG, which is a zlib stream of
// filtered rows, and Node can inflate that on its own. The blur underneath the glow is three
// box passes, which is a Gaussian to within a percent and needs no library either.
import { deflateSync, inflateSync } from 'node:zlib'
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const SIZE = 1024

// Cyan, because it is the colour the app itself is tinted with -- the icon and the first
// screen agree with each other. The core of a neon tube reads as white however it is
// filtered, so the tube is lifted most of the way there and the colour lives in the halo.
const NEON = [0x22, 0xd3, 0xee]
const TUBE = [0xd6, 0xfb, 0xff]
const BACKGROUND = [0x00, 0x00, 0x00]

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

/**
 * Blurs a field in place-ish, separably, three box passes to a Gaussian.
 *
 * Three passes is the standard approximation and is indistinguishable from a real Gaussian
 * at these radii, which matters because a halo with visible banding stops looking like
 * light and starts looking like a mistake.
 */
function blur(field, radius) {
  if (radius < 1) return Float32Array.from(field)
  let current = Float32Array.from(field)
  for (let pass = 0; pass < 3; pass += 1) {
    current = boxPass(current, radius, true)
    current = boxPass(current, radius, false)
  }
  return current
}

/** One box pass, along rows or down columns. */
function boxPass(field, radius, isHorizontal) {
  const out = new Float32Array(field.length)
  const span = radius * 2 + 1

  for (let line = 0; line < SIZE; line += 1) {
    const at = (step) =>
      isHorizontal ? line * SIZE + clampIndex(step) : clampIndex(step) * SIZE + line

    let running = 0
    for (let step = -radius; step <= radius; step += 1) running += field[at(step)]

    for (let step = 0; step < SIZE; step += 1) {
      out[isHorizontal ? line * SIZE + step : step * SIZE + line] = running / span
      running += field[at(step + radius + 1)] - field[at(step - radius)]
    }
  }
  return out
}

/** Reading past the edge repeats the edge, so a glow does not darken against the border. */
function clampIndex(index) {
  return index < 0 ? 0 : index >= SIZE ? SIZE - 1 : index
}

/**
 * The bright tube that runs along the edge of a shape.
 *
 * A blurred shape passes through a half at exactly its boundary, so `4b(1 - b)` peaks
 * there and falls away on both sides -- a tube of light centred on the outline, as wide as
 * the blur, with no edge detection and nothing to alias.
 */
function tubeAlong(shape, radius) {
  const soft = blur(shape, radius)
  const tube = new Float32Array(soft.length)
  for (let at = 0; at < soft.length; at += 1) {
    const band = 4 * soft[at] * (1 - soft[at])
    tube[at] = Math.min(1, band * band * 1.6)
  }
  return tube
}

/** How far a point is outside a rounded rectangle centred on the tile; negative inside. */
function roundedRectDistance(x, y, halfExtent, cornerRadius) {
  const middle = SIZE / 2 - 0.5
  const dx = Math.abs(x - middle) - (halfExtent - cornerRadius)
  const dy = Math.abs(y - middle) - (halfExtent - cornerRadius)
  const outside = Math.hypot(Math.max(dx, 0), Math.max(dy, 0))
  return outside + Math.min(Math.max(dx, dy), 0) - cornerRadius
}

/** The same, for the circle a watch face crops to. */
function circleDistance(x, y, radius) {
  const middle = SIZE / 2 - 0.5
  return Math.hypot(x - middle, y - middle) - radius
}

/**
 * The frame: a stroked outline of whatever shape the platform will crop this icon to.
 *
 * Inset far enough that the crop cannot touch it. A frame that the corner of a squircle
 * bites into reads as a printing error, not as a sign.
 */
function frameFor(frameShape) {
  const stroke = 5
  const field = new Float32Array(SIZE * SIZE)

  for (let row = 0; row < SIZE; row += 1) {
    for (let column = 0; column < SIZE; column += 1) {
      const distance =
        frameShape === 'circle'
          ? circleDistance(column, row, 392)
          : roundedRectDistance(column, row, 416, 150)
      // One pixel of softness either side of the line, so the frame is smooth at every
      // size Xcode resamples it to.
      field[row * SIZE + column] = clamp01((stroke - Math.abs(distance)) / 2 + 0.5)
    }
  }
  return field
}

function clamp01(value) {
  return value < 0 ? 0 : value > 1 ? 1 : value
}

/**
 * The traced shape, shrunk to sit inside the frame.
 *
 * The trace fills its canvas edge to edge, so drawn at full size the legs cross the frame
 * and the ball sits on top of it. A sign's frame goes round the sign.
 */
function scaled(mask, factor) {
  const field = new Float32Array(SIZE * SIZE)
  const middle = (SIZE - 1) / 2

  for (let row = 0; row < SIZE; row += 1) {
    const sourceY = (row - middle) / factor + middle
    if (sourceY < 0 || sourceY > SIZE - 1) continue

    for (let column = 0; column < SIZE; column += 1) {
      const sourceX = (column - middle) / factor + middle
      if (sourceX < 0 || sourceX > SIZE - 1) continue
      field[row * SIZE + column] = sample(mask, sourceX, sourceY) / 255
    }
  }
  return field
}

/** One pixel of the mask, read between its neighbours so the shrink does not stair-step. */
function sample(mask, x, y) {
  const left = Math.floor(x)
  const top = Math.floor(y)
  const right = Math.min(left + 1, SIZE - 1)
  const bottom = Math.min(top + 1, SIZE - 1)
  const acrossWeight = x - left
  const downWeight = y - top

  const above =
    mask.pixels[top * SIZE + left] * (1 - acrossWeight) + mask.pixels[top * SIZE + right] * acrossWeight
  const below =
    mask.pixels[bottom * SIZE + left] * (1 - acrossWeight) + mask.pixels[bottom * SIZE + right] * acrossWeight
  return above * (1 - downWeight) + below * downWeight
}

/**
 * Lights the shapes and returns raw RGB rows.
 *
 * Light adds, so every layer is added rather than laid over: a halo crossing another halo
 * gets brighter, which is what happens in front of a real sign and what stops the overlaps
 * looking like cut-out shapes.
 */
function paint(frameShape) {
  // A circle leaves less room in the corners than a rounded rectangle does, so the figure
  // is drawn a little smaller inside one.
  const figure = scaled(MASK, frameShape === 'circle' ? 0.74 : 0.8)
  const frame = frameFor(frameShape)

  // Two haloes, near and far: the near one gives the tube its body, the far one is the
  // wash a sign throws onto the wall behind it.
  const lit = new Float32Array(figure.length)
  for (let at = 0; at < lit.length; at += 1) lit[at] = Math.max(figure[at], frame[at])

  const tube = tubeAlong(figure, 7)
  for (let at = 0; at < tube.length; at += 1) tube[at] = Math.max(tube[at], frame[at])

  // The near halo comes off the tube, not off the filled shape. Blurring the fill lit the
  // whole figure evenly and it stopped reading as a tube of light and started reading as a
  // cyan cut-out. The far wash still comes off everything, because that is the light
  // landing on the wall and the wall does not care what shape threw it.
  const near = blur(tube, 24)
  const far = blur(lit, 92)

  const rgb = Buffer.alloc(SIZE * SIZE * 3)
  for (let at = 0; at < figure.length; at += 1) {
    // The glass of an unlit tube is still visible against black, which is what keeps the
    // figure readable at 40 points where the halo has blurred into nothing.
    const inside = figure[at] * 0.3
    const halo = Math.min(1, near[at] * 2.1 + far[at] * 1.15)
    const core = tube[at]

    for (let channel = 0; channel < 3; channel += 1) {
      const value =
        BACKGROUND[channel] +
        NEON[channel] * (halo + inside) +
        (TUBE[channel] - NEON[channel] * 0.35) * core
      rgb[at * 3 + channel] = Math.round(Math.min(255, Math.max(0, value)))
    }
  }
  return rgb
}

/** The traced artwork, read once and shared by every icon rendered from it. */
const MASK = (() => {
  const mask = decodeGreyscalePng(readFileSync(resolve(HERE, '../assets/app-icon-figure.png')))
  if (mask.width !== SIZE || mask.height !== SIZE) {
    throw new Error(`mask must be ${SIZE}x${SIZE} (got ${mask.width}x${mask.height})`)
  }
  return mask
})()

/**
 * The icon, as the bytes of a PNG.
 *
 * `frame` is the shape drawn around the tile: `rounded` for a home screen, `circle` for a
 * watch face or a maskable icon. `size` is the edge of the square written out.
 */
export function neonIcon({ frame, size = SIZE }) {
  const full = paint(frame)
  return encodePng(size === SIZE ? full : averageDown(full, size), size)
}

/**
 * Averages a rendered icon down to a smaller square.
 *
 * A plain box average over whole source pixels, which is what "average down" means when the
 * scale divides evenly and is close enough when it does not. Point sampling would put stairs
 * on the frame and speckle in the halo.
 */
function averageDown(source, size) {
  const out = Buffer.alloc(size * size * 3)
  const scale = SIZE / size

  for (let row = 0; row < size; row += 1) {
    const top = Math.floor(row * scale)
    const bottom = Math.min(SIZE, Math.ceil((row + 1) * scale))
    for (let column = 0; column < size; column += 1) {
      const left = Math.floor(column * scale)
      const right = Math.min(SIZE, Math.ceil((column + 1) * scale))

      for (let channel = 0; channel < 3; channel += 1) {
        let total = 0
        let count = 0
        for (let y = top; y < bottom; y += 1) {
          for (let x = left; x < right; x += 1) {
            total += source[(y * SIZE + x) * 3 + channel]
            count += 1
          }
        }
        out[(row * size + column) * 3 + channel] = Math.round(total / count)
      }
    }
  }
  return out
}

/** Wraps raw RGB rows as a PNG, no alpha -- an App Store icon may not carry any. */
function encodePng(rgb, size) {
  const stride = size * 3
  const raw = Buffer.alloc((stride + 1) * size)
  for (let row = 0; row < size; row += 1) {
    raw[row * (stride + 1)] = 0
    rgb.copy(raw, row * (stride + 1) + 1, row * stride, (row + 1) * stride)
  }

  const header = Buffer.alloc(13)
  header.writeUInt32BE(size, 0)
  header.writeUInt32BE(size, 4)
  header[8] = 8
  header[9] = 2

  return Buffer.concat([
    SIGNATURE,
    chunk('IHDR', header),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ])
}
