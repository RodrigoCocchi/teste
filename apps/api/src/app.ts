import cors from '@fastify/cors';
import websocket from '@fastify/websocket';
import Fastify, { type FastifyInstance } from 'fastify';
import { z } from 'zod';
import {
  agents,
  and,
  approvals,
  asc,
  desc,
  eq,
  memberships,
  sql,
  tenants,
  tickets,
  users,
  type Database,
} from '@nexus/db';
import { approvalStatusSchema, ticketStatusSchema } from '@nexus/shared';
import type { Auth } from './auth.js';
import { trustedOrigins, type Env } from './env.js';
import { EventHub } from './event-hub.js';
import { toFetchHeaders } from './http.js';
import { demoEventStream } from '@nexus/shared';
import { requireRole, resolveAccess } from './tenancy.js';

export interface AppDeps {
  db: Database;
  auth: Auth;
  env: Env;
}

const tenantParams = z.object({ tenant: z.string().min(1) });
const wsQuery = z.object({ tenant: z.string().min(1), token: z.string().optional() });

export async function buildApp({ db, auth, env }: AppDeps): Promise<FastifyInstance> {
  const app = Fastify({
    logger:
      env.NODE_ENV === 'test' ? false : { level: env.NODE_ENV === 'production' ? 'info' : 'debug' },
  });
  const hub = new EventHub(env.MOCK_EVENT_INTERVAL_MS, (tenantId) => demoEventStream(tenantId));
  app.addHook('onClose', async () => hub.close());

  await app.register(cors, {
    origin: trustedOrigins(env),
    credentials: true,
    exposedHeaders: ['set-auth-token'],
  });
  await app.register(websocket);

  app.get('/health', async () => {
    await db.execute(sql`select 1`);
    return { ok: true };
  });

  // --- Better Auth -----------------------------------------------------------
  app.route({
    method: ['GET', 'POST'],
    url: '/api/auth/*',
    handler: async (req, reply) => {
      const request = new Request(new URL(req.url, env.API_URL), {
        method: req.method,
        headers: toFetchHeaders(req),
        body: req.method === 'GET' || req.body === undefined ? undefined : JSON.stringify(req.body),
      });
      const res = await auth.handler(request);
      reply.status(res.status);
      res.headers.forEach((value, key) => {
        if (key !== 'set-cookie') reply.header(key, value);
      });
      const cookies = res.headers.getSetCookie();
      if (cookies.length) reply.header('set-cookie', cookies);
      return reply.send(res.body ? await res.text() : null);
    },
  });

  app.get('/api/me/tenants', async (req, reply) => {
    const session = await auth.api.getSession({ headers: toFetchHeaders(req) });
    if (!session) return reply.code(401).send({ error: 'Não autenticado' });
    return db
      .select({ slug: tenants.slug, name: tenants.name, role: memberships.role })
      .from(memberships)
      .innerJoin(tenants, eq(tenants.id, memberships.tenantId))
      .where(eq(memberships.userId, session.user.id))
      .orderBy(asc(tenants.name));
  });

  // --- Rotas por tenant (todas filtradas por tenant_id) ----------------------
  app.register(
    async (scoped) => {
      scoped.addHook('preValidation', async (req) => {
        req.params = tenantParams.parse(req.params);
      });

      scoped.get('/agents', { preHandler: requireRole(db, auth, 'viewer') }, async (req) => {
        const tenantId = req.access!.tenant.id;
        return db
          .select()
          .from(agents)
          .where(eq(agents.tenantId, tenantId))
          .orderBy(asc(agents.name));
      });

      scoped.get('/tickets', { preHandler: requireRole(db, auth, 'viewer') }, async (req) => {
        const tenantId = req.access!.tenant.id;
        const { status } = z.object({ status: ticketStatusSchema.optional() }).parse(req.query);
        return db
          .select()
          .from(tickets)
          .where(
            and(eq(tickets.tenantId, tenantId), status ? eq(tickets.status, status) : undefined),
          )
          .orderBy(desc(tickets.createdAt));
      });

      scoped.get('/approvals', { preHandler: requireRole(db, auth, 'viewer') }, async (req) => {
        const tenantId = req.access!.tenant.id;
        const { status } = z
          .object({ status: approvalStatusSchema.default('pending') })
          .parse(req.query);
        return db
          .select()
          .from(approvals)
          .where(and(eq(approvals.tenantId, tenantId), eq(approvals.status, status)))
          .orderBy(desc(approvals.createdAt));
      });

      scoped.get('/members', { preHandler: requireRole(db, auth, 'admin') }, async (req) => {
        const tenantId = req.access!.tenant.id;
        return db
          .select({
            userId: users.id,
            name: users.name,
            email: users.email,
            role: memberships.role,
          })
          .from(memberships)
          .innerJoin(users, eq(users.id, memberships.userId))
          .where(eq(memberships.tenantId, tenantId))
          .orderBy(asc(users.name));
      });
    },
    { prefix: '/api/tenants/:tenant' },
  );

  // --- WebSocket de eventos do escritório ------------------------------------
  app.get('/ws', { websocket: true }, async (socket, req) => {
    const query = wsQuery.safeParse(req.query);
    if (!query.success) return socket.close(4400, 'Parâmetro tenant obrigatório');

    const headers = toFetchHeaders(req);
    // Navegador e WebView não enviam headers no WebSocket: o app Android manda o token na query.
    if (query.data.token) headers.set('authorization', `Bearer ${query.data.token}`);

    const access = await resolveAccess(db, auth, query.data.tenant, headers);
    if ('error' in access) return socket.close(4000 + access.error, 'Acesso negado');

    const unsubscribe = hub.subscribe(
      access.tenant.id,
      (event) => socket.send(JSON.stringify(event)),
      { mock: access.tenant.isDemo },
    );
    socket.on('close', unsubscribe);

    // Estado inicial: todos os agentes ociosos em suas mesas.
    const roster = await db
      .select({ key: agents.key })
      .from(agents)
      .where(eq(agents.tenantId, access.tenant.id));
    for (const { key } of roster) {
      socket.send(
        JSON.stringify({
          ts: new Date().toISOString(),
          tenantId: access.tenant.id,
          agentId: key,
          type: 'agent.idle',
          payload: {},
        }),
      );
    }
  });

  app.setErrorHandler((error, _req, reply) => {
    if (error instanceof z.ZodError)
      return reply.code(400).send({ error: 'Requisição inválida', issues: error.issues });
    app.log.error(error);
    const status = (error as { statusCode?: number }).statusCode ?? 500;
    return reply
      .code(status)
      .send({ error: status === 500 ? 'Erro interno' : (error as Error).message });
  });

  return app;
}
