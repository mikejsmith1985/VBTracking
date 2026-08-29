// The five-serve alert. It interrupts, so what it says has to be right: who has finished,
// and who -- if anyone -- the app can honestly say has the ball next.
import { describe, it, expect } from 'vitest'
import { rotateOverlay } from '../../src/ui/components/rotate.js'

const ROSTER = [
  { id: 'p1', name: 'Ana Reyes', number: '7' },
  { id: 'p2', name: 'Bea Cole', number: '12' },
  { id: 'p3', name: 'Cass Ng', number: '' },
]

describe('the five-serve alert', () => {
  const html = rotateOverlay({ fromId: 'p1', toId: 'p2' }, ROSTER)

  it('names who has just taken their five', () => {
    expect(html).toContain('Ana Reyes')
    expect(html).toContain('has served 5')
  })

  it('names who has the ball now', () => {
    expect(html).toContain('Next up')
    expect(html).toContain('Bea Cole')
    expect(html).toContain('12')
  })

  it('asks for a server instead when the app cannot know who is next', () => {
    const noOrder = rotateOverlay({ fromId: 'p1', toId: null }, ROSTER)
    expect(noOrder).toContain('Pick the next server')
    expect(noOrder).not.toContain('Next up')
  })

  it('clears on a tap anywhere on it, not only on the button', () => {
    expect(html).toMatch(/class="rotate-overlay" data-action="dismiss-rotate"/)
    expect([...html.matchAll(/data-action="dismiss-rotate"/g)].length).toBeGreaterThan(1)
  })

  it('announces itself, for a screen reader as well as an eye', () => {
    expect(html).toContain('role="alert"')
  })

  it('still identifies a player who has no number', () => {
    const html = rotateOverlay({ fromId: 'p3', toId: null }, ROSTER)
    expect(html).toContain('Cass Ng')
    expect(html).toContain('–')
  })

  it('escapes a name rather than letting it become markup', () => {
    const html = rotateOverlay({ fromId: 'x', toId: null }, [{ id: 'x', name: '<b>Ana</b>', number: '1' }])
    expect(html).not.toContain('<b>Ana</b>')
    expect(html).toContain('&lt;b&gt;Ana&lt;/b&gt;')
  })

  it('does not break on a player who has left the roster', () => {
    const html = rotateOverlay({ fromId: 'gone', toId: null }, ROSTER)
    expect(html).toContain('That player')
  })
})
