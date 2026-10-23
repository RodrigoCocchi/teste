import type { Goal } from './goals';
import type { Point } from './layout';
import type { NavGrid } from './navigation';

export const WALK_SPEED = 1.7;

export interface Motion {
  x: number;
  z: number;
  heading: number;
  goal: Goal;
  path: Point[];
  /** 0 = em pé, 1 = sentado (transição suave). */
  sit: number;
  walkPhase: number;
}

export function createMotion(goal: Goal): Motion {
  return {
    x: goal.point[0],
    z: goal.point[1],
    heading: goal.facing,
    goal,
    path: [],
    sit: 1,
    walkPhase: 0,
  };
}

function angleLerp(a: number, b: number, k: number): number {
  return a + Math.atan2(Math.sin(b - a), Math.cos(b - a)) * k;
}

/**
 * Avança o movimento do agente em `dt` segundos: recalcula o caminho quando o destino muda,
 * levanta antes de andar, segue o caminho e senta ao chegar. Puro (só muta `m`), testável sem WebGL.
 * Retorna se o agente está caminhando neste passo.
 */
export function stepMotion(m: Motion, goal: Goal, dt: number, grid: NavGrid): boolean {
  if (goal.key !== m.goal.key) {
    m.goal = goal;
    m.path = grid.findPath([m.x, m.z], goal.point)?.slice(1) ?? [goal.point];
  }

  const moving = m.path.length > 0;
  const wantSit = !moving && goal.posture === 'seated' ? 1 : 0;
  m.sit += (wantSit - m.sit) * (1 - Math.exp(-dt * 6));
  if (Math.abs(wantSit - m.sit) < 0.01) m.sit = wantSit;
  const canWalk = m.sit < 0.15;

  if (moving && canWalk) {
    let budget = WALK_SPEED * dt;
    while (budget > 0 && m.path.length > 0) {
      const [tx, tz] = m.path[0]!;
      const dx = tx - m.x;
      const dz = tz - m.z;
      const dist = Math.hypot(dx, dz);
      if (dist > 1e-6) m.heading = angleLerp(m.heading, Math.atan2(dx, dz), 1 - Math.exp(-dt * 10));
      if (dist <= budget) {
        m.x = tx;
        m.z = tz;
        m.path.shift();
        budget -= dist;
      } else {
        m.x += (dx / dist) * budget;
        m.z += (dz / dist) * budget;
        budget = 0;
      }
    }
    m.walkPhase += dt * 9;
    return true;
  }
  if (!moving) m.heading = angleLerp(m.heading, goal.facing, 1 - Math.exp(-dt * 6));
  return false;
}
