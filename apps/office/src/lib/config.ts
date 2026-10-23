/** URL da API. No APK aponta para o servidor de produção (definida no build). */
export const API_URL = (process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:4000').replace(
  /\/$/,
  '',
);

export function wsUrl(tenant: string, token?: string): string {
  const url = new URL('/ws', API_URL.replace(/^http/, 'ws'));
  url.searchParams.set('tenant', tenant);
  if (token) url.searchParams.set('token', token);
  return url.toString();
}
