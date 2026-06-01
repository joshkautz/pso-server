# Dashboard container.
# - Node 22 alpine for a small image (~50 MB).
# - Serves static files (index.html) AND proxies a strict allowlist of safe
#   newserv REST endpoints under /api/* (see server.js).
# - Listens on :8080 inside the container; reached by Caddy via the
#   `internal` docker bridge network. No host port is published — Caddy
#   is the only entry point on 80/443 (see ../docker-compose.yml +
#   ../Caddyfile).

FROM node:22-alpine

WORKDIR /app

# Install only production deps. The backend is just express — no proxy
# library; we call fetch() directly against newserv on the internal
# bridge network and run the response through per-route sanitisers.
COPY package.json package-lock.json* ./
RUN npm install --omit=dev

# Static assets and the tiny server.
COPY index.html ./
COPY server.js ./

ENV NODE_ENV=production
ENV PORT=8080

# Run as a non-root user (node:alpine ships with the `node` user).
USER node

EXPOSE 8080

CMD ["node", "server.js"]
