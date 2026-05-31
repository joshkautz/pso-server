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

// Commit SHA of the running newserv build. Set by docker-compose from
// the .env file deploy.yml writes after reading the image's OCI label.
// "unknown" when no label is available — the dashboard handles this and
// shows "newserv —" instead of a bogus comparison.
const NEWSERV_REV = process.env.NEWSERV_REV ?? 'unknown';
const NEWSERV_UPSTREAM_REPO = 'fuzziqersoftware/newserv';
const NEWSERV_UPSTREAM_BRANCH = 'master';
// GitHub unauth rate limit is 60/hr per IP. We make at most 2 calls
// per cache miss (commits/master + compare), so 1h TTL keeps us at
// ~2 calls/hr — comfortably under budget even with sporadic restarts.
const BUILD_INFO_TTL_MS = 60 * 60 * 1000;

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

app.get('/api/:resource', async (req, res, next) => {
  // Reserved sub-resources are handled by dedicated routes registered
  // below; defer to Express's router so /api/build hits its dedicated
  // handler instead of falling through the allowlist (which it isn't
  // in — /api/build doesn't proxy newserv, it queries GitHub).
  if (req.params.resource === 'build') return next();
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

// =========================================================================
// /api/build — surfaces the running newserv SHA and how far behind it is
// from fuzziqersoftware/newserv master.
// =========================================================================

let buildInfoCache = null;

async function fetchBuildInfo() {
  const headers = {
    'User-Agent': 'pso-dashboard',
    Accept: 'application/vnd.github+json',
  };

  let upstream = null;
  let behindBy = null;
  let upstreamError = null;

  try {
    const headRes = await fetch(
      `https://api.github.com/repos/${NEWSERV_UPSTREAM_REPO}/commits/${NEWSERV_UPSTREAM_BRANCH}`,
      { headers, signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS) },
    );

    if (!headRes.ok) {
      upstreamError = `github commits api: ${headRes.status}`;
    } else {
      const head = await headRes.json();
      upstream = typeof head?.sha === 'string' ? head.sha : null;

      if (upstream && NEWSERV_REV !== 'unknown') {
        if (NEWSERV_REV === upstream) {
          behindBy = 0;
        } else {
          // base=local, head=upstream → ahead_by is commits in upstream
          // not in local, i.e. how far our deploy is behind master.
          const cmpRes = await fetch(
            `https://api.github.com/repos/${NEWSERV_UPSTREAM_REPO}/compare/${NEWSERV_REV}...${upstream}`,
            { headers, signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS) },
          );
          if (cmpRes.ok) {
            const cmp = await cmpRes.json();
            behindBy = typeof cmp?.ahead_by === 'number' ? cmp.ahead_by : null;
          } else {
            upstreamError = `github compare api: ${cmpRes.status}`;
          }
        }
      }
    }
  } catch (err) {
    upstreamError = err.message;
  }

  return {
    local: NEWSERV_REV,
    upstream,
    behindBy,
    upstreamError,
    commitUrl:
      NEWSERV_REV !== 'unknown'
        ? `https://github.com/${NEWSERV_UPSTREAM_REPO}/commit/${NEWSERV_REV}`
        : null,
    compareUrl:
      upstream && NEWSERV_REV !== 'unknown' && NEWSERV_REV !== upstream
        ? `https://github.com/${NEWSERV_UPSTREAM_REPO}/compare/${NEWSERV_REV}...${upstream}`
        : null,
  };
}

app.get('/api/build', async (_req, res) => {
  try {
    const now = Date.now();
    if (!buildInfoCache || now - buildInfoCache.at > BUILD_INFO_TTL_MS) {
      buildInfoCache = { at: now, data: await fetchBuildInfo() };
    }
    res.json(buildInfoCache.data);
  } catch (err) {
    console.error(`[api/build] ${err.message}`);
    res.status(502).json({ error: 'build info unavailable' });
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
  console.log(`[dashboard] newserv revision: ${NEWSERV_REV}`);
});
