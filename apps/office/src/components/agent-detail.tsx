'use client';

import { useOfficeStore } from '@/lib/office-store';
import type { AgentActivity } from '@/lib/office-state';

const LABEL: Record<AgentActivity, string> = {
  idle: 'Disponível',
  thinking: 'Pensando',
  working: 'Trabalhando',
  walking: 'Caminhando',
  talking: 'Conversando',
  waiting_approval: 'Aguardando aprovação',
  done: 'Concluiu',
  error: 'Erro',
};

/** Ficha do agente selecionado: o que está fazendo agora e o histórico recente. */
export function AgentDetail() {
  const selected = useOfficeStore((s) => s.selected);
  const agent = useOfficeStore((s) => s.roster.find((a) => a.key === s.selected));
  const state = useOfficeStore((s) => (s.selected ? s.agents[s.selected] : undefined));
  const feed = useOfficeStore((s) => s.feed);
  const following = useOfficeStore((s) => s.following);
  const { select, setFollowing } = useOfficeStore.getState();
  if (!selected || !agent) return null;

  const history = feed.filter((e) => e.agentId === selected).slice(0, 4);
  return (
    <div
      className="glass-strong w-full rounded-2xl p-4 shadow-2xl sm:w-80"
      role="dialog"
      aria-label={`Ficha de ${agent.name}`}
    >
      <div className="flex items-start justify-between gap-3">
        <div>
          <h2 className="text-base font-semibold">{agent.name}</h2>
          <p className="text-xs text-slate-400">{agent.role}</p>
        </div>
        <button
          onClick={() => select(null)}
          className="grid size-11 shrink-0 place-items-center rounded-full text-slate-300 hover:bg-white/10"
          aria-label="Fechar ficha"
        >
          ✕
        </button>
      </div>
      <p className="mt-2 text-sm">
        <span className="text-slate-400">{LABEL[state?.activity ?? 'idle']}</span>
        {state?.detail && <span className="text-slate-200">: {state.detail}</span>}
      </p>
      {history.length > 0 && (
        <ul className="mt-2 space-y-1 text-xs text-slate-400">
          {history.map((e, i) => (
            <li key={i} className="truncate">
              {new Date(e.ts).toLocaleTimeString('pt-BR', {
                hour: '2-digit',
                minute: '2-digit',
                second: '2-digit',
              })}{' '}
              · {String(e.payload.text ?? e.payload.task ?? e.payload.summary ?? e.type)}
            </li>
          ))}
        </ul>
      )}
      <label className="mt-3 flex min-h-11 cursor-pointer items-center gap-2 text-sm text-slate-300">
        <input
          type="checkbox"
          checked={following}
          onChange={(e) => setFollowing(e.target.checked)}
          className="size-4 accent-[--color-accent]"
        />
        Câmera seguindo o agente
      </label>
    </div>
  );
}
