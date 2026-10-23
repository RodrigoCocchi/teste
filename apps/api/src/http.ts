import type { FastifyRequest } from 'fastify';

/** Converte os headers do Fastify para `Headers` da Fetch API (usado pelo Better Auth). */
export function toFetchHeaders(req: FastifyRequest): Headers {
  const headers = new Headers();
  for (const [key, value] of Object.entries(req.headers)) {
    if (value === undefined) continue;
    headers.set(key, Array.isArray(value) ? value.join(', ') : value);
  }
  return headers;
}
