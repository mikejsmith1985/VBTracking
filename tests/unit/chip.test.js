// The chip is the only thing a player is tapped through, in three different places, so it
// is checked directly: a large number, no truncated name, and safe with hostile input.
import { describe, it, expect } from 'vitest'
import { chip, chipGrid } from '../../src/ui/components/chip.js'

const rivera = { id: 'p1', name: 'Rivera', number: '7' }
const noNumber = { id: 'p2', name: 'Okafor', number: '' }

describe('chip', () => {
  it('shows the jersey number, not the name (FR-047)', () => {
    const html = chip(rivera)
    expect(html).toContain('>7<')
    expect(html).toContain('chip-number')
    expect(html).not.toMatch(/>Rivera</)
  })

  it('never truncates a name, because it never renders one (FR-048)', () => {
    expect(chip({ id: 'p3', name: 'Charlotte-Rivera', number: '13' })).not.toContain('…')
  })

  it('keeps a player with no number identifiable and tappable (FR-049)', () => {
    const html = chip(noNumber)
    expect(html).toContain('data-id="p2"')
    expect(html).toMatch(/chip-number">.<\/span>/)
  })

  it('carries the name in the accessible label, since the visible text is a number', () => {
    expect(chip(rivera)).toContain('aria-label="Rivera, number 7"')
  })

  it('omits the number from the label when there is none', () => {
    expect(chip(noNumber)).toContain('aria-label="Okafor"')
  })

  it('shows the serving-order slot when given one', () => {
    expect(chip(rivera, { position: 2 })).toContain('chip-slot">3<')
  })

  it('shows no slot when the player is not in an order', () => {
    expect(chip(rivera)).not.toContain('chip-slot')
  })

  it('applies the state it is given', () => {
    expect(chip(rivera, { state: 'is-armed' })).toContain('class="chip is-armed"')
  })

  it('uses the action it is given', () => {
    expect(chip(rivera, { action: 'choose-lineup' })).toContain('data-action="choose-lineup"')
  })

  it('escapes a hostile name and number rather than rendering them as markup', () => {
    const hostile = { id: 'p4', name: '"><img src=x>', number: '<b>9</b>' }
    const html = chip(hostile)
    expect(html).not.toContain('<img')
    expect(html).not.toContain('<b>9</b>')
    expect(html).toContain('&lt;b&gt;')
  })
})

describe('chipGrid', () => {
  const team = [rivera, noNumber]

  it('renders one chip per player', () => {
    expect(chipGrid(team).split('data-action=').length - 1).toBe(2)
  })

  it('asks the caller for each chip\'s state', () => {
    const html = chipGrid(team, { stateFor: (player) => (player.id === 'p1' ? 'is-serving' : '') })
    expect(html).toContain('class="chip is-serving"')
  })

  it('asks the caller for each chip\'s slot', () => {
    const html = chipGrid(team, { positionFor: (player) => (player.id === 'p1' ? 0 : null) })
    expect(html.split('chip-slot').length - 1).toBe(1)
  })

  it('renders an empty grid for an empty roster', () => {
    expect(chipGrid([])).toContain('chip-grid')
  })
})
