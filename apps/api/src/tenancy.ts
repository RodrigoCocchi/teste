import type { FastifyReply, FastifyRequest } from 'fastify';
import { and, eq, memberships, tenants, type Database } from '@nexus/db';
import { hasRole, type Role } from '@nexus/shared';
import type { Auth } from './auth.js';
import { toFetchHeaders } from './http.js';

export interface TenantAccess {
  tenant: typeof tenants.$inferSelect;
  userId: string | null;
  role: Role;
}

declare module 'fastify' {
  interface FastifyRequest {
    access?: TenantAccess;
  }
}

/**
 * Resolve o tenant e o papel do usuário. O tenant demo é público em modo leitura
 * (viewer) para gravação de vídeos; qualquer outro tenant exige sessão + membership.
 */
export async function resolveAccess(
  db: Database,
  auth: Auth,
  slug: string,
  headers: Headers,
): Promise<TenantAccess | { error: 401 | 403 | 404 }> {
  const [tenant] = await db.select().from(tenants).where(eq(tenants.slug, slug)).limit(1);
  if (!tenant) return { error: 404 };

  const session = await auth.api.getSession({ headers });
  const userId = session?.user.id ?? null;

  if (userId) {
    const [membership] = await db
      .select({ role: memberships.role })
      .from(memberships)
      .where(and(eq(memberships.tenantId, tenant.id), eq(memberships.userId, userId)))
      .limit(1);
    if (membership) return { tenant, userId, role: membership.role };
  }

  if (tenant.isDemo) return { tenant, userId, role: 'viewer' };
  return { error: userId ? 403 : 401 };
}

/** preHandler que exige papel mínimo no tenant de `:tenant` e popula `req.access`. */
export function requireRole(db: Database, auth: Auth, required: Role) {
  return async (req: FastifyRequest, reply: FastifyReply) => {
    const { tenant: slug } = req.params as { tenant: string };
    const result = await resolveAccess(db, auth, slug, toFetchHeaders(req));
    if ('error' in result)
      return reply.code(result.error).send({ error: errorMessage(result.error) });
    if (!hasRole(result.role, required)) return reply.code(403).send({ error: errorMessage(403) });
    req.access = result;
  };
}

function errorMessage(code: 401 | 403 | 404): string {
  return {
    401: 'Não autenticado',
    403: 'Sem permissão neste tenant',
    404: 'Tenant não encontrado',
  }[code];
}
