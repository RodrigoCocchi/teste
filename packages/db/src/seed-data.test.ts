import { describe, expect, it } from 'vitest';
import { DEMO_TICKETS } from './seed-data.js';

describe('DEMO_TICKETS', () => {
  it('tem 30 chamados variados', () => {
    expect(DEMO_TICKETS).toHaveLength(30);
    expect(new Set(DEMO_TICKETS.map((t) => t.category)).size).toBeGreaterThanOrEqual(6);
    expect(new Set(DEMO_TICKETS.map((t) => t.status)).size).toBeGreaterThanOrEqual(6);
    expect(new Set(DEMO_TICKETS.map((t) => t.priority)).size).toBe(4);
  });

  it('chamados novos não têm agente atribuído', () => {
    for (const t of DEMO_TICKETS.filter((d) => d.status === 'new')) expect(t.agent).toBeNull();
  });
});
