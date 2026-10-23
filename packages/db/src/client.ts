import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import * as schema from './schema.js';

export type Database = ReturnType<typeof createDb>['db'];

export function createDb(url = process.env.DATABASE_URL) {
  if (!url) throw new Error('DATABASE_URL não definida');
  const sql = postgres(url, { max: 10 });
  return { db: drizzle(sql, { schema }), sql };
}
