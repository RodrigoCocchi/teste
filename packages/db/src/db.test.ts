import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { and, count, eq } from 'drizzle-orm';
import { createDb } from './client.js';
import { runMigrations } from './migrate.js';
import { agents, tickets } from './schema.js';
import { seedDemo } from './seed.js';

const url = process.env.DATABASE_URL;

describe.skipIf(!url)('banco (integração)', () => {
  const { db, sql } = createDb(url);
  let tenantId = '';

  beforeAll(async () => {
    await runMigrations(url);
    tenantId = await seedDemo(db);
  });
  afterAll(() => sql.end());

  it('seed cria 7 agentes e 30 chamados no tenant demo', async () => {
    const [a] = await db.select({ n: count() }).from(agents).where(eq(agents.tenantId, tenantId));
    const [t] = await db.select({ n: count() }).from(tickets).where(eq(tickets.tenantId, tenantId));
    expect(a?.n).toBe(7);
    expect(t?.n).toBe(30);
  });

  it('seed é idempotente', async () => {
    const again = await seedDemo(db);
    const [t] = await db.select({ n: count() }).from(tickets).where(eq(tickets.tenantId, again));
    expect(t?.n).toBe(30);
    const [old] = await db
      .select({ n: count() })
      .from(tickets)
      .where(and(eq(tickets.tenantId, tenantId)));
    expect(old?.n).toBe(0);
  });
});
