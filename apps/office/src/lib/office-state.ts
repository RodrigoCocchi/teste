import type { OfficeEvent, OfficeEventType, TicketPriority, TicketStatus } from '@nexus/shared';

export type AgentActivity =
  'idle' | 'thinking' | 'working' | 'walking' | 'talking' | 'waiting_approval' | 'done' | 'error';

/** Onde o agente deveria estar. A cena converte isso em um ponto do layout. */
export type AgentLocation = { kind: 'desk' } | { kind: 'visit'; desk: string };

export interface AgentState {
  activity: AgentActivity;
  detail: string | null;
  location: AgentLocation;
  updatedAt: string;
}

export interface TicketView {
  number: number;
  subject: string;
  requester: string;
  status: TicketStatus;
  priority: TicketPriority;
  createdAt: string;
}

export interface ApprovalView {
  id: string;
  agentId: string;
  summary: string;
  ticketNumber: number | null;
  requestedAt: string;
}

export interface OfficeState {
  agents: Record<string, AgentState>;
  feed: OfficeEvent[];
  tickets: Record<number, TicketView>;
  approvals: ApprovalView[];
  standup: boolean;
  stats: { created: number; resolved: number; approvalsGranted: number; approvalsDenied: number };
}

export const FEED_LIMIT = 50;

export const initialOfficeState: OfficeState = {
  agents: {},
  feed: [],
  tickets: {},
  approvals: [],
  standup: false,
  stats: { created: 0, resolved: 0, approvalsGranted: 0, approvalsDenied: 0 },
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

const str = (v: unknown): string | null => (typeof v === 'string' ? v : null);
const num = (v: unknown): number | null => (typeof v === 'number' ? v : null);

function detailOf(event: OfficeEvent): string | null {
  const { task, text, summary } = event.payload;
  return str(text) ?? str(task) ?? str(summary);
}

function nextLocation(event: OfficeEvent, previous: AgentLocation | undefined): AgentLocation {
  if (event.type === 'agent.walking') {
    const desk = str(event.payload.to);
    return desk ? { kind: 'visit', desk } : (previous ?? { kind: 'desk' });
  }
  // Conversar não tira o agente do lugar; qualquer outro estado o leva de volta à mesa.
  if (event.type === 'agent.talking') return previous ?? { kind: 'desk' };
  return { kind: 'desk' };
}

function reduceTicket(
  tickets: Record<number, TicketView>,
  event: OfficeEvent,
): Record<number, TicketView> {
  const number = num(event.payload.ticketNumber);
  if (number === null) return tickets;
  const current = tickets[number];
  if (event.type === 'ticket.created') {
    return {
      ...tickets,
      [number]: {
        number,
        subject: str(event.payload.subject) ?? `Chamado #${number}`,
        requester: str(event.payload.requester) ?? '—',
        status: 'new',
        priority: 'medium',
        createdAt: event.ts,
      },
    };
  }
  if (!current) return tickets;
  if (event.type === 'ticket.updated') {
    const status = str(event.payload.status) as TicketStatus | null;
    const priority = str(event.payload.priority) as TicketPriority | null;
    return {
      ...tickets,
      [number]: {
        ...current,
        status: status ?? current.status,
        priority: priority ?? current.priority,
      },
    };
  }
  if (event.type === 'approval.requested')
    return { ...tickets, [number]: { ...current, status: 'waiting_approval' } };
  if (event.type === 'approval.granted')
    return { ...tickets, [number]: { ...current, status: 'in_progress' } };
  if (event.type === 'ticket.resolved')
    return { ...tickets, [number]: { ...current, status: 'resolved' } };
  return tickets;
}

/** Reducer puro: o visual só reflete eventos, nunca contém regra de negócio. */
export function reduceOfficeEvent(state: OfficeState, event: OfficeEvent): OfficeState {
  let agents = state.agents;
  const activity = AGENT_TYPES[event.type];
  if (activity) {
    const previous = agents[event.agentId];
    agents = {
      ...agents,
      [event.agentId]: {
        activity,
        detail: detailOf(event),
        location: nextLocation(event, previous?.location),
        updatedAt: event.ts,
      },
    };
  }

  let { standup, approvals } = state;
  const stats = { ...state.stats };
  switch (event.type) {
    case 'standup.started':
      standup = true;
      break;
    case 'standup.ended':
      standup = false;
      // Fim da reunião: todos voltam às mesas e as conversas do standup se encerram.
      agents = Object.fromEntries(
        Object.entries(agents).map(([k, a]) => [
          k,
          {
            ...a,
            activity: a.activity === 'talking' ? 'idle' : a.activity,
            location: { kind: 'desk' } as AgentLocation,
          },
        ]),
      );
      break;
    case 'approval.requested': {
      const id = str(event.payload.approvalId) ?? `${event.agentId}-${event.ts}`;
      approvals = [
        ...approvals.filter((a) => a.id !== id),
        {
          id,
          agentId: event.agentId,
          summary: str(event.payload.summary) ?? 'Ação aguardando aprovação',
          ticketNumber: num(event.payload.ticketNumber),
          requestedAt: event.ts,
        },
      ];
      break;
    }
    case 'approval.granted':
    case 'approval.denied': {
      const id = str(event.payload.approvalId);
      approvals = approvals.filter((a) => a.id !== id);
      if (event.type === 'approval.granted') stats.approvalsGranted += 1;
      else stats.approvalsDenied += 1;
      break;
    }
    case 'ticket.created':
      stats.created += 1;
      break;
    case 'ticket.resolved':
      stats.resolved += 1;
      break;
  }

  const silent = event.type === 'agent.idle';
  const feed = silent ? state.feed : [event, ...state.feed].slice(0, FEED_LIMIT);
  return { agents, feed, tickets: reduceTicket(state.tickets, event), approvals, standup, stats };
}
