# CLAUDE.md — Prompt-mestre do projeto Nexus TI

> Este arquivo é lido automaticamente pelo Claude Code em toda sessão neste repositório.
> Ele define o produto, a arquitetura, as regras e a ordem de construção.
> "Nexus TI" é nome provisório — troque à vontade.

## 1. O produto

Uma plataforma SaaS de **time de TI operado por agentes de IA**, visualizado como um
**escritório 3D de altíssima qualidade** no navegador. Cada agente é um "funcionário"
com mesa, avatar animado e status em tempo real. O que o boneco faz na tela reflete
o que o agente está fazendo de verdade (lendo chamado, codando, aguardando aprovação).

Dois objetivos ao mesmo tempo:

1. **Ferramenta real**: atender, responder e resolver chamados, desenvolver, documentar.
2. **Vitrine**: visual cinematográfico para gravar conteúdo diário (Instagram/LinkedIn)
   e vender o produto para PMEs.

## 2. Princípios inegociáveis

- **Humano no controle**: toda ação que altera algo fora da plataforma (responder cliente,
  criar usuário, rodar comando, abrir PR, fechar chamado) passa por **fila de aprovação**,
  a menos que o tenant libere explicitamente aquela ação como automática.
- **Multi-tenant desde o dia 1**: todo dado tem `tenant_id`. Nenhuma query sem filtro de tenant.
- **Modo Demo com dados fictícios**: um tenant `demo` com chamados, usuários e repositórios
  falsos, para gravar vídeos sem expor dado real de nenhum cliente ou empregador.
- **Segredos nunca no código**: tudo via `.env` / cofre. Credenciais de conectores
  criptografadas no banco (AES-256-GCM, chave fora do banco).
- **Auditoria total**: todo passo de agente (prompt, ferramenta chamada, resultado, custo
  em tokens) gravado em `agent_runs` / `agent_steps`.
- **Custo controlado**: orçamento de tokens por tenant e por agente; roteamento de modelo
  (modelo barato para triagem, modelo forte para dev/diagnóstico); cache de prompt.
- **Visual é cosmético, lógica é real**: o front 3D só consome eventos. Nunca colocar
  regra de negócio no front.
- **Web responsiva + APK Android sempre**: toda tela nasce mobile-first e funciona de
  360 px a 4K; o mesmo código vira APK via Capacitor. Nenhuma feature entra só na web.
- **Mídia em altíssima qualidade**: imagens, texturas e vídeos nunca são degradados para
  "caber" — usa-se compressão moderna e variantes por dispositivo (ver §7.1 e docs/MOBILE.md).

## 3. Stack

Monorepo **pnpm + Turborepo**, TypeScript estrito em tudo.

| Camada             | Tecnologia                                                                                                                                 |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Escritório 3D      | Next.js 15 (App Router, export estático), React Three Fiber, @react-three/drei, @react-three/postprocessing, Zustand                       |
| App Android        | Capacitor 8 empacotando o export estático do `apps/office` (APK gerado no GitHub Actions)                                                  |
| Assets 3D          | GLB/GLTF comprimidos (Draco + KTX2 via gltf-transform), personagens rigados com animações (idle, digitando, andando, falando, comemorando) |
| UI 2D              | Tailwind + shadcn/ui, painéis em glassmorphism sobre a cena                                                                                |
| API / Orquestrador | Node 22 + Fastify, WebSocket (eventos em tempo real)                                                                                       |
| Agentes            | Claude Agent SDK (Anthropic) com ferramentas próprias; OpenAI opcional via camada de roteamento                                            |
| Filas              | BullMQ + Redis                                                                                                                             |
| Banco              | PostgreSQL 16 + Drizzle ORM; pgvector para base de conhecimento                                                                            |
| Auth               | Better Auth (e-mail + Google/Microsoft), RBAC por tenant                                                                                   |
| Infra              | Docker Compose (dev e produção MVP), Caddy como proxy reverso com HTTPS                                                                    |
| Observabilidade    | Pino (logs), OpenTelemetry, painel interno de custos                                                                                       |

## 4. Estrutura do repositório

