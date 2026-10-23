import type { AgentInfo } from '@/lib/use-agents';
import type { AgentActivity, AgentState } from '@/lib/office-state';

const ACTIVITY: Record<AgentActivity, { label: string; dot: string }> = {
  idle: { label: 'Disponível', dot: 'bg-slate-400' },
  thinking: { label: 'Pensando', dot: 'bg-violet-400 animate-pulse' },
  working: { label: 'Trabalhando', dot: 'bg-sky-400 animate-pulse' },
  walking: { label: 'Caminhando', dot: 'bg-teal-400' },
  talking: { label: 'Conversando', dot: 'bg-indigo-300' },
  waiting_approval: { label: 'Aguardando aprovação', dot: 'bg-amber-400 animate-ping' },
  done: { label: 'Concluiu', dot: 'bg-emerald-400' },
  error: { label: 'Erro', dot: 'bg-rose-500' },
};

export function AgentCard({ agent, state }: { agent: AgentInfo; state: AgentState | undefined }) {
  const activity = ACTIVITY[state?.activity ?? 'idle'];
  return (
    <article className="glass rounded-2xl p-4 transition-colors duration-300">
      <header className="flex items-center justify-between gap-3">
        <h3 className="truncate text-base font-semibold">{agent.name}</h3>
        <span className="flex shrink-0 items-center gap-2 text-xs text-slate-300">
          <span className="relative flex size-2.5">
            <span className={`absolute inline-flex size-full rounded-full ${activity.dot}`} />
            <span
              className={`relative inline-flex size-2.5 rounded-full ${activity.dot.split(' ')[0]}`}
            />
          </span>
          {activity.label}
        </span>
      </header>
      <p className="mt-1 line-clamp-2 text-xs text-slate-400">{agent.role}</p>
      <p className="mt-3 min-h-10 text-sm text-slate-200 line-clamp-2">{state?.detail ?? '—'}</p>
    </article>
  );
}
