import type { OfficeEvent } from '@nexus/shared';

type Listener = (event: OfficeEvent) => void;

/**
 * Distribui eventos por tenant. Para tenants demo, um único gerador mockado por tenant
 * roda enquanto houver alguém conectado.
 */
export class EventHub {
  private listeners = new Map<string, Set<Listener>>();
  private timers = new Map<string, NodeJS.Timeout>();

  constructor(
    private readonly intervalMs: number,
    private readonly mockSource: (tenantId: string) => Iterator<OfficeEvent>,
  ) {}

  subscribe(tenantId: string, listener: Listener, { mock }: { mock: boolean }): () => void {
    const set = this.listeners.get(tenantId) ?? new Set();
    set.add(listener);
    this.listeners.set(tenantId, set);
    if (mock && !this.timers.has(tenantId)) {
      const source = this.mockSource(tenantId);
      this.timers.set(
        tenantId,
        setInterval(() => {
          const next = source.next();
          if (!next.done) this.publish(next.value);
        }, this.intervalMs),
      );
    }
    return () => {
      set.delete(listener);
      if (set.size === 0) {
        this.listeners.delete(tenantId);
        clearInterval(this.timers.get(tenantId));
        this.timers.delete(tenantId);
      }
    };
  }

  publish(event: OfficeEvent): void {
    for (const listener of this.listeners.get(event.tenantId) ?? []) listener(event);
  }

  close(): void {
    for (const timer of this.timers.values()) clearInterval(timer);
    this.timers.clear();
    this.listeners.clear();
  }
}
