import { describe, expect, it } from 'vitest';
import { agentKeySchema, officeEventSchema } from '../index.js';
import { demoEventStream } from './event-stream.js';

describe('demoEventStream', () => {
  it('gera eventos válidos pelo contrato, com agentes conhecidos', () => {
    const stream = demoEventStream('tenant-1');
    for (let i = 0; i < 200; i++) {
      const ev = stream.next().value;
      expect(officeEventSchema.parse(ev).tenantId).toBe('tenant-1');
      expect(agentKeySchema.safeParse(ev?.agentId).success).toBe(true);
    }
  });

  it('toda aprovação pedida é concedida no mesmo ciclo', () => {
    const stream = demoEventStream('t');
    const events = Array.from({ length: 100 }, () => stream.next().value);
    const requested = events
      .filter((e) => e?.type === 'approval.requested')
      .map((e) => e?.payload.approvalId);
    const granted = new Set(
      events.filter((e) => e?.type === 'approval.granted').map((e) => e?.payload.approvalId),
    );
    for (const id of requested.slice(0, -1)) expect(granted.has(id)).toBe(true);
  });
});
