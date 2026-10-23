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
```

## App Android (APK)

O APK é gerado automaticamente pelo GitHub Actions (artefato `nexus-ti-apk` em cada push).
Defina a variável `NEXT_PUBLIC_API_URL` do repositório com a URL pública da API.
Local (precisa do Android Studio): veja [docs/MOBILE.md](docs/MOBILE.md).

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

Fase 1 (Fundação) concluída. Próximo passo: Fase 2 — Escritório 3D v1.
