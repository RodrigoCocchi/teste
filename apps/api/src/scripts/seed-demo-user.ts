import { createDb, eq, memberships, tenants, users, DEMO_TENANT_SLUG } from '@nexus/db';
import { createAuth } from '../auth.js';
import { loadEnv } from '../env.js';

/** Cria (ou reaproveita) o usuário dono do tenant demo. Rode depois de `pnpm db:seed`. */
const env = loadEnv();
const email = process.env.DEMO_USER_EMAIL ?? 'demo@vertice.demo';
const password = process.env.DEMO_USER_PASSWORD;
if (!password) throw new Error('Defina DEMO_USER_PASSWORD (mínimo 10 caracteres)');

const { db, sql } = createDb(env.DATABASE_URL);
try {
  const auth = createAuth(db, env);
  let [user] = await db.select({ id: users.id }).from(users).where(eq(users.email, email));
  if (!user) {
    const res = await auth.api.signUpEmail({ body: { email, password, name: 'Dono do Demo' } });
    user = { id: res.user.id };
  }
  const [tenant] = await db
    .select({ id: tenants.id })
    .from(tenants)
    .where(eq(tenants.slug, DEMO_TENANT_SLUG));
  if (!tenant) throw new Error('Tenant demo não existe: rode `pnpm db:seed` antes');
  await db
    .insert(memberships)
    .values({ tenantId: tenant.id, userId: user.id, role: 'owner' })
    .onConflictDoUpdate({
      target: [memberships.tenantId, memberships.userId],
      set: { role: 'owner' },
    });
  console.log(`Usuário ${email} é owner do tenant demo.`);
} finally {
  await sql.end();
}
