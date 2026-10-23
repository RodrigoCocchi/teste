import { sql } from 'drizzle-orm';
import {
  bigint,
  boolean,
  date,
  index,
  integer,
  jsonb,
  numeric,
  pgEnum,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';
import {
  approvalStatusSchema,
  modelTierSchema,
  roleSchema,
  roomSchema,
  ticketCategorySchema,
  ticketPrioritySchema,
  ticketStatusSchema,
} from '@nexus/shared';

// ---------------------------------------------------------------------------
// Enums (derivados dos schemas Zod de @nexus/shared — fonte única de verdade)
// ---------------------------------------------------------------------------
const values = <T extends string>(options: readonly T[]) => options as [T, ...T[]];

export const roleEnum = pgEnum('role', values(roleSchema.options));
export const roomEnum = pgEnum('room', values(roomSchema.options));
export const modelTierEnum = pgEnum('model_tier', values(modelTierSchema.options));
export const ticketStatusEnum = pgEnum('ticket_status', values(ticketStatusSchema.options));
export const ticketPriorityEnum = pgEnum('ticket_priority', values(ticketPrioritySchema.options));
export const ticketCategoryEnum = pgEnum('ticket_category', values(ticketCategorySchema.options));
export const approvalStatusEnum = pgEnum('approval_status', values(approvalStatusSchema.options));
export const messageAuthorEnum = pgEnum('message_author', ['requester', 'agent', 'human']);
export const runStatusEnum = pgEnum('run_status', [
  'queued',
  'running',
  'succeeded',
  'failed',
  'cancelled',
]);
export const stepKindEnum = pgEnum('step_kind', ['prompt', 'tool_call', 'tool_result', 'message']);
export const budgetPeriodEnum = pgEnum('budget_period', ['day', 'month']);

const timestamps = {
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
};

const tenantRef = () =>
  uuid('tenant_id')
    .notNull()
    .references(() => tenants.id, { onDelete: 'cascade' });

// ---------------------------------------------------------------------------
// Tenants
// ---------------------------------------------------------------------------
export const tenants = pgTable('tenants', {
  id: uuid('id').primaryKey().defaultRandom(),
  slug: text('slug').notNull().unique(),
  name: text('name').notNull(),
  plan: text('plan').notNull().default('trial'),
  isDemo: boolean('is_demo').notNull().default(false),
  ...timestamps,
});

// ---------------------------------------------------------------------------
// Auth (tabelas no formato do Better Auth, com nomes no plural)
// ---------------------------------------------------------------------------
export const users = pgTable('users', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  email: text('email').notNull().unique(),
  emailVerified: boolean('email_verified').notNull().default(false),
  image: text('image'),
  ...timestamps,
});

export const sessions = pgTable('sessions', {
  id: text('id').primaryKey(),
  token: text('token').notNull().unique(),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  ipAddress: text('ip_address'),
  userAgent: text('user_agent'),
  userId: text('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  ...timestamps,
});

export const accounts = pgTable('accounts', {
  id: text('id').primaryKey(),
  accountId: text('account_id').notNull(),
  providerId: text('provider_id').notNull(),
  userId: text('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' }),
  accessToken: text('access_token'),
  refreshToken: text('refresh_token'),
  idToken: text('id_token'),
  accessTokenExpiresAt: timestamp('access_token_expires_at', { withTimezone: true }),
  refreshTokenExpiresAt: timestamp('refresh_token_expires_at', { withTimezone: true }),
  scope: text('scope'),
  password: text('password'),
  ...timestamps,
});

export const verifications = pgTable('verifications', {
  id: text('id').primaryKey(),
  identifier: text('identifier').notNull(),
  value: text('value').notNull(),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  ...timestamps,
});

export const memberships = pgTable(
  'memberships',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: tenantRef(),
    userId: text('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    role: roleEnum('role').notNull().default('viewer'),
    ...timestamps,
  },
  (t) => [uniqueIndex('memberships_tenant_user_uq').on(t.tenantId, t.userId)],
);

// ---------------------------------------------------------------------------
// Agentes
// ---------------------------------------------------------------------------
export const agents = pgTable(
  'agents',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: tenantRef(),
    key: text('key').notNull(),
    name: text('name').notNull(),
    role: text('role').notNull(),
    avatar: text('avatar').notNull(),
    modelTier: modelTierEnum('model_tier').notNull(),
    tools: jsonb('tools').$type<string[]>().notNull().default([]),
    permissions: jsonb('permissions').$type<string[]>().notNull().default([]),
    room: roomEnum('room').notNull(),
    desk: text('desk').notNull(),
    maxSteps: integer('max_steps').notNull(),
    maxTokens: integer('max_tokens').notNull(),
    timeoutMs: integer('timeout_ms').notNull(),
    ...timestamps,
  },
  (t) => [uniqueIndex('agents_tenant_key_uq').on(t.tenantId, t.key)],
);

