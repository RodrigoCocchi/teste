import { describe, expect, it } from 'vitest';
import type { OfficeEvent } from '@nexus/shared';
import {
  FEED_LIMIT,
  initialOfficeState,
  reduceOfficeEvent,
  type OfficeState,
} from './office-state';

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

const run = (...events: OfficeEvent[]): OfficeState =>
  events.reduce(reduceOfficeEvent, initialOfficeState);

describe('reduceOfficeEvent', () => {
  it('atualiza a atividade do agente com o detalhe do payload', () => {
    const s = run(ev('agent.working', { task: 'Classificando #31' }));
    expect(s.agents.triage).toMatchObject({ activity: 'working', detail: 'Classificando #31' });
  });

  it('caminhar até uma mesa vira visita; conversar mantém o lugar; trabalhar volta à mesa', () => {
    let s = run(ev('agent.walking', { to: 'manager-desk' }));
    expect(s.agents.triage?.location).toEqual({ kind: 'visit', desk: 'manager-desk' });
    s = reduceOfficeEvent(s, ev('agent.talking', { text: 'oi' }));
    expect(s.agents.triage?.location).toEqual({ kind: 'visit', desk: 'manager-desk' });
    s = reduceOfficeEvent(s, ev('agent.idle'));
    expect(s.agents.triage?.location).toEqual({ kind: 'desk' });
  });

  it('controla a fila de aprovações e o standup', () => {
    let s = run(
      ev('ticket.created', { ticketNumber: 40, subject: 'VPN' }),
      ev('approval.requested', { approvalId: 'a1', ticketNumber: 40, summary: 'Responder' }),
      ev('standup.started'),
      ev('agent.talking', { text: 'Bom dia' }, 'manager'),
    );
    expect(s.approvals).toEqual([
      expect.objectContaining({ id: 'a1', summary: 'Responder', ticketNumber: 40 }),
    ]);
    expect(s.tickets[40]?.status).toBe('waiting_approval');
    expect(s.standup).toBe(true);
    s = reduceOfficeEvent(s, ev('approval.granted', { approvalId: 'a1' }));
    s = reduceOfficeEvent(s, ev('standup.ended'));
    expect(s).toMatchObject({ approvals: [], standup: false, stats: { approvalsGranted: 1 } });
    expect(s.agents.manager).toMatchObject({ activity: 'idle', location: { kind: 'desk' } });
  });

  it('acompanha o ciclo de vida do chamado', () => {
    const s = run(
      ev('ticket.created', { ticketNumber: 7, subject: 'Impressora' }),
      ev('ticket.updated', { ticketNumber: 7, status: 'triaged', priority: 'high' }),
      ev('ticket.resolved', { ticketNumber: 7 }),
    );
    expect(s.tickets[7]).toMatchObject({
      subject: 'Impressora',
      status: 'resolved',
      priority: 'high',
    });
    expect(s.stats).toMatchObject({ created: 1, resolved: 1 });
  });

  it('não polui o feed com idle e limita o tamanho', () => {
    let s = run(ev('agent.idle'));
    expect(s.feed).toHaveLength(0);
    for (let i = 0; i < FEED_LIMIT + 10; i++) s = reduceOfficeEvent(s, ev('agent.thinking'));
    expect(s.feed).toHaveLength(FEED_LIMIT);
  });
});
