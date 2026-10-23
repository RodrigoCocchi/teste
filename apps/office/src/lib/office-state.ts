import type { OfficeEvent, OfficeEventType } from '@nexus/shared';

export type AgentActivity =
  'idle' | 'thinking' | 'working' | 'walking' | 'talking' | 'waiting_approval' | 'done' | 'error';

export interface AgentState {
  activity: AgentActivity;
  detail: string | null;
  updatedAt: string;
}

export interface OfficeState {
  agents: Record<string, AgentState>;
  feed: OfficeEvent[];
  pendingApprovals: number;
  standup: boolean;
}

export const FEED_LIMIT = 50;

export const initialOfficeState: OfficeState = {
  agents: {},
  feed: [],
  pendingApprovals: 0,
  standup: false,
};

const AGENT_TYPES: Partial<Record<OfficeEventType, AgentActivity>> = {
  'agent.idle': 'idle',
  'agent.thinking': 'thinking',
  'agent.working': 'working',
  'agent.walking': 'walking',
  'agent.talking': 'talking',
  'agent.waiting_approval': 'waiting_approval',
  'agent.done': 'done',
  'agent.error': 'error',
};

function detailOf(event: OfficeEvent): string | null {
  const { task, text, to, summary } = event.payload;
  for (const value of [text, task, summary]) if (typeof value === 'string') return value;
  if (typeof to === 'string') return `Indo até ${to}`;
  return null;
}

/** Reducer puro: o visual só reflete eventos, nunca contém regra de negócio. */
export function reduceOfficeEvent(state: OfficeState, event: OfficeEvent): OfficeState {
  const activity = AGENT_TYPES[event.type];
  const agents = activity
    ? {
        ...state.agents,
        [event.agentId]: { activity, detail: detailOf(event), updatedAt: event.ts },
      }
    : state.agents;

  let { pendingApprovals, standup } = state;
  if (event.type === 'approval.requested') pendingApprovals += 1;
  if (event.type === 'approval.granted' || event.type === 'approval.denied')
    pendingApprovals = Math.max(0, pendingApprovals - 1);
  if (event.type === 'standup.started') standup = true;
  if (event.type === 'standup.ended') standup = false;

  const silent = event.type === 'agent.idle';
  const feed = silent ? state.feed : [event, ...state.feed].slice(0, FEED_LIMIT);
  return { agents, feed, pendingApprovals, standup };
}
