'use client';

import { ActivityFeed } from '@/components/activity-feed';
import { AgentCard } from '@/components/agent-card';
import { useAgents } from '@/lib/use-agents';
import { useOfficeSocket } from '@/lib/use-office-socket';
import { useOfficeStore } from '@/lib/office-store';

const TENANT = 'demo';

const CONNECTION = {
  connecting: { label: 'Conectando…', cls: 'bg-amber-400' },
  online: { label: 'Ao vivo', cls: 'bg-emerald-400' },
  offline: { label: 'Offline', cls: 'bg-rose-500' },
} as const;

export default function OfficePage() {
  useOfficeSocket(TENANT);
  const agents = useAgents(TENANT);
  const { agents: states, feed, pendingApprovals, standup, connection } = useOfficeStore();
  const names = Object.fromEntries(agents.map((a) => [a.key, a.name]));
  const conn = CONNECTION[connection];

  return (
    <div className="safe-px safe-pt safe-pb mx-auto flex min-h-dvh max-w-7xl flex-col gap-4">
      <header className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold tracking-tight sm:text-2xl">Nexus TI</h1>
          <p className="text-xs text-slate-400 sm:text-sm">Vértice Logística · modo demonstração</p>
        </div>
        <div className="flex flex-wrap items-center gap-2 whitespace-nowrap text-xs sm:text-sm">
          {standup && (
            <span className="glass rounded-full px-3 py-1">
              Standup<span className="hidden sm:inline"> em andamento</span>
            </span>
          )}
          <span className="glass rounded-full px-3 py-1">
            Aprovações<span className="hidden sm:inline"> pendentes</span>:{' '}
            <strong>{pendingApprovals}</strong>
          </span>
          <span className="glass flex items-center gap-2 rounded-full px-3 py-1">
            <span className={`size-2 rounded-full ${conn.cls}`} />
            {conn.label}
          </span>
        </div>
      </header>

      <div className="grid flex-1 gap-4 lg:grid-cols-[1fr_22rem]">
        <section aria-labelledby="agents-title" className="flex flex-col gap-3">
          {/* Fase 2: este palco recebe o canvas 3D (React Three Fiber). */}
          <div className="glass relative aspect-[16/9] w-full overflow-hidden rounded-3xl max-sm:aspect-[4/5]">
            <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_30%_20%,rgba(124,156,255,0.25),transparent_60%),radial-gradient(ellipse_at_80%_80%,rgba(45,212,191,0.15),transparent_55%)]" />
            <div className="absolute inset-0 grid place-items-center p-6 text-center">
              <p className="text-sm text-slate-300">Escritório 3D chega na Fase 2</p>
            </div>
          </div>
          <h2 id="agents-title" className="sr-only">
            Agentes
          </h2>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3">
            {agents.map((a) => (
              <AgentCard key={a.key} agent={a} state={states[a.key]} />
            ))}
          </div>
        </section>

        <aside className="glass flex max-h-[70dvh] flex-col rounded-3xl p-4 lg:sticky lg:top-4 lg:max-h-[calc(100dvh-2rem)]">
          <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-slate-400">
            Atividade
          </h2>
          <div className="-mr-2 overflow-y-auto pr-2">
            <ActivityFeed events={feed} names={names} />
          </div>
        </aside>
      </div>
    </div>
  );
}
