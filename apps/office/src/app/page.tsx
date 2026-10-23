'use client';

import dynamic from 'next/dynamic';
import { useState } from 'react';
import { ActivityFeed } from '@/components/activity-feed';
import { AgentDetail } from '@/components/agent-detail';
import { ApprovalsPanel, MetricsPanel, TicketsBoard } from '@/components/panels';
import { useOfficeFeed } from '@/lib/use-office-feed';
import { useOfficeStore } from '@/lib/office-store';

// WebGL só existe no cliente: a cena não entra no HTML estático.
const OfficeCanvas = dynamic(
  () => import('@/office/scene/office-canvas').then((m) => m.OfficeCanvas),
  {
    ssr: false,
    loading: () => (
      <div className="grid size-full place-items-center text-sm text-slate-400">
        Montando o escritório…
      </div>
    ),
  },
);

const CONNECTION = {
  local: { label: 'Demo local', cls: 'bg-sky-400' },
  connecting: { label: 'Conectando…', cls: 'bg-amber-400' },
  online: { label: 'Ao vivo', cls: 'bg-emerald-400' },
  offline: { label: 'Offline', cls: 'bg-rose-500' },
} as const;

const TABS = ['Atividade', 'Aprovações', 'Chamados', 'Métricas'] as const;
type Tab = (typeof TABS)[number];

export default function OfficePage() {
  useOfficeFeed();
  const [tab, setTab] = useState<Tab>('Atividade');
  const [resetSignal, setResetSignal] = useState(0);
  const feed = useOfficeStore((s) => s.feed);
  const roster = useOfficeStore((s) => s.roster);
  const approvals = useOfficeStore((s) => s.approvals.length);
  const standup = useOfficeStore((s) => s.standup);
  const connection = useOfficeStore((s) => s.connection);
  const select = useOfficeStore((s) => s.select);
  const names = Object.fromEntries(roster.map((a) => [a.key, a.name]));
  const conn = CONNECTION[connection];

  return (
    <div className="flex h-dvh flex-col overflow-hidden short:relative short:flex-row lg:relative lg:block">
      <header className="safe-px safe-pt pointer-events-none z-10 flex flex-wrap items-center justify-between gap-2 pb-2 short:absolute short:inset-x-0 short:top-0 short:mr-80 lg:absolute lg:inset-x-0 lg:top-0 lg:bg-gradient-to-b lg:from-black/55 lg:to-transparent lg:pb-8">
        <div className="pointer-events-auto">
          <h1 className="text-lg font-semibold tracking-tight drop-shadow sm:text-2xl">Nexus TI</h1>
          <p className="text-xs text-slate-300/80 sm:text-sm">Vértice Logística · demonstração</p>
        </div>
        <div className="pointer-events-auto flex flex-wrap items-center gap-2 whitespace-nowrap text-xs sm:text-sm lg:mr-[25rem]">
          {standup && <span className="glass-strong rounded-full px-3 py-1">Standup</span>}
          <button
            onClick={() => setTab('Aprovações')}
            className="glass-strong min-h-8 rounded-full px-3 py-1"
          >
            Aprovações<span className="hidden sm:inline"> pendentes</span>:{' '}
            <strong>{approvals}</strong>
          </button>
          <span className="glass-strong flex items-center gap-2 rounded-full px-3 py-1">
            <span className={`size-2 rounded-full ${conn.cls}`} />
            {conn.label}
          </span>
        </div>
      </header>

      <section
        aria-label="Escritório 3D"
        className="relative h-[52dvh] shrink-0 short:h-full short:flex-1 sm:h-[58dvh] lg:absolute lg:inset-0 lg:h-auto"
      >
        <OfficeCanvas resetSignal={resetSignal} />
        <div className="safe-px pointer-events-none absolute inset-x-0 bottom-3 flex items-end justify-between gap-3 lg:bottom-4 lg:right-[25rem]">
          <div className="pointer-events-auto w-full max-w-sm">
            <AgentDetail />
          </div>
          <button
            onClick={() => {
              select(null);
              setResetSignal((n) => n + 1);
            }}
            className="glass-strong pointer-events-auto min-h-11 shrink-0 rounded-full px-4 text-sm"
          >
            Visão geral
          </button>
        </div>
      </section>

      <aside className="safe-px safe-pb flex min-h-0 flex-1 flex-col pt-3 short:w-80 short:flex-none short:pl-0 lg:absolute lg:bottom-4 lg:right-4 lg:top-4 lg:w-96 lg:p-0">
        <div className="glass-strong flex min-h-0 flex-1 flex-col rounded-3xl p-3 lg:p-4">
          <nav
            role="tablist"
            className="mb-3 grid grid-cols-4 gap-1 rounded-2xl bg-black/30 p-1 text-xs sm:text-sm short:text-xs lg:text-xs"
          >
            {TABS.map((t) => (
              <button
                key={t}
                role="tab"
                aria-selected={tab === t}
                onClick={() => setTab(t)}
                className={`min-h-10 rounded-xl px-1 transition-colors ${tab === t ? 'bg-white/15 text-white' : 'text-slate-400 hover:text-slate-200'}`}
              >
                {t}
              </button>
            ))}
          </nav>
          <div className="-mr-2 min-h-0 flex-1 overflow-y-auto pr-2">
            {tab === 'Atividade' && <ActivityFeed events={feed} names={names} />}
            {tab === 'Aprovações' && <ApprovalsPanel />}
            {tab === 'Chamados' && <TicketsBoard />}
            {tab === 'Métricas' && <MetricsPanel />}
          </div>
        </div>
      </aside>
    </div>
  );
}
