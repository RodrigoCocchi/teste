import { describe, expect, it } from 'vitest';
import type { OfficeEvent } from '@nexus/shared';
import { FEED_LIMIT, initialOfficeState, reduceOfficeEvent } from './office-state';

const ev = (
  type: OfficeEvent['type'],
  payload: Record<string, unknown> = {},
  agentId = 'triage',
): OfficeEvent => ({
  ts: '2026-01-01T00:00:00.000Z',
  tenantId: 'demo',
  agentId,
  type,
  payload,
});

describe('reduceOfficeEvent', () => {
  it('atualiza a atividade do agente com o detalhe do payload', () => {
    const s = reduceOfficeEvent(
      initialOfficeState,
      ev('agent.working', { task: 'Classificando #31' }),
    );
    expect(s.agents.triage).toMatchObject({ activity: 'working', detail: 'Classificando #31' });
  });

  it('conta aprovações pendentes e controla o standup', () => {
    let s = reduceOfficeEvent(initialOfficeState, ev('approval.requested'));
    s = reduceOfficeEvent(s, ev('standup.started'));
    expect(s).toMatchObject({ pendingApprovals: 1, standup: true });
    s = reduceOfficeEvent(s, ev('approval.granted'));
    s = reduceOfficeEvent(s, ev('approval.denied'));
    s = reduceOfficeEvent(s, ev('standup.ended'));
    expect(s).toMatchObject({ pendingApprovals: 0, standup: false });
  });

  it('não polui o feed com idle e limita o tamanho', () => {
    let s = reduceOfficeEvent(initialOfficeState, ev('agent.idle'));
    expect(s.feed).toHaveLength(0);
    for (let i = 0; i < FEED_LIMIT + 10; i++) s = reduceOfficeEvent(s, ev('agent.thinking'));
    expect(s.feed).toHaveLength(FEED_LIMIT);
  });
});
