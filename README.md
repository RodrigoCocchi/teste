# Nexus TI

Time de TI operado por agentes de IA, visualizado em um escritório 3D em tempo real.
Roda como **web responsiva** e como **app Android (APK)**.

Agentes que triam, respondem e resolvem chamados, monitoram infraestrutura, desenvolvem
correções e documentam soluções, com aprovação humana em cada ação sensível.

## Rodar local

Requisitos: Node 22, pnpm 10 (`corepack enable`) e Docker.

### Tudo em containers

```bash
docker compose up -d --build
```

- Escritório: http://localhost:3000
- API: http://localhost:4000/health
- O tenant `demo` (7 agentes, 30 chamados fictícios) é criado no primeiro boot.

### Modo desenvolvimento (hot reload)

```bash
cp .env.example .env                      # preencha AUTH_SECRET (openssl rand -base64 48)
docker compose up -d postgres redis
pnpm install
pnpm build                                # compila os pacotes compartilhados
pnpm db:migrate && pnpm db:seed           # schema + tenant demo
pnpm dev                                  # api :4000 e office :3000
```

Usuário dono do demo (opcional): `DEMO_USER_PASSWORD=... pnpm --filter @nexus/api seed:demo-user`.

### Testes e qualidade

```bash
pnpm lint && pnpm typecheck && pnpm test  # com DATABASE_URL definido roda também os testes de integração
pnpm --filter @nexus/office e2e           # E2E do escritório (Playwright, celular + desktop)
```

## App Android (APK)

Cada push gera o APK, testa no emulador Android e publica na release
[`nexus-apk-latest`](https://github.com/RodrigoCocchi/teste/releases/tag/nexus-apk-latest).
Como instalar no celular: [INSTALAR-NEXUS.md](INSTALAR-NEXUS.md). Detalhes: [docs/MOBILE.md](docs/MOBILE.md).

## Modo demo local

Sem `NEXT_PUBLIC_API_URL` definida, o escritório roda **sem servidor**: a simulação dos agentes
acontece no próprio navegador/celular. É o modo do APK de demonstração e o mais prático para gravar vídeos.
Com a variável definida, ele se conecta à API (REST + WebSocket).

```bash
pnpm build && pnpm --filter @nexus/office dev              # demo local em http://localhost:3000
NEXT_PUBLIC_API_URL=http://localhost:4000 pnpm --filter @nexus/office dev   # ligado à API
```

`?q=low` na URL força o modo gráfico leve (celulares fracos).

## Estrutura

```
apps/office       Next.js (export estático) + projeto Android Capacitor
apps/api          Fastify: REST, WebSocket, Better Auth, RBAC
packages/shared   Tipos e schemas Zod (contrato de eventos)
packages/db       Drizzle: schema, migrations, seed do demo
packages/agents   Catálogo dos 7 agentes e prompts
packages/connectors  Contratos de conectores + criptografia de credenciais
```

## Documentos

- [CLAUDE.md](CLAUDE.md) — prompt-mestre do projeto (lido pelo Claude Code)
- [PROMPT-INICIAL.md](PROMPT-INICIAL.md) — prompts de cada fase
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — arquitetura
- [docs/ROADMAP.md](docs/ROADMAP.md) — fases e progresso
- [docs/INFRA.md](docs/INFRA.md) — requisitos de servidor
- [docs/MOBILE.md](docs/MOBILE.md) — app Android e padrão de qualidade de mídia

## Status

Fases 1 (Fundação) e 2 (Escritório 3D v1) concluídas. Próximo passo: Fase 3 — Orquestrador.
