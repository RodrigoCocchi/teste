import { betterAuth } from 'better-auth';
import { drizzleAdapter } from 'better-auth/adapters/drizzle';
import { bearer } from 'better-auth/plugins';
import { schema, type Database } from '@nexus/db';
import { trustedOrigins, type Env } from './env.js';

export function createAuth(db: Database, env: Env) {
  const socialProviders: Parameters<typeof betterAuth>[0]['socialProviders'] = {};
  if (env.GOOGLE_CLIENT_ID && env.GOOGLE_CLIENT_SECRET) {
    socialProviders.google = {
      clientId: env.GOOGLE_CLIENT_ID,
      clientSecret: env.GOOGLE_CLIENT_SECRET,
    };
  }
  if (env.MICROSOFT_CLIENT_ID && env.MICROSOFT_CLIENT_SECRET) {
    socialProviders.microsoft = {
      clientId: env.MICROSOFT_CLIENT_ID,
      clientSecret: env.MICROSOFT_CLIENT_SECRET,
      tenantId: 'common',
    };
  }

  return betterAuth({
    baseURL: env.API_URL,
    basePath: '/api/auth',
    secret: env.AUTH_SECRET,
    database: drizzleAdapter(db, { provider: 'pg', schema, usePlural: true }),
    emailAndPassword: { enabled: true, minPasswordLength: 10 },
    socialProviders,
    trustedOrigins: trustedOrigins(env),
    // bearer: o app Android (Capacitor) autentica por header, sem depender de cookie de terceiros.
    plugins: [bearer()],
  });
}

export type Auth = ReturnType<typeof createAuth>;
