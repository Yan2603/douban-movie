# Nest API — multi-stage. daocloud mirror for CN servers (aligned with interview).
FROM docker.m.daocloud.io/library/node:22-slim AS builder
WORKDIR /app

COPY apps/server/package.json apps/server/package-lock.json ./
RUN npm ci

COPY apps/server/ ./
RUN npm run build && npm prune --omit=dev

FROM docker.m.daocloud.io/library/node:22-slim
WORKDIR /app
ENV NODE_ENV=production

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./package.json

EXPOSE 3000
CMD ["node", "dist/main.js"]
