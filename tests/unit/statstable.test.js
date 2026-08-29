// Proves the statistics table orders by contribution, never shows a misleading zero for an
// undefined percentage, and escapes operator-entered names.
import { describe, it, expect } from 'vitest'
import { statsTable } from '../../src/ui/components/statstable.js'

const team = [
  { id: 'p1', name: 'Rivera', number: '7' },
  { id: 'p2', name: 'Okafor', number: '3' },
]

function stats(serves, servesIn, points, turnsTaken) {
  return { serves, servesIn, points, turnsTaken, inPercentage: serves === 0 ? null : servesIn / serves }
}

describe('statsTable', () => {
  it('says so plainly when nothing has been recorded', () => {
    expect(statsTable(new Map(), team)).toContain('No serves recorded yet')
    expect(statsTable(null, team)).toContain('No serves recorded yet')
  })

  it('renders one row per player who served', () => {
    const html = statsTable(new Map([['p1', stats(4, 3, 2, 1)], ['p2', stats(2, 2, 1, 1)]]), team)
    expect(html.split('<tr>').length - 1).toBe(3) // header row plus two players
  })

  it('orders by points, then by serves', () => {
    const html = statsTable(new Map([['p1', stats(9, 4, 1, 2)], ['p2', stats(3, 3, 5, 1)]]), team)
    expect(html.indexOf('Okafor')).toBeLessThan(html.indexOf('Rivera'))
  })

  it('shows every figure the spec asks for', () => {
    const html = statsTable(new Map([['p1', stats(4, 3, 2, 1)]]), team)
    for (const heading of ['Srv', 'In', 'In %', 'Pts', 'Turns']) expect(html).toContain(heading)
    expect(html).toContain('<td>75%</td>')
  })

  it('shows a dash for an undefined percentage, not 0% (FR-039)', () => {
    const html = statsTable(new Map([['p1', stats(0, 0, 0, 0)]]), team)
    expect(html).toContain('class="none"')
    expect(html).not.toContain('0%')
    expect(html).not.toContain('NaN')
  })

  it('does not cap a large serve count', () => {
    expect(statsTable(new Map([['p1', stats(9, 9, 8, 1)]]), team)).toContain('<td>9</td>')
  })

  it('still renders a row for a player who has since been removed', () => {
    const html = statsTable(new Map([['gone', stats(2, 1, 1, 1)]]), team)
    expect(html).toContain('Removed player')
  })

  it('escapes a player name rather than rendering it as markup', () => {
    const hostile = [{ id: 'p1', name: '<b>x</b>', number: '7' }]
    const html = statsTable(new Map([['p1', stats(1, 1, 1, 1)]]), hostile)
    expect(html).not.toContain('<b>x</b>')
    expect(html).toContain('&lt;b&gt;')
  })
})
