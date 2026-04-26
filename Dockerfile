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
ARG GITHUB_TOKEN
ARG SERVER_ID=showdown
ARG SERVER_HOST=sim3.psim.us
ARG SERVER_PORT=443
ARG SERVER_HTTPPORT=8000
ARG SERVER_ALTPORT=80
ARG SERVER_REGISTERED=true
ARG TESTCLIENT_KEY

# build-tools/build-indexes expects GITHUB_TOKEN in process.env
ENV GITHUB_TOKEN=${GITHUB_TOKEN}

# Bring in the rest of the source
COPY . .

# Full build: indexes, learnsets, minidex, then TS/Babel compile + asset hashing
# The `update` step inside will append Config.routes/version to config/config.js.
RUN node build full

# Generate browser config + optional testclient key AFTER build full so they are
# guaranteed to be present in the final image artifacts.
RUN SERVER_ID=$SERVER_ID \
    SERVER_HOST=$SERVER_HOST \
    SERVER_PORT=$SERVER_PORT \
    SERVER_HTTPPORT=$SERVER_HTTPPORT \
    SERVER_ALTPORT=$SERVER_ALTPORT \
    SERVER_REGISTERED=$SERVER_REGISTERED \
    TESTCLIENT_KEY=$TESTCLIENT_KEY \
    node build-tools/generate-config.js

# ---------- Runtime stage ----------
FROM nginx:1.27-alpine

# Static doc root: the play subdomain, with testclient.html as index
COPY --from=builder /app/play.pokemonshowdown.com/ /usr/share/nginx/html/

# testclient key is generated into /config/testclient-key.js when TESTCLIENT_KEY
# is provided as a build arg.

COPY nginx/default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q --spider http://127.0.0.1/testclient.html || exit 1
