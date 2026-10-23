import type { TicketPriority } from '@nexus/shared';

export type ConnectorKind =
  'email' | 'webhook' | 'tomticket' | 'glpi' | 'm365' | 'gmail' | 'github' | 'zabbix';

export interface ExternalTicket {
  externalId: string;
  subject: string;
  body: string;
  requesterEmail: string;
  priority?: TicketPriority;
}

/** Contrato que todo conector de chamados implementa (Fase 4). */
export interface TicketConnector {
  readonly kind: ConnectorKind;
  fetchNew(since: Date): Promise<ExternalTicket[]>;
  reply(externalId: string, message: string): Promise<void>;
  close(externalId: string): Promise<void>;
}
