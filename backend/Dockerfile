# syntax=docker/dockerfile:1

# ---- Étape 1 : dépendances de production uniquement ----
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# ---- Étape 2 : image finale minimale, utilisateur non-root ----
FROM node:22-alpine AS runtime
ARG APP_VERSION=dev
ENV NODE_ENV=production \
    PORT=3000 \
    APP_VERSION=${APP_VERSION}
WORKDIR /app

COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node package.json ./
COPY --chown=node:node src ./src

USER node
EXPOSE 3000

HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

CMD ["node", "src/server.js"]
