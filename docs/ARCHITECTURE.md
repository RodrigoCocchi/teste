# Arquitetura

```
 Navegador (GPU do usuário renderiza o 3D)
 ┌───────────────────────────────────────────┐
 │ apps/office (Next.js + React Three Fiber) │
 │  cena 3D ◄── estados ◄── WebSocket        │
 │  painéis: aprovações, chamados, métricas  │
 └───────────────▲───────────────────────────┘
                 │ HTTPS / WSS
 Servidor        │
 ┌───────────────┴───────────────────────────┐
 │ Caddy (TLS)                               │
 │ apps/api (Fastify)                        │
 │  REST · WebSocket · Auth · Aprovações     │
 │        │ enfileira                        │
 │  Redis/BullMQ ──► Workers de agentes      │
 │                    │ Claude Agent SDK      │──► API Anthropic / OpenAI
 │                    │ ferramentas           │──► TomTicket, M365, GitHub...
 │                    │ sandbox (containers)  │
 │  PostgreSQL + pgvector                    │
 └───────────────────────────────────────────┘
```

## Fluxo de um chamado

1. Chamado chega (conector, e-mail, webhook ou simulador do demo) → `ticket.created`.
2. **Triagem** classifica, busca na base de conhecimento, define prioridade e responsável.
3. **Gestor** delega para **Suporte N1** (ou Infra/Dev).
4. Agente monta a resposta ou ação → `approval.requested` (se a ação exigir).
5. Humano aprova no painel → agente executa → `ticket.resolved`.
6. **Documentação** gera artigo na base de conhecimento a partir da solução.

Cada passo emite `OfficeEvent` e o avatar correspondente se move/anima.

## Decisões-chave

- **3D renderizado no cliente**: o servidor não precisa de GPU. Isso barateia muito a infra.
- **Workers separados da API**: agentes demorados não travam a interface.
- **Sandbox por execução**: código e comandos dos agentes Dev/Infra rodam em containers
  descartáveis, sem acesso à rede interna por padrão.
- **Roteador de modelo**: tarefa simples → modelo rápido/barato; diagnóstico e código → modelo forte.