// ---------------------------------------------------------------------------
// Chamados
// ---------------------------------------------------------------------------
export const tickets = pgTable(
  'tickets',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: tenantRef(),
    number: integer('number').notNull(),
    subject: text('subject').notNull(),
    body: text('body').notNull(),
    requesterName: text('requester_name').notNull(),
    requesterEmail: text('requester_email').notNull(),
    status: ticketStatusEnum('status').notNull().default('new'),
    priority: ticketPriorityEnum('priority').notNull().default('medium'),
    category: ticketCategoryEnum('category').notNull().default('other'),
    assignedAgentId: uuid('assigned_agent_id').references(() => agents.id, {
      onDelete: 'set null',
    }),
    source: text('source').notNull().default('manual'),
    externalId: text('external_id'),
    slaDueAt: timestamp('sla_due_at', { withTimezone: true }),
    resolvedAt: timestamp('resolved_at', { withTimezone: true }),
    ...timestamps,
  },
  (t) => [
    uniqueIndex('tickets_tenant_number_uq').on(t.tenantId, t.number),
    index('tickets_tenant_status_idx').on(t.tenantId, t.status),
  ],
);

export const ticketMessages = pgTable(
  'ticket_messages',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: tenantRef(),
    ticketId: uuid('ticket_id')
      .notNull()
      .references(() => tickets.id, { onDelete: 'cascade' }),
    author: messageAuthorEnum('author').notNull(),
    authorAgentId: uuid('author_agent_id').references(() => agents.id, { onDelete: 'set null' }),
    authorUserId: text('author_user_id').references(() => users.id, { onDelete: 'set null' }),
    body: text('body').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index('ticket_messages_ticket_idx').on(t.tenantId, t.ticketId)],
);

// ---------------------------------------------------------------------------
// Execuções de agentes (auditoria total)
// ---------------------------------------------------------------------------
export const agentRuns = pgTable(
  'agent_runs',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: tenantRef(),
    agentId: uuid('agent_id')
      .notNull()
      .references(() => agents.id, { onDelete: 'cascade' }),
    ticketId: uuid('ticket_id').references(() => tickets.id, { onDelete: 'set null' }),
    status: runStatusEnum('status').notNull().default('queued'),
    model: text('model'),
    inputTokens: integer('input_tokens').notNull().default(0),
    outputTokens: integer('output_tokens').notNull().default(0),
    cacheReadTokens: integer('cache_read_tokens').notNull().default(0),
    costUsd: numeric('cost_usd', { precision: 12, scale: 6 }).notNull().default('0'),
    error: text('error'),
    startedAt: timestamp('started_at', { withTimezone: true }),
    finishedAt: timestamp('finished_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index('agent_runs_tenant_agent_idx').on(t.tenantId, t.agentId)],
);

export const agentSteps = pgTable(
  'agent_steps',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: tenantRef(),
    runId: uuid('run_id')
      .notNull()
      .references(() => agentRuns.id, { onDelete: 'cascade' }),
    index: integer('index').notNull(),
    kind: stepKindEnum('kind').notNull(),
    toolName: text('tool_name'),
    input: jsonb('input'),
    output: jsonb('output'),
    inputTokens: integer('input_tokens').notNull().default(0),
    outputTokens: integer('output_tokens').notNull().default(0),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [uniqueIndex('agent_steps_run_index_uq').on(t.runId, t.index)],
);

// ---------------------------------------------------------------------------
// Aprovações (humano no controle)
// ---------------------------------------------------------------------------
export const approvals = pgTable(
  'approvals',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: tenantRef(),
    agentId: uuid('agent_id')
      .notNull()
      .references(() => agents.id, { onDelete: 'cascade' }),
    ticketId: uuid('ticket_id').references(() => tickets.id, { onDelete: 'set null' }),
    runId: uuid('run_id').references(() => agentRuns.id, { onDelete: 'set null' }),
    action: text('action').notNull(),
    summary: text('summary').notNull(),
    payload: jsonb('payload').$type<Record<string, unknown>>().notNull().default({}),
    status: approvalStatusEnum('status').notNull().default('pending'),
    decidedBy: text('decided_by').references(() => users.id, { onDelete: 'set null' }),
    decidedAt: timestamp('decided_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index('approvals_tenant_status_idx').on(t.tenantId, t.status)],
);

// ---------------------------------------------------------------------------
// Conectores e orçamento
// ---------------------------------------------------------------------------
export const connectorCredentials = pgTable('connector_credentials', {
  id: uuid('id').primaryKey().defaultRandom(),
  tenantId: tenantRef(),
  kind: text('kind').notNull(),
  label: text('label').notNull(),
  /** AES-256-GCM (ver @nexus/connectors). A chave fica fora do banco. */
  encryptedSecret: text('encrypted_secret').notNull(),
  config: jsonb('config').$type<Record<string, unknown>>().notNull().default({}),
  ...timestamps,
});

export const tokenBudgets = pgTable(
  'token_budgets',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    tenantId: tenantRef(),
    /** `null` = orçamento do tenant inteiro. */
    agentId: uuid('agent_id').references(() => agents.id, { onDelete: 'cascade' }),
    period: budgetPeriodEnum('period').notNull(),
    periodStart: date('period_start')
      .notNull()
      .default(sql`current_date`),
    limitTokens: bigint('limit_tokens', { mode: 'number' }).notNull(),
    usedTokens: bigint('used_tokens', { mode: 'number' }).notNull().default(0),
    ...timestamps,
  },
  (t) => [
    uniqueIndex('token_budgets_scope_uq')
      .on(t.tenantId, t.agentId, t.period)
      .where(sql`${t.agentId} is not null`),
    uniqueIndex('token_budgets_tenant_uq')
      .on(t.tenantId, t.period)
      .where(sql`${t.agentId} is null`),
  ],
);
