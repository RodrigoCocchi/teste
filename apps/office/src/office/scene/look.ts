import type { AgentActivity } from '@/lib/office-state';

/** Identidade visual de cada agente (cor do uniforme, pele, cabelo). */
export const AGENT_LOOK: Record<string, { color: string; skin: string; hair: string }> = {
  manager: { color: '#f4b860', skin: '#e0ac85', hair: '#2b1d14' },
  triage: { color: '#2dd4bf', skin: '#c68a64', hair: '#1a1410' },
  support_n1: { color: '#60a5fa', skin: '#f1c7a5', hair: '#7a4a24' },
  infra: { color: '#fb923c', skin: '#8d5a3b', hair: '#0f0c0a' },
  dev: { color: '#a78bfa', skin: '#f3d2b8', hair: '#c9a26b' },
  qa: { color: '#f472b6', skin: '#a8704f', hair: '#3a2416' },
  docs: { color: '#a3e635', skin: '#6f4630', hair: '#141010' },
};

export const DEFAULT_LOOK = { color: '#94a3b8', skin: '#e0ac85', hair: '#222' };

/** Cor e intensidade da tela do monitor conforme o que o dono da mesa está fazendo. */
export const SCREEN_GLOW: Record<AgentActivity, { color: string; intensity: number }> = {
  idle: { color: '#3b4a6b', intensity: 0.6 },
  thinking: { color: '#a78bfa', intensity: 2.2 },
  working: { color: '#60a5fa', intensity: 3 },
  walking: { color: '#3b4a6b', intensity: 0.6 },
  talking: { color: '#93c5fd', intensity: 1.6 },
  waiting_approval: { color: '#fbbf24', intensity: 3 },
  done: { color: '#34d399', intensity: 2.4 },
  error: { color: '#f43f5e', intensity: 3 },
};

export const PALETTE = {
  floor: '#3b3f47',
  wall: '#d7dbe2',
  wallTrim: '#9aa3b2',
  glass: '#b9d4ff',
  frame: '#c4cad4',
  desk: '#e9e4dc',
  deskLeg: '#2a2d33',
  chair: '#1f2329',
  monitor: '#0e1014',
  rack: '#16191f',
  wood: '#8a6243',
  sofa: '#46566f',
  plantPot: '#e7e2da',
  leaf: '#3f8f5a',
};
