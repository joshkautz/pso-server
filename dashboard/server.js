// Dashboard backend.
//
// Does two jobs:
//   1. Serves static dashboard files (index.html).
//   2. Proxies a strict allowlist of newserv REST endpoints under /api/*.
//
// Security model: newserv's REST API is bound to the docker-internal
// network only (see server/config.json HTTPListen). The internet can
// only reach this container, and this container only forwards GET
// requests to a hardcoded set of safe endpoints. The dangerous bits
// (POST /y/shell-exec, GET /y/accounts) are not forwardable from here.

import express from 'express';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const app = express();

// =========================================================================
// Configuration
// =========================================================================

const PORT = parseInt(process.env.PORT ?? '8080', 10);
const NEWSERV_API =
  process.env.NEWSERV_API ?? 'http://newserv:8081';
const REQUEST_TIMEOUT_MS = parseInt(process.env.REQUEST_TIMEOUT_MS ?? '5000', 10);
const CACHE_TTL_MS = parseInt(process.env.CACHE_TTL_MS ?? '10000', 10);

// =========================================================================
// Safe-endpoint allowlist
//
// Adding new entries is a deliberate act — never proxy newserv routes
// that return PII or accept side-effectful POSTs without considering
// what gets surfaced publicly.
// =========================================================================

const ALLOWLIST = new Map([
  ['summary',  { path: '/y/summary',      strip: stripSensitive }],
  ['lobbies',  { path: '/y/lobbies',      strip: stripPlayerIdentities }],
  ['server',   { path: '/y/server',       strip: passthrough }],
  ['quests',   { path: '/y/data/quests',  strip: passthrough }],
]);

// =========================================================================
// Sanitisers
//
// Each allowlisted endpoint passes through one of these so we never
// leak fields newserv exposes that a public dashboard shouldn't.
// =========================================================================

function passthrough(data) { return data; }

function stripSensitive(data) {
  // newserv's /y/summary returns top-level counts plus per-client info.
  // Keep counts, drop per-client identifiers (player names are OK if
  // you want a "now playing" list; account IDs, IPs, and session
  // tokens are not).
  if (data && typeof data === 'object') {
    const clean = { ...data };
    for (const k of ['accounts', 'clients', 'proxy_clients']) {
      if (Array.isArray(clean[k])) {
        clean[k] = clean[k].map((c) => ({
          name: c.name,
          version: c.version,
          // intentionally drop: account_id, session_id, remote_address
        }));
      }
    }
    return clean;
  }
  return data;
}

function stripPlayerIdentities(data) {
  // /y/lobbies returns games + lobby occupancy. Player names are fine
  // to show; remote addresses are not.
  if (Array.isArray(data)) {
    return data.map((lobby) => ({
      ...lobby,
      players: Array.isArray(lobby.players)
        ? lobby.players.map((p) => ({ name: p.name, version: p.version }))
        : lobby.players,
    }));
  }
  return data;
}

// =========================================================================
// Small TTL cache to avoid hammering newserv on every dashboard refresh
// =========================================================================

const cache = new Map();

async function fetchCached(key, url) {
  const now = Date.now();
  const cached = cache.get(key);
  if (cached && now - cached.at < CACHE_TTL_MS) {
    return cached.data;
  }

  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), REQUEST_TIMEOUT_MS);
  try {
    const res = await fetch(url, { signal: ctrl.signal });
    if (!res.ok) {
      throw new Error(`upstream ${res.status}`);
    }
    const data = await res.json();
    cache.set(key, { at: now, data });
    return data;
  } finally {
    clearTimeout(timer);
  }
}

// =========================================================================
// Routes
// =========================================================================

app.get('/api/:resource', async (req, res) => {
  const route = ALLOWLIST.get(req.params.resource);
  if (!route) {
    return res.status(404).json({ error: 'unknown resource' });
  }
  try {
    const data = await fetchCached(req.params.resource, NEWSERV_API + route.path);
    res.json(route.strip(data));
  } catch (err) {
    console.error(`[api/${req.params.resource}] ${err.message}`);
    res.status(502).json({ error: 'upstream unavailable', resource: req.params.resource });
  }
});

// Simple healthcheck for docker / load-balancer probes.
app.get('/healthz', (_req, res) => res.json({ ok: true }));

// Static dashboard. Serves index.html for the root, plus any sibling
// assets you add later (favicon, images, etc.).
app.use(express.static(__dirname, { extensions: ['html'] }));

// =========================================================================
// Start
// =========================================================================

app.listen(PORT, () => {
  console.log(`[dashboard] listening on :${PORT}`);
  console.log(`[dashboard] proxying ${ALLOWLIST.size} routes to ${NEWSERV_API}`);
});
