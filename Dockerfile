# syntax=docker/dockerfile:1.7

# ---------- Build stage ----------
FROM node:20-bookworm-slim AS builder

WORKDIR /app

# git is used by build-tools/update for version stamping (wrapped in try/catch,
# so absence is non-fatal, but having it gives nicer cache-busting strings).
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install JS deps first so this layer caches between source-only changes
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

# Bring in the rest of the source
COPY . .

# `node build` auto-creates config/config.js from config-example.js if missing,
# but make it explicit so a misconfigured .dockerignore doesn't silently break.
RUN if [ ! -f config/config.js ]; then cp config/config-example.js config/config.js; fi

# Full build: indexes, learnsets, minidex, then TS/Babel compile + asset hashing
RUN node build full

# ---------- Runtime stage ----------
FROM nginx:1.27-alpine

# Static doc root: the play subdomain, with testclient.html as index
COPY --from=builder /app/play.pokemonshowdown.com/ /usr/share/nginx/html/

# testclient.html references ../config/testclient-key.js (one level above doc
# root). That file is optional (logged-in test sessions only) and intentionally
# 404s in production — no action needed.

COPY nginx/default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q --spider http://127.0.0.1/testclient.html || exit 1