```
apps/
  office/        # Next.js — escritório 3D + painéis (web) e projeto Android (Capacitor) em office/android
  api/           # Fastify — REST + WebSocket + workers
packages/
  agents/        # definição dos agentes, ferramentas, prompts, roteador de modelo
  shared/        # tipos, schemas Zod, contratos de eventos
  connectors/    # TomTicket, GLPI, M365/Graph, Gmail, GitHub, Zabbix...
  db/            # schema Drizzle, migrations, seeds (incl. tenant demo)
assets/          # modelos 3D, texturas, HDRIs (Git LFS)
docs/            # arquitetura, roadmap, infra
```

## 5. Os agentes (MVP)

Cada agente = `{ id, nome, papel, avatar, modelo, ferramentas[], permissões[], mesa }`.

| Agente           | Sala               | Faz                                                                                              | Ferramentas                                          |
| ---------------- | ------------------ | ------------------------------------------------------------------------------------------------ | ---------------------------------------------------- |
| **Gestor**       | Sala do gestor     | Recebe demanda, decompõe, delega, cobra prazo, faz o standup diário                              | delegar, consultar status, relatório                 |
| **Triagem**      | Recepção           | Lê chamado novo, classifica (categoria, prioridade, SLA), busca duplicados, encaminha            | conector de chamados, base de conhecimento           |
| **Suporte N1**   | Ilha de suporte    | Responde usuário, guia passo a passo, executa ações padrão (reset de senha, desbloqueio, acesso) | conector de chamados, AD/Entra ID, e-mail            |
| **Infra**        | Sala de servidores | Monitora alertas, diagnostica, propõe correção                                                   | Zabbix/Prometheus, SSH em sandbox, scripts aprovados |
| **Dev**          | Ilha de dev        | Implementa correções e features em repositórios, abre PR                                         | GitHub, sandbox de código (container)                |
| **QA**           | Ilha de dev        | Revisa PR, roda testes, aponta problemas                                                         | GitHub, runner de testes                             |
| **Documentação** | Biblioteca         | Transforma chamados resolvidos em artigos da base de conhecimento                                | base de conhecimento (pgvector)                      |

Regras:

- Agentes conversam entre si por **mensagens registradas** (visíveis no front como balões).
- Todo agente tem `max_steps`, `max_tokens` e timeout.
- Prompts de sistema ficam em `packages/agents/prompts/*.md`, versionados.

## 6. Contrato de eventos (API → Escritório 3D)

WebSocket em `/ws?tenant=...`. Todo evento segue:

```ts
type OfficeEvent = {
  ts: string;
  tenantId: string;
  agentId: string;
  type:
    | 'agent.idle'
    | 'agent.thinking'
    | 'agent.working'
    | 'agent.walking'
    | 'agent.talking'
    | 'agent.waiting_approval'
    | 'agent.done'
    | 'agent.error'
    | 'ticket.created'
    | 'ticket.updated'
    | 'ticket.resolved'
    | 'approval.requested'
    | 'approval.granted'
    | 'approval.denied'
    | 'standup.started'
    | 'standup.ended';
  payload: Record<string, unknown>;
};
```

O front mapeia cada `type` para animação + posição:

- `working` → senta na mesa, animação de digitar, monitor acende com o conteúdo
- `walking` → caminha (pathfinding em navmesh) até a mesa de outro agente
- `talking` → balão com o texto resumido
- `waiting_approval` → ícone pulsante acima da cabeça + card no painel lateral
- `standup.started` → todos vão para a mesa de reunião

## 7. Escritório 3D — padrão de qualidade

Meta: nível de vídeo publicitário, não de protótipo.

- **Iluminação**: HDRI de ambiente + luz direcional com sombras suaves (PCSS ou
  ContactShadows), iluminação "assada" (lightmaps) nas paredes e móveis estáticos.
- **Pós-processamento**: SSAO/N8AO, Bloom sutil em telas e LEDs, Tone mapping ACES,
  Depth of Field apenas no modo cinematográfico, SMAA.
- **Materiais**: PBR (roughness/metalness/normal), vidro com transmissão nas salas.
- **Personagens**: avatares estilizados de alta qualidade, rigados, com blend entre
  animações (useAnimations + crossfade). Cada agente com visual único e crachá.
