import { z } from 'zod';

export const ticketStatusSchema = z.enum([
  'new',
  'triaged',
  'in_progress',
  'waiting_approval',
  'waiting_user',
  'resolved',
  'closed',
]);
export type TicketStatus = z.infer<typeof ticketStatusSchema>;

export const ticketPrioritySchema = z.enum(['low', 'medium', 'high', 'critical']);
export type TicketPriority = z.infer<typeof ticketPrioritySchema>;

export const ticketCategorySchema = z.enum([
  'access',
  'hardware',
  'software',
  'network',
  'email',
  'infra',
  'development',
  'other',
]);
export type TicketCategory = z.infer<typeof ticketCategorySchema>;

/** SLA de resolução em horas por prioridade. */
export const SLA_HOURS: Record<TicketPriority, number> = {
  critical: 4,
  high: 8,
  medium: 24,
  low: 72,
};

export const approvalStatusSchema = z.enum(['pending', 'granted', 'denied', 'expired']);
export type ApprovalStatus = z.infer<typeof approvalStatusSchema>;
