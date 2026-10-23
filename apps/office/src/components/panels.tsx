'use client';

import type { TicketStatus } from '@nexus/shared';
import { useOfficeStore } from '@/lib/office-store';
import type { TicketView } from '@/lib/office-state';

const PRIORITY: Record<TicketView['priority'], { label: string; cls: string }> = {
  critical: { label: 'Crítica', cls: 'bg-rose-500/20 text-rose-300' },
  high: { label: 'Alta', cls: 'bg-orange-500/20 text-orange-300' },
  medium: { label: 'Média', cls: 'bg-sky-500/20 text-sky-300' },
  low: { label: 'Baixa', cls: 'bg-slate-500/20 text-slate-300' },
};

const COLUMNS: Array<{ title: string; statuses: TicketStatus[] }> = [
  { title: 'Novos', statuses: ['new'] },
  { title: 'Em andamento', statuses: ['triaged', 'in_progress'] },
  { title: 'Aguardando', statuses: ['waiting_approval', 'waiting_user'] },
  { title: 'Resolvidos', statuses: ['resolved', 'closed'] },
];

function useNames(): Record<string, string> {
  const roster = useOfficeStore((s) => s.roster);
  return Object.fromEntries(roster.map((a) => [a.key, a.name]));
}

const time = (iso: string) =>
  new Date(iso).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });

export function ApprovalsPanel() {
  const approvals = useOfficeStore((s) => s.approvals);
  const names = useNames();
  if (approvals.length === 0)
    return <p className="text-sm text-slate-400">Nenhuma ação aguardando aprovação.</p>;
  return (
    <ul className="space-y-2">
      {approvals.map((a) => (
        <li
          key={a.id}
          className="rounded-xl border border-amber-400/30 bg-amber-400/10 px-3 py-2 text-sm"
        >
          <div className="flex items-baseline justify-between gap-2">
            <span className="font-medium text-amber-200">{names[a.agentId] ?? a.agentId}</span>
            <time className="text-[11px] text-amber-200/60">{time(a.requestedAt)}</time>
          </div>
          <p className="text-slate-200">{a.summary}</p>
          {a.ticketNumber !== null && (
            <p className="text-xs text-slate-400">Chamado #{a.ticketNumber}</p>
          )}
        </li>
      ))}
      <li className="px-1 text-[11px] text-slate-500">
        Aprovar e reprovar pelo painel chega na Fase 4.
      </li>
    </ul>
  );
}

export function TicketsBoard() {
  const tickets = useOfficeStore((s) => s.tickets);
  const list = Object.values(tickets).sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  return (
    <div className="-mx-1 flex snap-x snap-mandatory gap-3 overflow-x-auto px-1 pb-1">
      {COLUMNS.map((col) => {
        const items = list.filter((t) => col.statuses.includes(t.status));
        return (
          <section key={col.title} className="w-64 shrink-0 snap-start">
            <h3 className="mb-2 flex items-center justify-between text-xs font-semibold uppercase tracking-wider text-slate-400">
              {col.title}
              <span className="rounded-full bg-white/10 px-2 py-0.5 text-[11px] text-slate-300">
                {items.length}
              </span>
            </h3>
            <ul className="space-y-2">
              {items.slice(0, 30).map((t) => (
                <li key={t.number} className="rounded-xl bg-white/[0.04] px-3 py-2 text-sm">
                  <div className="flex items-center justify-between gap-2 text-[11px]">
                    <span className="text-slate-500">#{t.number}</span>
                    <span className={`rounded-full px-2 py-0.5 ${PRIORITY[t.priority].cls}`}>
                      {PRIORITY[t.priority].label}
                    </span>
                  </div>
                  <p className="mt-1 line-clamp-2 text-slate-200">{t.subject}</p>
                  <p className="mt-0.5 text-[11px] text-slate-500">{t.requester}</p>
                </li>
              ))}
            </ul>
          </section>
        );
      })}
    </div>
  );
}

export function MetricsPanel() {
  const tickets = useOfficeStore((s) => s.tickets);
  const stats = useOfficeStore((s) => s.stats);
  const approvals = useOfficeStore((s) => s.approvals.length);
  const all = Object.values(tickets);
  const open = all.filter((t) => t.status !== 'resolved' && t.status !== 'closed').length;
  const resolved = all.length - open;
  const cards = [
    { label: 'Chamados abertos', value: open },
    { label: 'Resolvidos', value: resolved },
    { label: 'Aguardando aprovação', value: approvals },
    { label: 'Novos nesta sessão', value: stats.created },
    { label: 'Resolvidos nesta sessão', value: stats.resolved },
    { label: 'Aprovações concedidas', value: stats.approvalsGranted },
  ];
  return (
    <div className="grid grid-cols-2 gap-2">
      {cards.map((c) => (
        <div key={c.label} className="rounded-xl bg-white/[0.04] px-3 py-3">
          <p className="text-2xl font-semibold tabular-nums">{c.value}</p>
          <p className="text-xs text-slate-400">{c.label}</p>
        </div>
      ))}
    </div>
  );
}
