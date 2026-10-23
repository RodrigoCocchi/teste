import type { NextConfig } from 'next';

const config: NextConfig = {
  // Export estático: o mesmo build serve a web (Caddy) e é empacotado no APK pelo Capacitor.
  output: 'export',
  trailingSlash: true,
  reactStrictMode: true,
  // Sem otimizador em runtime no export estático: as imagens já saem do pipeline de assets
  // em AVIF/WebP de alta resolução com variantes por densidade de tela (ver docs/MOBILE.md).
  images: { unoptimized: true },
  transpilePackages: ['@nexus/shared'],
  // Lint roda separado (pnpm lint) com a config flat da raiz.
  eslint: { ignoreDuringBuilds: true },
};

export default config;
