import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().default(4000),
  HOST: z.string().default('0.0.0.0'),
  DATABASE_URL: z.string().min(1),
  REDIS_URL: z.string().default('redis://localhost:6379'),
  AUTH_SECRET: z.string().min(32, 'AUTH_SECRET precisa de pelo menos 32 caracteres'),
  API_URL: z.string().url().default('http://localhost:4000'),
  PUBLIC_URL: z.string().url().default('http://localhost:3000'),
  /** Origens extras aceitas (CORS + auth), separadas por vírgula. Inclui o app Android (Capacitor). */
  TRUSTED_ORIGINS: z.string().default('capacitor://localhost,https://localhost,http://localhost'),
  /** Cria o tenant demo no boot se ele ainda não existir. */
  SEED_DEMO: z.stringbool().default(false),
  MOCK_EVENT_INTERVAL_MS: z.coerce.number().int().positive().default(3000),
  GOOGLE_CLIENT_ID: z.string().optional(),
  GOOGLE_CLIENT_SECRET: z.string().optional(),
  MICROSOFT_CLIENT_ID: z.string().optional(),
  MICROSOFT_CLIENT_SECRET: z.string().optional(),
});

export type Env = z.infer<typeof envSchema>;

export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  return envSchema.parse(source);
}

export function trustedOrigins(env: Env): string[] {
  const extra = env.TRUSTED_ORIGINS.split(',')
    .map((o) => o.trim())
    .filter(Boolean);
  return [...new Set([env.PUBLIC_URL, ...extra])];
}
