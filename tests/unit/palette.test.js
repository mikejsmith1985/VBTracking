// Proves consecutive serve turns can never share a colour, which is what makes a
// player's separate serving sessions readable at a glance.
import { describe, it, expect } from 'vitest'
import { PALETTE, colorForTurn } from '../../src/domain/palette.js'

describe('turn colour palette', () => {
  it('offers more than one colour', () => {
    expect(PALETTE.length).toBeGreaterThan(1)
  })

  it('never gives two consecutive turns the same colour, including at wrap-around (FR-033)', () => {
    for (let ordinal = 0; ordinal < PALETTE.length * 4; ordinal += 1) {
      expect(colorForTurn(ordinal)).not.toBe(colorForTurn(ordinal + 1))
    }
  })

  it('depends only on the ordinal, so a turn\'s colour never changes retroactively', () => {
    expect(colorForTurn(7)).toBe(colorForTurn(7))
    expect(colorForTurn(0)).toBe(colorForTurn(PALETTE.length))
  })

  it('returns a colour for every ordinal, however large', () => {
    expect(colorForTurn(999)).toEqual(expect.stringMatching(/^#[0-9a-fA-F]{6}$/))
  })
})
