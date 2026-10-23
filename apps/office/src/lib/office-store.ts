'use client';

import { create } from 'zustand';
import type { OfficeEvent } from '@nexus/shared';
import { initialOfficeState, reduceOfficeEvent, type OfficeState } from './office-state';

export type ConnectionStatus = 'connecting' | 'online' | 'offline';

interface OfficeStore extends OfficeState {
  connection: ConnectionStatus;
  apply: (event: OfficeEvent) => void;
  setConnection: (connection: ConnectionStatus) => void;
}

export const useOfficeStore = create<OfficeStore>((set) => ({
  ...initialOfficeState,
  connection: 'connecting',
  apply: (event) => set((state) => reduceOfficeEvent(state, event)),
  setConnection: (connection) => set({ connection }),
}));
