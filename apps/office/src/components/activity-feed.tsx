import type { OfficeEvent } from '@nexus/shared';

const LABEL: Record<OfficeEvent['type'], string> = {
  'agent.idle': 'Disponível',
  'agent.thinking': 'Pensando',
  'agent.working': 'Trabalhando',
  'agent.walking': 'Caminhando',
  'agent.talking': 'Disse',
  'agent.waiting_approval': 'Aguardando aprovação',
  'agent.done': 'Concluiu',
  'agent.error': 'Erro',
  'ticket.created': 'Novo chamado',
  'ticket.updated': 'Chamado atualizado',
  'ticket.resolved': 'Chamado resolvido',
  'approval.requested': 'Pediu aprovação',
  'approval.granted': 'Aprovado',
  'approval.denied': 'Reprovado',
  'standup.started': 'Standup começou',
  'standup.ended': 'Standup terminou',
};

function detail(e: OfficeEvent): string | null {
  const p = e.payload;
  const text = [p.text, p.task, p.summary, p.subject].find((v) => typeof v === 'string');
  if (typeof text === 'string') return text;
  if (typeof p.ticketNumber === 'number') return `Chamado #${p.ticketNumber}`;
  return null;
}

export function ActivityFeed({
  events,
  names,
}: {
  events: OfficeEvent[];
  names: Record<string, string>;
}) {
  if (events.length === 0) return <p className="text-sm text-slate-400">Aguardando atividade…</p>;
  return (
    <ol className="space-y-2" aria-live="polite">
      {events.map((e, i) => (
        <li key={`${e.ts}-${i}`} className="rounded-xl bg-white/[0.03] px-3 py-2 text-sm">
          <div className="flex items-baseline justify-between gap-2">
            <span className="font-medium text-[--color-accent]">
              {names[e.agentId] ?? e.agentId}
            </span>
            <time className="shrink-0 text-[11px] text-slate-500">
              {new Date(e.ts).toLocaleTimeString('pt-BR', {
                hour: '2-digit',
                minute: '2-digit',
                second: '2-digit',
              })}
            </time>
          </div>
          <p className="text-slate-300">
            <span className="text-slate-400">{LABEL[e.type]}</span>
            {detail(e) && <span>: {detail(e)}</span>}
          </p>
        </li>
      ))}
    </ol>
  );
}
