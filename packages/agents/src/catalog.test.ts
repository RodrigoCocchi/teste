import { describe, expect, it } from 'vitest';
import { agentDefinitionSchema, agentKeySchema } from '@nexus/shared';
import { AGENT_CATALOG } from './catalog.js';

describe('AGENT_CATALOG', () => {
  it('tem exatamente um agente válido para cada chave', () => {
    expect(AGENT_CATALOG.map((a) => a.key).sort()).toEqual([...agentKeySchema.options].sort());
    for (const agent of AGENT_CATALOG) agentDefinitionSchema.parse(agent);
  });
});
