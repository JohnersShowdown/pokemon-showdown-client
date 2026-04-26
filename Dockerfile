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

# Server config build args — override in Coolify / docker build --build-arg
ARG SERVER_ID=showdown
ARG SERVER_HOST=sim3.psim.us
ARG SERVER_PORT=443
ARG SERVER_HTTPPORT=8000
ARG SERVER_ALTPORT=80
ARG SERVER_REGISTERED=true

# Bring in the rest of the source
COPY . .

# Generate a browser-compatible config/config.js with baked-in server values
# BEFORE the main build, so that the `update` build step can read this file and
# append Config.routes + version to it (it appends, not replaces).
RUN SERVER_ID=$SERVER_ID \
    SERVER_HOST=$SERVER_HOST \
    SERVER_PORT=$SERVER_PORT \
    SERVER_HTTPPORT=$SERVER_HTTPPORT \
    SERVER_ALTPORT=$SERVER_ALTPORT \
    SERVER_REGISTERED=$SERVER_REGISTERED \
    node build-tools/generate-config.js

# Full build: indexes, learnsets, minidex, then TS/Babel compile + asset hashing
# The `update` step inside will append Config.routes/version to config/config.js.
RUN node build full

# ---------- Runtime stage ----------
FROM nginx:1.27-alpine

# Static doc root: the play subdomain, with testclient.html as index
COPY --from=builder /app/play.pokemonshowdown.com/ /usr/share/nginx/html/

# play.pokemonshowdown.com/config/config.js is a symlink in the source tree.
# Explicitly overwrite it with the generated static file so nginx serves real JS.
COPY --from=builder /app/config/config.js /usr/share/nginx/html/config/config.js

# testclient.html references ../config/testclient-key.js (one level above doc
# root). That file is optional (logged-in test sessions only) and intentionally
# 404s in production — no action needed.

COPY nginx/default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q --spider http://127.0.0.1/testclient.html || exit 1
