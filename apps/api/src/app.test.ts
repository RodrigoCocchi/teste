import type { AddressInfo } from 'node:net';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import WebSocket from 'ws';
import { createDb, eq, memberships, runMigrations, seedDemo, tenants } from '@nexus/db';
import { officeEventSchema, type OfficeEvent } from '@nexus/shared';
import { buildApp } from './app.js';
import { createAuth } from './auth.js';
import { loadEnv } from './env.js';

const url = process.env.DATABASE_URL;

describe.skipIf(!url)('API (integração)', () => {
  const env = loadEnv({
    NODE_ENV: 'test',
    DATABASE_URL: url,
    AUTH_SECRET: 'test-secret-test-secret-test-secret-123',
    MOCK_EVENT_INTERVAL_MS: '20',
  });
  const { db, sql } = createDb(url);
  const auth = createAuth(db, env);
  let app: Awaited<ReturnType<typeof buildApp>>;
  let base = '';
  let privateSlug = '';

  async function signUp(email: string): Promise<{ token: string; userId: string }> {
    const res = await app.inject({
      method: 'POST',
      url: '/api/auth/sign-up/email',
      payload: { email, password: 'senha-super-forte-123', name: 'Teste' },
    });
    expect(res.statusCode).toBe(200);
    return { token: String(res.headers['set-auth-token']), userId: res.json().user.id };
  }

  beforeAll(async () => {
    await runMigrations(url);
    await seedDemo(db);
    privateSlug = `acme-${Date.now()}`;
    await db.insert(tenants).values({ slug: privateSlug, name: 'Acme (teste)' });
    app = await buildApp({ db, auth, env });
    await app.listen({ port: 0, host: '127.0.0.1' });
    base = `127.0.0.1:${(app.server.address() as AddressInfo).port}`;
  });

  afterAll(async () => {
    await app.close();
    await sql.end();
  });

  it('GET /health', async () => {
    expect((await app.inject('/health')).json()).toEqual({ ok: true });
  });

  it('tenant demo é público para leitura', async () => {
    const res = await app.inject('/api/tenants/demo/agents');
    expect(res.statusCode).toBe(200);
    expect(res.json()).toHaveLength(7);
    const tickets = await app.inject('/api/tenants/demo/tickets?status=new');
    expect(tickets.json().length).toBeGreaterThan(0);
    expect(tickets.json().every((t: { status: string }) => t.status === 'new')).toBe(true);
  });

  it('valida a query', async () => {
    expect((await app.inject('/api/tenants/demo/tickets?status=xyz')).statusCode).toBe(400);
  });

  it('RBAC: tenant privado exige login, membership e papel', async () => {
    expect((await app.inject(`/api/tenants/${privateSlug}/agents`)).statusCode).toBe(401);
    expect((await app.inject('/api/tenants/nao-existe/agents')).statusCode).toBe(404);

    const { token, userId } = await signUp(`rbac-${Date.now()}@teste.demo`);
    const authHeaders = { authorization: `Bearer ${token}` };
    expect(
      (await app.inject({ url: `/api/tenants/${privateSlug}/agents`, headers: authHeaders }))
        .statusCode,
    ).toBe(403);

    const [tenant] = await db.select().from(tenants).where(eq(tenants.slug, privateSlug));
    await db.insert(memberships).values({ tenantId: tenant!.id, userId, role: 'viewer' });
    expect(
      (await app.inject({ url: `/api/tenants/${privateSlug}/agents`, headers: authHeaders }))
        .statusCode,
    ).toBe(200);
    expect(
      (await app.inject({ url: `/api/tenants/${privateSlug}/members`, headers: authHeaders }))
        .statusCode,
    ).toBe(403);

    await db.update(memberships).set({ role: 'admin' }).where(eq(memberships.userId, userId));
    const members = await app.inject({
      url: `/api/tenants/${privateSlug}/members`,
      headers: authHeaders,
    });
    expect(members.statusCode).toBe(200);
    expect(members.json()[0].role).toBe('admin');

    const mine = await app.inject({ url: '/api/me/tenants', headers: authHeaders });
    expect(mine.json()).toEqual([{ slug: privateSlug, name: 'Acme (teste)', role: 'admin' }]);
  });

  it('WebSocket do demo emite estado inicial e eventos mockados válidos', async () => {
    const ws = new WebSocket(`ws://${base}/ws?tenant=demo`);
    const events: OfficeEvent[] = await new Promise((resolve, reject) => {
      const got: OfficeEvent[] = [];
      ws.on('message', (raw) => {
        got.push(officeEventSchema.parse(JSON.parse(String(raw))));
        if (got.length >= 12) resolve(got);
      });
      ws.on('error', reject);
      setTimeout(() => reject(new Error('timeout')), 5000);
    });
    ws.close();
    expect(events.slice(0, 7).every((e) => e.type === 'agent.idle')).toBe(true);
    expect(events.slice(7).some((e) => e.type !== 'agent.idle')).toBe(true);
  });

  it('WebSocket recusa tenant privado sem sessão', async () => {
    const ws = new WebSocket(`ws://${base}/ws?tenant=${privateSlug}`);
    const code = await new Promise<number>((resolve) => ws.on('close', (c) => resolve(c)));
    expect(code).toBe(4401);
  });
});
