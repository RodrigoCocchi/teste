# syntax=docker/dockerfile:1.7
FROM node:22-alpine AS base
RUN corepack enable
WORKDIR /repo

FROM base AS build
COPY . .
RUN --mount=type=cache,id=pnpm,target=/root/.local/share/pnpm/store pnpm install --frozen-lockfile
ARG NEXT_PUBLIC_API_URL=http://localhost:4000
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
RUN pnpm build
RUN pnpm --filter @nexus/api deploy --prod --legacy /out/api

# --- API (Fastify + WebSocket) ---------------------------------------------
FROM node:22-alpine AS api
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build /out/api .
USER node
EXPOSE 4000
CMD ["node", "dist/server.js"]

# --- Escritório (export estático servido pelo Caddy) -------------------------
FROM caddy:2-alpine AS office
COPY infra/Caddyfile.office /etc/caddy/Caddyfile
COPY --from=build /repo/apps/office/out /srv
EXPOSE 3000
