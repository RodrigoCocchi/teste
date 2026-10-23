import { z } from 'zod';

export const officeEventTypeSchema = z.enum([
  'agent.idle',
  'agent.thinking',
  'agent.working',
  'agent.walking',
  'agent.talking',
  'agent.waiting_approval',
  'agent.done',
  'agent.error',
  'ticket.created',
  'ticket.updated',
  'ticket.resolved',
  'approval.requested',
  'approval.granted',
  'approval.denied',
  'standup.started',
  'standup.ended',
]);
export type OfficeEventType = z.infer<typeof officeEventTypeSchema>;

/** Contrato API → Escritório 3D (CLAUDE.md §6). */
export const officeEventSchema = z.object({
  ts: z.iso.datetime(),
  tenantId: z.string().min(1),
  agentId: z.string().min(1),
  type: officeEventTypeSchema,
  payload: z.record(z.string(), z.unknown()),
});
export type OfficeEvent = z.infer<typeof officeEventSchema>;
