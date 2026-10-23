/**
 * URL da API. Sem ela o escritório roda em **modo demo local**: a simulação dos agentes
 * acontece no próprio navegador/celular (útil para o APK de demonstração e para gravar vídeos).
 */
export const API_URL = process.env.NEXT_PUBLIC_API_URL?.replace(/\/$/, '') || null;

export const TENANT = 'demo';

export function wsUrl(apiUrl: string, tenant: string, token?: string): string {
  const url = new URL('/ws', apiUrl.replace(/^http/, 'ws'));
  url.searchParams.set('tenant', tenant);
  if (token) url.searchParams.set('token', token);
  return url.toString();
}