- **Telas vivas**: monitores renderizam texto real do que o agente faz (render target).
- **Câmeras**: órbita livre; "seguir agente"; **modo cinematográfico** com trilhos de
  câmera pré-definidos para gravar vídeos 9:16 e 16:9.
- **Performance**: instancing, LOD, assets Draco/KTX2, `PerformanceMonitor` do drei
  para degradar qualidade automaticamente. Meta: 60 fps em GPU média, 30 fps em notebook.
- **Layout editável**: salas e mesas definidas em JSON (`office-layout.json`), com
  modo editor para arrastar móveis.

### 7.1 Multiplataforma e qualidade de mídia

- **Responsivo**: mobile-first com Tailwind; áreas seguras (`env(safe-area-inset-*)`);
  `100dvh`; alvos de toque ≥ 44 px; sem rolagem horizontal de 360 px a 4K.
- **APK**: `apps/office` é exportado estático (`output: 'export'`) e empacotado pelo
  Capacitor. Nada de SSR/route handlers no office — toda lógica fica na API.
  Auth no app via token bearer (header `Authorization` / `?token=` no WebSocket).
- **Imagens**: masters em PNG/EXR sem perda em `assets/` (Git LFS); entregues como AVIF +
  WebP em 1x/2x/3x via `srcset`. Nunca servir JPEG recomprimido de baixa qualidade.
- **Texturas 3D**: KTX2 (UASTC para normal maps e telas, ETC1S só em texturas difusas
  secundárias), mipmaps, anisotropia máxima suportada.
- **Vídeo**: gravação do modo cinematográfico em 4K 60 fps (16:9) e 2160×3840 (9:16);
  entrega em AV1 + H.264 (fallback) com bitrate alto; `playsInline` e poster em AVIF.
- **Celular**: `dpr` limitado a `[1, 2]` e qualidade adaptativa via `PerformanceMonitor`
  (reduz sombras/pós antes de reduzir resolução de textura). WebView com aceleração de hardware.

## 8. Painéis 2D (sobre a cena)

- Fila de aprovações (aprovar / editar / reprovar com um clique)
- Chamados (kanban por status, SLA visível)
- Feed de atividade dos agentes
- Clique em um agente → ficha com o que está fazendo, histórico, custo do dia
- Métricas: chamados resolvidos, tempo médio, % resolvido sem humano, custo por chamado
  (esses números são o conteúdo dos posts)

## 9. Ordem de construção

Construa nesta ordem. Ao final de cada fase: testes passando, `docker compose up` funcional,
commit, e atualize `docs/ROADMAP.md` marcando o que foi feito.

1. **Fundação**: monorepo, lint/format, Docker Compose (Postgres, Redis, API, Office),
   schema do banco com tenants/usuários/agentes/chamados/aprovações/runs, auth, seed do tenant demo.
2. **Escritório 3D v1**: cena com layout JSON, avatares placeholder, câmera, consumo de
   eventos mockados via WebSocket, animações por estado.
3. **Orquestrador**: Claude Agent SDK, agentes Gestor + Triagem + Suporte N1, filas BullMQ,
   gravação de runs/steps, roteador de modelo, orçamento de tokens.
4. **Aprovações + conectores**: fila de aprovação ponta a ponta; conector de chamados
   (começar por um genérico via e-mail/webhook + TomTicket); simulador de chamados no demo.
5. **Dev + QA**: sandbox em container, GitHub App, PR automático com revisão do QA.
6. **Escritório 3D v2 (qualidade final)**: assets definitivos, iluminação assada,
   pós-processamento, telas vivas, modo cinematográfico, gravação de vídeo.
7. **Infra + Documentação**: agentes restantes, base de conhecimento com pgvector.
8. **SaaS**: onboarding de tenant, planos, billing (Stripe/Asaas), landing page.

## 10. Convenções

- Código e identificadores em inglês; textos de interface e prompts dos agentes em português (pt-BR).
- Commits no padrão Conventional Commits.
- Validação de toda entrada com Zod.
- Nada de `any`. Testes com Vitest; E2E do escritório com Playwright.
- Antes de qualquer decisão estrutural fora deste documento, pergunte.
- Nunca use dados reais de clientes ou do empregador do autor em seeds, testes ou demos.
