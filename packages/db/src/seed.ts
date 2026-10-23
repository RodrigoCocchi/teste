import { fileURLToPath } from 'node:url';
import { eq } from 'drizzle-orm';
import { AGENT_CATALOG } from '@nexus/agents';
import { createDb, type Database } from './client.js';
import { agents, ticketMessages, tickets, tenants, tokenBudgets } from './schema.js';
import { DEMO_TICKETS, SLA_HOURS } from '@nexus/shared';

export const DEMO_TENANT_SLUG = 'demo';
const HOUR = 3_600_000;

function emailFor(name: string): string {
  const local = name
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '.')
    .replace(/^\.|\.$/g, '');
  return `${local}@vertice.demo`;
}

/** Recria do zero o tenant `demo` (idempotente). Retorna o id do tenant. */
export async function seedDemo(db: Database, now = new Date()): Promise<string> {
  return db.transaction(async (tx) => {
    await tx.delete(tenants).where(eq(tenants.slug, DEMO_TENANT_SLUG));

    const [tenant] = await tx
      .insert(tenants)
      .values({
        slug: DEMO_TENANT_SLUG,
        name: 'Vértice Logística (demo)',
        plan: 'demo',
        isDemo: true,
      })
      .returning({ id: tenants.id });
    if (!tenant) throw new Error('Falha ao criar tenant demo');

    const agentRows = await tx
      .insert(agents)
      .values(AGENT_CATALOG.map((a) => ({ ...a, tenantId: tenant.id })))
      .returning({ id: agents.id, key: agents.key });
    const agentId = new Map(agentRows.map((a) => [a.key, a.id]));

    const ticketRows = await tx
      .insert(tickets)
      .values(
        DEMO_TICKETS.map((d, i) => {
          const createdAt = new Date(now.getTime() - d.ageHours * HOUR);
          const done = d.status === 'resolved' || d.status === 'closed';
          return {
            tenantId: tenant.id,
            number: i + 1,
            subject: d.subject,
            body: d.body,
            requesterName: d.requester,
            requesterEmail: emailFor(d.requester),
            status: d.status,
            priority: d.priority,
            category: d.category,
            assignedAgentId: d.agent ? (agentId.get(d.agent) ?? null) : null,
            source: 'demo',
            slaDueAt: new Date(createdAt.getTime() + SLA_HOURS[d.priority] * HOUR),
            resolvedAt: done
              ? new Date(createdAt.getTime() + Math.min(d.ageHours, 6) * HOUR)
              : null,
            createdAt,
            updatedAt: createdAt,
          };
        }),
      )
      .returning({ id: tickets.id, body: tickets.body, createdAt: tickets.createdAt });

    await tx.insert(ticketMessages).values(
      ticketRows.map((r) => ({
        tenantId: tenant.id,
        ticketId: r.id,
        author: 'requester' as const,
        body: r.body,
        createdAt: r.createdAt,
      })),
    );

    await tx
      .insert(tokenBudgets)
      .values({ tenantId: tenant.id, period: 'month', limitTokens: 5_000_000 });

    return tenant.id;
  });
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const { db, sql } = createDb();
  try {
    const id = await seedDemo(db);
    console.log(
      `Tenant demo criado: ${id} (${AGENT_CATALOG.length} agentes, ${DEMO_TICKETS.length} chamados)`,
    );
  } finally {
    await sql.end();
  }
}
