import { DEMO_TICKETS } from '@nexus/db';
import type { AgentKey, OfficeEvent, OfficeEventType } from '@nexus/shared';

type Step = [agent: AgentKey, type: OfficeEventType, payload: Record<string, unknown>];

/** Roteiro de um chamado percorrendo o time (Triagem → Gestor → Suporte N1 → Documentação). */
function ticketScript(ticketNumber: number, subject: string, cycle: number): Step[] {
  const approvalId = `demo-approval-${cycle}`;
  const ref = `#${ticketNumber}`;
  return [
    ['triage', 'ticket.created', { ticketNumber, subject }],
    ['triage', 'agent.thinking', { ticketNumber }],
    ['triage', 'agent.working', { ticketNumber, task: `Classificando o chamado ${ref}` }],
    ['triage', 'ticket.updated', { ticketNumber, status: 'triaged', priority: 'high' }],
    ['dev', 'agent.working', { task: 'Corrigindo o relatório de fretes' }],
    ['triage', 'agent.walking', { to: 'manager-desk' }],
    ['triage', 'agent.talking', { to: 'manager', text: `Chamado ${ref} classificado: ${subject}` }],
    ['triage', 'agent.idle', {}],
    ['manager', 'agent.talking', { to: 'support_n1', text: `Pode assumir o ${ref}?` }],
    ['qa', 'agent.thinking', { task: 'Revisando PR do relatório de fretes' }],
    ['support_n1', 'agent.working', { ticketNumber, task: `Preparando resposta do ${ref}` }],
    [
      'support_n1',
      'approval.requested',
      {
        approvalId,
        ticketNumber,
        action: 'ticket.reply',
        summary: `Responder ${ref} com o passo a passo`,
      },
    ],
    ['support_n1', 'agent.waiting_approval', { approvalId }],
    ['support_n1', 'approval.granted', { approvalId }],
    ['support_n1', 'agent.working', { ticketNumber, task: 'Enviando resposta ao usuário' }],
    ['support_n1', 'ticket.resolved', { ticketNumber }],
    ['support_n1', 'agent.done', { ticketNumber }],
    ['docs', 'agent.working', { ticketNumber, task: `Gerando artigo a partir do ${ref}` }],
    ['qa', 'agent.done', { task: 'PR aprovado' }],
    ['docs', 'agent.done', { ticketNumber }],
    ['support_n1', 'agent.idle', {}],
    ['dev', 'agent.idle', {}],
    ['docs', 'agent.idle', {}],
  ];
}

function standupScript(): Step[] {
  return [
    ['manager', 'standup.started', { room: 'meeting_room' }],
    ['manager', 'agent.talking', { text: 'Bom dia, time! Como estão os chamados de hoje?' }],
    ['infra', 'agent.talking', { text: 'Disco do FS01 liberado, monitorando.' }],
    ['manager', 'standup.ended', {}],
  ];
}

/** Gera infinitamente eventos fictícios coerentes para o tenant demo. */
export function* demoEventStream(
  tenantId: string,
  now: () => Date = () => new Date(),
): Generator<OfficeEvent> {
  for (let cycle = 0; ; cycle++) {
    const ticket = DEMO_TICKETS[cycle % DEMO_TICKETS.length];
    const steps = [
      ...(cycle % 5 === 0 ? standupScript() : []),
      ...ticketScript(31 + cycle, ticket?.subject ?? 'Chamado de demonstração', cycle),
    ];
    for (const [agentId, type, payload] of steps) {
      yield { ts: now().toISOString(), tenantId, agentId, type, payload };
    }
  }
}
