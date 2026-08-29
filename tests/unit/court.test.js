// The court arrangement IS the serving order, so what matters here is which player lands
// in which corner -- and that it re-lays itself around whoever is serving now.
import { describe, it, expect } from 'vitest'
import { courtView, positionAt } from '../../src/ui/components/court.js'

const ROSTER = Array.from({ length: 9 }, (each, index) => ({
  id: `p${index + 1}`,
  name: `Player ${index + 1}`,
  number: String(index + 1),
}))

const LINEUP = ['p1', 'p2', 'p3', 'p4', 'p5', 'p6']

/** The jersey numbers in the six court cells, in drawn order: front row, then back row. */
function cellNumbers(html) {
  return html.split('<div class="court-cell').slice(1)
    .map((cell) => cell.match(/chip-number">([^<]*)</)?.[1] ?? '')
}

describe('the six on court', () => {
  const html = courtView(ROSTER, LINEUP, { servingPosition: 0 })

  it('puts the server in the bottom-right corner', () => {
    expect(cellNumbers(html).at(-1)).toBe('1')
  })

  it('runs the serving order clockwise from there', () => {
    // Front row left to right is positions 4, 3, 2; back row is 5, 6, 1.
    expect(cellNumbers(html)).toEqual(['4', '3', '2', '5', '6', '1'])
  })

  it('marks the service corner and the player who takes it next', () => {
    expect(html).toContain('court-cell is-service')
    expect(html).toContain('court-cell is-next')
    expect(html).toContain('serving')
    expect(html).toContain('next')
  })

  it('shows which way the court faces', () => {
    expect(html).toContain('court-net')
  })

  it('labels each cell with its court position', () => {
    expect([...html.matchAll(/class="court-pos">(\d)</g)].map((each) => each[1]))
      .toEqual(['4', '3', '2', '5', '6', '1'])
  })
})

describe('the court re-lays itself as the rotation moves', () => {
  it('brings the next server into the corner when the rotation advances', () => {
    const html = courtView(ROSTER, LINEUP, { servingPosition: 1 })
    expect(cellNumbers(html).at(-1)).toBe('2')
    expect(cellNumbers(html)).toEqual(['5', '4', '3', '6', '1', '2'])
  })

  it('wraps round the order rather than running off the end', () => {
    const html = courtView(ROSTER, LINEUP, { servingPosition: 5 })
    expect(cellNumbers(html).at(-1)).toBe('6')
    expect(cellNumbers(html)).toContain('1')
  })

  it('returns to where it started after six rotations', () => {
    expect(positionAt(0, 6)).toBe(0)
    expect(positionAt(4, 3)).toBe(1)
  })
})

describe('the bench', () => {
  const html = courtView(ROSTER, LINEUP, { servingPosition: 0 })

  it('holds everyone not in the order', () => {
    expect(html).toContain('Bench')
    expect([...html.matchAll(/chip is-bench/g)]).toHaveLength(3)
  })

  it('marks them as off the court, so the six who are on stand out', () => {
    expect(html).toMatch(/class="chip is-bench"[\s\S]*?data-id="p7"/)
  })

  it('is left out entirely when everyone is on court', () => {
    const noBench = courtView(ROSTER.slice(0, 6), LINEUP, { servingPosition: 0 })
    expect(noBench).not.toContain('bench-label')
  })

  it('keeps a bench player armed for a substitution recognisable as armed', () => {
    const armed = courtView(ROSTER, LINEUP, {
      servingPosition: 0,
      stateFor: (player) => (player.id === 'p7' ? 'is-armed' : ''),
    })
    expect(armed).toMatch(/class="chip is-bench is-armed"/)
  })
})

describe('a position nobody is standing in', () => {
  it('is still drawn, because it is still a place in the order', () => {
    const short = courtView(ROSTER, ['p1', 'p2', undefined, 'p4', 'p5', 'p6'], { servingPosition: 0 })
    expect(short).toContain('court-empty')
    expect(cellNumbers(short)).toEqual(['4', '', '2', '5', '6', '1'])
  })
})

describe('the chips themselves', () => {
  it('carry the same marks they do anywhere else, so a tap means the same thing', () => {
    const html = courtView(ROSTER, LINEUP, {
      servingPosition: 0,
      stateFor: (player) => (player.id === 'p1' ? 'is-serving' : 'is-on-court'),
    })
    expect(html).toContain('class="chip is-serving"')
    expect(html).toContain('data-action="select-server"')
  })
})
