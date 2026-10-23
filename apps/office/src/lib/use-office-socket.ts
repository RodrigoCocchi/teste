'use client';

import { useEffect } from 'react';
import { officeEventSchema } from '@nexus/shared';
import { wsUrl } from './config';
import { useOfficeStore } from './office-store';

/** Conecta ao WebSocket do tenant e reconecta com backoff exponencial (até 15 s). */
export function useOfficeSocket(tenant: string): void {
  const apply = useOfficeStore((s) => s.apply);
  const setConnection = useOfficeStore((s) => s.setConnection);

  useEffect(() => {
    let socket: WebSocket | null = null;
    let retry: ReturnType<typeof setTimeout> | undefined;
    let attempt = 0;
    let disposed = false;

    const connect = () => {
      setConnection('connecting');
      socket = new WebSocket(wsUrl(tenant));
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
        if (disposed) return;
        retry = setTimeout(connect, Math.min(15_000, 500 * 2 ** attempt++));
      };
    };

    connect();
    return () => {
      disposed = true;
      clearTimeout(retry);
      socket?.close();
    };
  }, [tenant, apply, setConnection]);
}
