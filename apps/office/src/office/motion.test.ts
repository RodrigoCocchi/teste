import { describe, expect, it } from 'vitest';
import { AGENT_CATALOG } from '@nexus/agents';
import { resolveGoal } from './goals';
import { OFFICE_LAYOUT } from './layout';
import { createMotion, stepMotion } from './motion';
import { NavGrid } from './navigation';

const grid = new NavGrid(OFFICE_LAYOUT);
const FPS = 30;

/** Simula até o agente parar no destino; retorna os segundos gastos e os pontos visitados. */
function simulate(agentKey: string, standup: boolean, visit?: string, maxSeconds = 60) {
  const desk = AGENT_CATALOG.find((a) => a.key === agentKey)!.desk;
  const m = createMotion(resolveGoal(OFFICE_LAYOUT, agentKey, desk, { kind: 'desk' }, false));
  const goal = resolveGoal(
    OFFICE_LAYOUT,
    agentKey,
    desk,
    visit ? { kind: 'visit', desk: visit } : { kind: 'desk' },
    standup,
  );
  const trail: Array<[number, number]> = [];
  for (let i = 0; i < maxSeconds * FPS; i++) {
    stepMotion(m, goal, 1 / FPS, grid);
    trail.push([m.x, m.z]);
    if (
      m.path.length === 0 &&
      Math.hypot(m.x - goal.point[0], m.z - goal.point[1]) < 1e-3 &&
      m.sit === (goal.posture === 'seated' ? 1 : 0)
    ) {
      for (let j = 0; j < 2 * FPS; j++) stepMotion(m, goal, 1 / FPS, grid); // tempo para virar
      return { seconds: i / FPS, trail, m, goal };
    }
  }
  return { seconds: Infinity, trail, m, goal };
}

describe('movimento dos agentes', () => {
  it('no standup todos chegam sentados à sala de reunião em menos de 15 s', () => {
    for (const { key } of AGENT_CATALOG) {
      const { seconds, m } = simulate(key, true);
      expect(seconds, key).toBeLessThan(15);
      expect(m.sit).toBe(1);
    }
  });

  it('a visita da Triagem ao Gestor passa só por áreas livres e termina em pé virada para ele', () => {
    const { seconds, trail, m, goal } = simulate('triage', false, 'manager-desk');
    expect(seconds).toBeLessThan(20);
    // Do meio do caminho em diante (fora da cadeira e antes da chegada) nunca entra em obstáculo.
    for (const p of trail.slice(FPS, -FPS)) expect(grid.isPointWalkable(p), String(p)).toBe(true);
    expect(m.sit).toBe(0);
    expect(
      Math.abs(Math.atan2(Math.sin(m.heading - goal.facing), Math.cos(m.heading - goal.facing))),
    ).toBeLessThan(0.05);
  });

  it('levanta antes de andar e só anda depois de levantar', () => {
    const desk = 'reception-desk';
    const m = createMotion(resolveGoal(OFFICE_LAYOUT, 'triage', desk, { kind: 'desk' }, false));
    const goal = resolveGoal(OFFICE_LAYOUT, 'triage', desk, { kind: 'desk' }, true);
    const start = [m.x, m.z];
    expect(stepMotion(m, goal, 1 / FPS, grid)).toBe(false);
    expect([m.x, m.z]).toEqual(start);
    expect(m.sit).toBeLessThan(1);
  });
});
