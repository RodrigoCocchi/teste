'use client';

import { useEffect } from 'react';
import { AGENT_CATALOG } from '@nexus/agents';
import {
  DEMO_TICKETS,
  demoEventStream,
  officeEventSchema,
  type TicketPriority,
  type TicketStatus,
} from '@nexus/shared';
import { API_URL, TENANT, wsUrl } from './config';
import { useOfficeStore, type AgentInfo } from './office-store';
import type { TicketView } from './office-state';

const LOCAL_INTERVAL_MS = 2200;

/** Liga o escritório à fonte de eventos: API (WebSocket) ou simulação local. */
export function useOfficeFeed(): void {
  useEffect(() => (API_URL ? connectRemote(API_URL) : runLocal()), []);
}

function runLocal(): () => void {
  const { apply, load, setConnection } = useOfficeStore.getState();
  const now = Date.now();
  load(
    AGENT_CATALOG.map(({ key, name, role, desk }) => ({ key, name, role, desk })),
    DEMO_TICKETS.map((t, i) => ({
      number: i + 1,
      subject: t.subject,
      requester: t.requester,
      status: t.status,
      priority: t.priority,
      createdAt: new Date(now - t.ageHours * 3_600_000).toISOString(),
    })),
  );
  setConnection('local');
  const stream = demoEventStream(TENANT);
  const timer = setInterval(() => apply(stream.next().value), LOCAL_INTERVAL_MS);
  return () => clearInterval(timer);
}

interface ApiTicket {
  number: number;
  subject: string;
  requesterName: string;
  status: TicketStatus;
  priority: TicketPriority;
  createdAt: string;
}

function connectRemote(apiUrl: string): () => void {
  const { apply, load, setConnection } = useOfficeStore.getState();
  const controller = new AbortController();
  const get = <T>(path: string) =>
    fetch(`${apiUrl}/api/tenants/${TENANT}${path}`, {
      credentials: 'include',
      signal: controller.signal,
    }).then((r) => (r.ok ? (r.json() as Promise<T>) : Promise.reject(new Error(String(r.status)))));
  Promise.all([get<AgentInfo[]>('/agents'), get<ApiTicket[]>('/tickets')])
    .then(([agents, tickets]) =>
      load(
        agents,
        tickets.map<TicketView>((t) => ({ ...t, requester: t.requesterName })),
      ),
    )
    .catch(() => undefined);

  let socket: WebSocket | null = null;
  let retry: ReturnType<typeof setTimeout> | undefined;
  let attempt = 0;
  let disposed = false;
  const connect = () => {
    setConnection('connecting');
    socket = new WebSocket(wsUrl(apiUrl, TENANT));
    socket.onopen = () => {
      attempt = 0;
      setConnection('online');
    };
    socket.onmessage = (msg) => {
      const parsed = officeEventSchema.safeParse(JSON.parse(String(msg.data)));
      if (parsed.success) apply(parsed.data);
    };
    socket.onclose = () => {
      setConnection('offline');
      if (!disposed) retry = setTimeout(connect, Math.min(15_000, 500 * 2 ** attempt++));
    };
  };
  connect();
  return () => {
    disposed = true;
    controller.abort();
    clearTimeout(retry);
    socket?.close();
  };
}
