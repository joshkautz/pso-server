# Dashboard container.
# - Node 22 alpine for a small image (~50 MB).
# - Serves static files (index.html, etc.) AND proxies a strict whitelist
#   of safe newserv REST endpoints. No extra reverse proxy in front.
# - Listens on port 8080 inside the container; mapped to host port 80 in
#   docker-compose.

FROM node:22-alpine

WORKDIR /app

# Install only production deps. The dashboard backend is tiny — express
# + http-proxy + that's it.
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
