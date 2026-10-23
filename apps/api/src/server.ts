import { createDb, DEMO_TENANT_SLUG, eq, runMigrations, seedDemo, tenants } from '@nexus/db';
import { createAuth } from './auth.js';
import { buildApp } from './app.js';
import { loadEnv } from './env.js';

const env = loadEnv();
await runMigrations(env.DATABASE_URL);
const { db, sql } = createDb(env.DATABASE_URL);
if (env.SEED_DEMO) {
  const [demo] = await db
    .select({ id: tenants.id })
    .from(tenants)
    .where(eq(tenants.slug, DEMO_TENANT_SLUG));
  if (!demo) await seedDemo(db);
}
const app = await buildApp({ db, auth: createAuth(db, env), env });

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.on(signal, async () => {
    await app.close();
    await sql.end();
    process.exit(0);
  });
}

await app.listen({ port: env.PORT, host: env.HOST });
