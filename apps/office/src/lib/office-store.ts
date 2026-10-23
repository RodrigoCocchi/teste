'use client';

import { create } from 'zustand';
import type { OfficeEvent } from '@nexus/shared';
import {
  initialOfficeState,
  reduceOfficeEvent,
  type OfficeState,
  type TicketView,
} from './office-state';

export type ConnectionStatus = 'local' | 'connecting' | 'online' | 'offline';

export interface AgentInfo {
  key: string;
  name: string;
  role: string;
  desk: string;
}

interface OfficeStore extends OfficeState {
  connection: ConnectionStatus;
  roster: AgentInfo[];
  selected: string | null;
  following: boolean;
  apply: (event: OfficeEvent) => void;
  load: (roster: AgentInfo[], tickets: TicketView[]) => void;
  setConnection: (connection: ConnectionStatus) => void;
  select: (key: string | null) => void;
  setFollowing: (following: boolean) => void;
}

export const useOfficeStore = create<OfficeStore>((set) => ({
  ...initialOfficeState,
  connection: 'connecting',
  roster: [],
  selected: null,
  following: false,
  apply: (event) => set((state) => reduceOfficeEvent(state, event)),
  load: (roster, tickets) =>
    set({ roster, tickets: Object.fromEntries(tickets.map((t) => [t.number, t])) }),
  setConnection: (connection) => set({ connection }),
  select: (selected) => set({ selected, following: selected !== null }),
  setFollowing: (following) => set({ following }),
}));
