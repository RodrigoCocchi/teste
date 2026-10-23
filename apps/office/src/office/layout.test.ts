import { describe, expect, it } from 'vitest';
import { AGENT_CATALOG } from '@nexus/agents';
import { OFFICE_LAYOUT, findDesk, rotate, seatOf, visitorSpotOf, wallSegments } from './layout';
import { NavGrid } from './navigation';
import { resolveGoal } from './goals';

const grid = new NavGrid(OFFICE_LAYOUT);

describe('layout do escritório', () => {
  it('tem mesa para todos os agentes do catálogo', () => {
    for (const agent of AGENT_CATALOG)
      expect(() => findDesk(OFFICE_LAYOUT, agent.desk)).not.toThrow();
  });

  it('rotaciona como o three.js (rotation.y)', () => {
    const [x, z] = rotate([0, 1], 90);
    expect(x).toBeCloseTo(1);
    expect(z).toBeCloseTo(0);
  });

  it('desconta as portas das paredes', () => {
    const segments = wallSegments({
      from: [0, 0],
      to: [10, 0],
      kind: 'solid',
      doors: [{ at: 5, width: 2 }],
    });
    expect(segments).toEqual([
      [
        [0, 0],
        [4, 0],
      ],
      [
        [6, 0],
        [10, 0],
      ],
    ]);
  });
});

describe('navegação', () => {
  const agents = AGENT_CATALOG.map((a) => ({
    key: a.key,
    seat: seatOf(findDesk(OFFICE_LAYOUT, a.desk)).point,
  }));

  it('todo agente consegue ir da sua mesa até a mesa de qualquer outro e à reunião', () => {
    for (const from of agents) {
      for (const to of agents) {
        const spot = visitorSpotOf(
          findDesk(OFFICE_LAYOUT, AGENT_CATALOG.find((a) => a.key === to.key)!.desk),
        ).point;
        expect(grid.findPath(from.seat, spot), `${from.key} → ${to.key}`).not.toBeNull();
      }
      const meeting = resolveGoal(OFFICE_LAYOUT, from.key, 'x', { kind: 'desk' }, true).point;
      expect(grid.findPath(from.seat, meeting), `${from.key} → reunião`).not.toBeNull();
    }
  });

  it('pontos de visita e cadeiras da reunião ficam em área livre', () => {
    for (const desk of OFFICE_LAYOUT.desks)
      expect(grid.isPointWalkable(visitorSpotOf(desk).point), desk.id).toBe(true);
    for (const seat of OFFICE_LAYOUT.meetingSeats) expect(grid.isPointWalkable(seat)).toBe(true);
  });

  it('o caminho nunca atravessa parede: entra na sala do gestor pela porta', () => {
    const path = grid.findPath([3, 0.8 + 1.5], [4.3, -6.3])!;
    for (let i = 1; i < path.length - 1; i++) expect(grid.isPointWalkable(path[i]!)).toBe(true);
    const crossing = path.findIndex((p, i) => i > 0 && path[i - 1]![1] > -3.5 && p[1] <= -3.5);
    const [a, b] = [path[crossing - 1]!, path[crossing]!];
    const x = a[0] + ((b[0] - a[0]) * (-3.5 - a[1])) / (b[1] - a[1]);
    expect(Math.abs(x - 1.2)).toBeLessThan(0.65);
  });

  it('retorna null quando não há caminho', () => {
    const closed = new NavGrid({
      ...OFFICE_LAYOUT,
      walls: [...OFFICE_LAYOUT.walls, { from: [-14, -2], to: [14, -2], kind: 'solid', doors: [] }],
      desks: [],
      furniture: [],
    });
    expect(closed.findPath([0, 0], [0, -6])).toBeNull();
  });
});

describe('resolveGoal', () => {
  it('standup leva à reunião, visita leva ao lado da mesa visitada, senão volta à cadeira', () => {
    expect(resolveGoal(OFFICE_LAYOUT, 'triage', 'reception-desk', { kind: 'desk' }, true).key).toBe(
      'meeting:1',
    );
    const visit = resolveGoal(
      OFFICE_LAYOUT,
      'triage',
      'reception-desk',
      { kind: 'visit', desk: 'manager-desk' },
      false,
    );
    expect(visit).toMatchObject({ key: 'visit:manager-desk', posture: 'standing' });
    expect(
      resolveGoal(OFFICE_LAYOUT, 'triage', 'reception-desk', { kind: 'desk' }, false).key,
    ).toBe('desk:reception-desk');
  });
});
