import { describe, expect, it } from 'vitest';
import { hasRole, officeEventSchema } from './index.js';

describe('hasRole', () => {
  it('respeita a hierarquia owner > admin > viewer', () => {
    expect(hasRole('owner', 'admin')).toBe(true);
    expect(hasRole('admin', 'admin')).toBe(true);
    expect(hasRole('viewer', 'admin')).toBe(false);
    expect(hasRole('admin', 'owner')).toBe(false);
  });
});

describe('officeEventSchema', () => {
  it('aceita um evento válido e rejeita tipo desconhecido', () => {
    const base = { ts: new Date().toISOString(), tenantId: 'demo', agentId: 'triage', payload: {} };
    expect(officeEventSchema.safeParse({ ...base, type: 'agent.working' }).success).toBe(true);
    expect(officeEventSchema.safeParse({ ...base, type: 'agent.dancing' }).success).toBe(false);
  });
});
