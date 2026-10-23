# Prompt para colar no Claude Code (primeira sessão)

Abra o repositório no VS Code, inicie o Claude Code e cole:

---

Leia o CLAUDE.md, docs/ARCHITECTURE.md, docs/ROADMAP.md e docs/INFRA.md por completo.

Depois execute a **Fase 1 — Fundação** do roadmap, do início ao fim:

1. Monorepo pnpm + Turborepo com `apps/office`, `apps/api`, `packages/shared`,
   `packages/db`, `packages/agents`, `packages/connectors`.
2. TypeScript estrito, ESLint, Prettier, Vitest configurados em todos os pacotes.
3. `docker-compose.yml` com Postgres 16 (pgvector), Redis 7, api e office, mais
   `docker-compose.prod.yml` com Caddy e HTTPS.
4. Schema Drizzle: tenants, users, memberships, agents, tickets, ticket_messages,
   approvals, agent_runs, agent_steps, connector_credentials (criptografadas), token_budgets.
5. Seed do tenant `demo` com 7 agentes do CLAUDE.md e 30 chamados fictícios variados.
6. Auth com Better Auth e RBAC (owner, admin, viewer).
7. Endpoint WebSocket que emite `OfficeEvent` mockados para o tenant demo a cada poucos segundos.
8. README com como rodar local.

Ao terminar: rode os testes, suba o compose, confirme que tudo responde, faça commit
e marque a fase como concluída no ROADMAP. Se algo do CLAUDE.md estiver ambíguo,
pergunte antes de decidir.

---

## Prompts das fases seguintes

Use um por sessão, sempre começando com "Leia o CLAUDE.md e o ROADMAP.md":

- **Fase 2**: "Execute a Fase 2 — Escritório 3D v1. Priorize arquitetura da cena
  (layout JSON, sistema de estados → animações, navmesh) sobre beleza; assets são placeholder."
- **Fase 3**: "Execute a Fase 3 — Orquestrador, com Claude Agent SDK, Gestor + Triagem + Suporte N1."
- **Fase 4**: "Execute a Fase 4 — Aprovações e conectores, começando pelo simulador de chamados do demo."
- **Fase 5**: "Execute a Fase 5 — Dev + QA com sandbox em container."
- **Fase 6**: "Execute a Fase 6 — Escritório 3D v2. Meta: qualidade de vídeo publicitário.
  Siga a seção 7 do CLAUDE.md à risca e use o modo cinematográfico para gerar um vídeo 9:16 de teste."
- **Fase 7 e 8**: idem, conforme ROADMAP.
