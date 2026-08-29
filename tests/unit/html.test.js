// Proves operator-entered text cannot break out of the markup it is interpolated into,
// and that an undefined percentage renders as a dash rather than a number.
import { describe, it, expect } from 'vitest'
import { esc, playerLabel, percent, playerById } from '../../src/ui/html.js'

describe('esc', () => {
  it('neutralises every character that could open a tag or attribute', () => {
    expect(esc('<script>alert("x")</script>'))
      .toBe('&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;')
  })

  it('escapes ampersands first so an entity cannot be reconstructed', () => {
    expect(esc('&lt;')).toBe('&amp;lt;')
  })

  it('escapes single quotes, which close an attribute just as well as double ones', () => {
    expect(esc("' onerror='x")).toBe('&#39; onerror=&#39;x')
  })

  it('renders null and undefined as empty rather than as the words', () => {
    expect(esc(null)).toBe('')
    expect(esc(undefined)).toBe('')
  })

  it('leaves ordinary names untouched', () => {
    expect(esc("O'Brien-Nakamura")).toBe('O&#39;Brien-Nakamura')
    expect(esc('Rivera')).toBe('Rivera')
  })
})

describe('playerLabel', () => {
  it('escapes both the name and the jersey number', () => {
    const label = playerLabel({ id: 'p1', name: '<b>Rivera</b>', number: '<7>' })
    expect(label).not.toContain('<b>')
    expect(label).toContain('&lt;b&gt;Rivera&lt;/b&gt;')
    expect(label).toContain('&lt;7&gt;')
  })

  it('shows a dash when a player has no jersey number', () => {
    expect(playerLabel({ id: 'p1', name: 'Rivera', number: '' })).toContain('—')
  })

  it('degrades to a placeholder for a player who has since been removed', () => {
    expect(playerLabel(null)).toContain('Removed player')
  })
})

describe('percent', () => {
  it('renders a ratio as a rounded percentage', () => {
    expect(percent(0.75)).toBe('75%')
    expect(percent(2 / 3)).toBe('67%')
    expect(percent(1)).toBe('100%')
    expect(percent(0)).toBe('0%')
  })

  it('renders a dash when the figure is undefined, never 0% or NaN', () => {
    expect(percent(null)).toBe('—')
    expect(percent(undefined)).toBe('—')
  })
})

describe('playerById', () => {
  const team = [{ id: 'p1', name: 'Rivera', number: '7' }]

  it('finds a player on the roster', () => {
    expect(playerById(team, 'p1').name).toBe('Rivera')
  })

  it('returns null rather than undefined for one who is gone', () => {
    expect(playerById(team, 'gone')).toBeNull()
  })
})
