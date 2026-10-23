# Roadmap

Marque `[x]` ao concluir. Cada fase termina com testes passando e commit.

## Fase 1 — Fundação
- [ ] Monorepo pnpm + Turborepo, TS estrito, lint, testes
- [ ] Docker Compose (Postgres+pgvector, Redis, api, office) + prod com Caddy
- [ ] Schema do banco e migrations
- [ ] Auth + RBAC
- [ ] Seed do tenant demo (7 agentes, 30 chamados fictícios)
- [ ] WebSocket com eventos mockados

## Fase 2 — Escritório 3D v1
- [ ] Cena com layout em JSON
- [ ] Avatares placeholder com máquina de estados de animação
- [ ] Navmesh e caminhada entre mesas
- [ ] Câmera órbita / seguir agente
- [ ] Painéis 2D básicos

## Fase 3 — Orquestrador
- [ ] Claude Agent SDK integrado
- [ ] Agentes Gestor, Triagem, Suporte N1
- [ ] Filas BullMQ e workers
- [ ] Registro de runs/steps e custo
- [ ] Roteador de modelo + orçamento de tokens

## Fase 4 — Aprovações e conectores
- [ ] Fila de aprovação ponta a ponta
- [ ] Simulador de chamados (demo)
- [ ] Conector e-mail/webhook genérico
- [ ] Conector TomTicket

## Fase 5 — Dev + QA
- [ ] Sandbox em container
- [ ] GitHub App, PR automático
- [ ] QA revisando PR e rodando testes

## Fase 6 — Escritório 3D v2 (qualidade final)
- [ ] Assets definitivos (Draco/KTX2)
- [ ] Iluminação assada + HDRI + sombras suaves
- [ ] Pós-processamento (AO, bloom, tone mapping, DoF cinematográfico)
- [ ] Telas vivas nos monitores
- [ ] Modo cinematográfico + gravação 9:16 e 16:9

## Fase 7 — Infra + Documentação
- [ ] Agente Infra com monitoramento
- [ ] Agente Documentação + base de conhecimento (pgvector)

## Fase 8 — SaaS
- [ ] Onboarding de tenant
- [ ] Planos e billing
- [ ] Landing page
