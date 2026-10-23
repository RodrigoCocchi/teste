'use client';

import { useEffect, useState } from 'react';
import { API_URL } from './config';

export interface AgentInfo {
  key: string;
  name: string;
  role: string;
  room: string;
}

export function useAgents(tenant: string): AgentInfo[] {
  const [agents, setAgents] = useState<AgentInfo[]>([]);
  useEffect(() => {
    const controller = new AbortController();
    fetch(`${API_URL}/api/tenants/${tenant}/agents`, {
      credentials: 'include',
      signal: controller.signal,
    })
      .then((r) => (r.ok ? (r.json() as Promise<AgentInfo[]>) : []))
      .then(setAgents)
      .catch(() => undefined);
    return () => controller.abort();
  }, [tenant]);
  return agents;
}
