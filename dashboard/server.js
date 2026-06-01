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
import http from 'node:http';
import { WebSocketServer, WebSocket } from 'ws';

const __dirname = dirname(fileURLToPath(import.meta.url));
const app = express();
// Explicit http.Server so we can attach an `upgrade` handler for the
// WebSocket route — Express's app.listen() doesn't expose the underlying
// server in a clean way.
const server = http.createServer(app);

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
  ['summary',    { path: '/y/summary',     strip: stripSensitive }],
  ['lobbies',    { path: '/y/lobbies',     strip: stripPlayerIdentities }],
  ['server',     { path: '/y/server',      strip: passthrough }],
  ['quests',     { path: '/y/data/quests', strip: passthrough }],
  ['accounts',   { path: '/y/accounts',    strip: stripAccountIdentities }],
  // /y/characters is already sanitized server-side (see HTTPServer.cc's
  // /y/characters handler — drops PSO serials, passwords, ban times, raw
  // inventory hex, bank contents, guild card data, auto-reply text,
  // info-board text, choice-search config). AccountID is intentionally
  // kept so the frontend can group characters by account (each PSO
  // account has up to 4 character slots).
  ['characters', { path: '/y/characters',  strip: passthrough }],
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

// /y/accounts returns full Account records — license details (with PSO
// serial numbers / passwords), ban end-times, auto-reply messages,
// per-platform login dicts, internal account_id, BBTeamID, ep3 meseta
// totals, auto-patch flags. Most of that is PII or server-internal
// state. We keep only the bare minimum for a "who has played here" list:
// the most-recent character name and a list of platforms the account
// has registered logins for. Banned accounts are filtered out entirely.
function stripAccountIdentities(data) {
  if (!Array.isArray(data)) return [];
  const out = [];
  for (const a of data) {
    if (!a || typeof a !== 'object') continue;

    // Skip currently-banned accounts — BanEndTime is a Unix timestamp in
    // seconds, 0 (or negative) means "not banned".
    if (typeof a.BanEndTime === 'number' && a.BanEndTime > Math.floor(Date.now() / 1000)) {
      continue;
    }
    const name = typeof a.LastPlayerName === 'string' && a.LastPlayerName.trim()
      ? a.LastPlayerName.trim()
      : null;
    if (!name) continue;

    // Derive platforms from the per-version license arrays. The arrays
    // themselves contain serial-numbers / passwords / etc. so they're
    // dropped wholesale — we only keep the count + the friendly label.
    const platforms = [];
    if (Array.isArray(a.GCLicenses)    && a.GCLicenses.length)    platforms.push('GameCube');
    if (Array.isArray(a.BBLicenses)    && a.BBLicenses.length)    platforms.push('Blue Burst');
    if (Array.isArray(a.PCLicenses)    && a.PCLicenses.length)    platforms.push('PC');
    if (Array.isArray(a.XBLicenses)    && a.XBLicenses.length)    platforms.push('Xbox');
    if (Array.isArray(a.DCLicenses)    && a.DCLicenses.length)    platforms.push('Dreamcast');
    if (Array.isArray(a.DCNTELicenses) && a.DCNTELicenses.length) platforms.push('DC NTE');

    out.push({ name, platforms });
  }
  return out;
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

// =========================================================================
// /api/quest/:num/completions
//
// Per-quest "who has completed this" — proxies newserv's parameterized
// /y/data/quest/:num/completions endpoint. Quest number must be a
// non-negative integer; anything else returns 400 without touching
// newserv. The response is already sanitized server-side (each entry
// is just {AccountID, SlotIndex, Name}).
// =========================================================================

app.get('/api/quest/:num/completions', async (req, res) => {
  const num = Number.parseInt(req.params.num, 10);
  if (!Number.isInteger(num) || num < 0 || String(num) !== req.params.num) {
    return res.status(400).json({ error: 'quest number must be a non-negative integer' });
  }
  try {
    const data = await fetchCached(
      `quest-completions:${num}`,
      `${NEWSERV_API}/y/data/quest/${num}/completions`,
    );
    res.json(data);
  } catch (err) {
    console.error(`[api/quest/${num}/completions] ${err.message}`);
    res.status(502).json({ error: 'upstream unavailable' });
  }
});

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

// =========================================================================
// WebSocket proxy: /api/drops/stream
//
// Maintains exactly one outbound WebSocket connection to newserv's
// `WS /y/rare-drops/stream` endpoint and fans the messages out to every
// browser subscribed on `/api/drops/stream`. Browsers never reach newserv
// directly — same security model as the HTTP allowlist.
//
// On the wire newserv emits one JSON object per rare drop with these
// fields (see ReceiveSubcommands.cc:2300+):
//   PlayerAccountID, PlayerName, PlayerVersion, GameName, GameDropMode,
//   ItemData (raw hex), ItemDescription, NotifyGame, NotifyServer
//
// We sanitize:
//   - drop PlayerAccountID (server-internal ID, no need to leak it)
//   - drop ItemData (raw bytes, not useful for the ticker)
//   - drop NotifyGame (game-internal flag)
//   - drop messages with NotifyServer=false (they're game-local, not
//     intended for the public ticker)
//   - the first message on connect is a server-hello (NewservVersion
//     field), not a drop event — skip those
//
// Per-client messages are wrapped as {type, ...} so future event kinds
// (server status, etc.) can ride the same stream.
// =========================================================================

const wss = new WebSocketServer({ noServer: true });
const dropSubscribers = new Set();
let newservDropsWs = null;
let newservReconnectTimer = null;

function sanitizeDropMessage(msg) {
  if (!msg || typeof msg !== 'object') return null;
  return {
    type: 'drop',
    player:  typeof msg.PlayerName       === 'string' ? msg.PlayerName       : '?',
    version: typeof msg.PlayerVersion    === 'string' ? msg.PlayerVersion    : null,
    game:    typeof msg.GameName         === 'string' ? msg.GameName         : '',
    item:    typeof msg.ItemDescription  === 'string' ? msg.ItemDescription  : 'Unknown',
    // Stamp at receipt — newserv doesn't put a timestamp in the message
    // and the ticker only needs relative "X seconds ago" anyway.
    ts: Date.now(),
  };
}

function connectToNewservDropsStream() {
  if (newservDropsWs) return;
  clearTimeout(newservReconnectTimer);

  const url = `${NEWSERV_API.replace(/^http/, 'ws')}/y/rare-drops/stream`;
  console.log(`[drops] connecting to ${url}`);
  let ws;
  try {
    ws = new WebSocket(url);
  } catch (err) {
    console.warn(`[drops] WS construct failed: ${err.message}`);
    newservReconnectTimer = setTimeout(connectToNewservDropsStream, 5000);
    return;
  }

  ws.on('open', () => {
    console.log('[drops] connected to newserv');
    newservDropsWs = ws;
  });

  ws.on('message', (data) => {
    let msg;
    try {
      msg = JSON.parse(data.toString());
    } catch (err) {
      console.warn(`[drops] non-JSON from newserv: ${err.message}`);
      return;
    }
    // The server-version hello fires on every connect — discard it.
    if (msg && typeof msg.NewservVersion === 'string') return;
    // Only forward drops flagged as global notifications.
    if (msg && msg.NotifyServer === false) return;

    const out = sanitizeDropMessage(msg);
    if (!out) return;
    const payload = JSON.stringify(out);
    for (const sub of dropSubscribers) {
      if (sub.readyState === WebSocket.OPEN) {
        sub.send(payload);
      }
    }
  });

  ws.on('close', () => {
    console.log('[drops] disconnected from newserv, retrying in 5s');
    newservDropsWs = null;
    newservReconnectTimer = setTimeout(connectToNewservDropsStream, 5000);
  });

  ws.on('error', (err) => {
    console.warn(`[drops] newserv ws error: ${err.message}`);
    // 'close' will fire after 'error'; reconnect there.
  });
}

server.on('upgrade', (req, socket, head) => {
  const path = new URL(req.url, 'http://localhost').pathname;
  if (path === '/api/drops/stream') {
    wss.handleUpgrade(req, socket, head, (ws) => {
      wss.emit('connection', ws, req);
    });
  } else {
    // Unknown upgrade target — reject the handshake cleanly so the client
    // doesn't sit blocked waiting for a response.
    socket.destroy();
  }
});

wss.on('connection', (ws) => {
  dropSubscribers.add(ws);
  console.log(`[drops] subscriber connected (${dropSubscribers.size} total)`);
  // Send a one-shot hello so the client knows whether we have a working
  // upstream connection. The browser can decide whether to show "live" UI.
  ws.send(JSON.stringify({
    type: 'hello',
    upstreamConnected: !!newservDropsWs,
  }));
  ws.on('close', () => {
    dropSubscribers.delete(ws);
  });
  ws.on('error', () => {/* close fires too */});
});

connectToNewservDropsStream();

server.listen(PORT, () => {
  console.log(`[dashboard] listening on :${PORT}`);
  console.log(`[dashboard] proxying ${ALLOWLIST.size} routes to ${NEWSERV_API}`);
  console.log(`[dashboard] newserv revision: ${NEWSERV_REV}`);
  console.log(`[dashboard] WebSocket /api/drops/stream → ${NEWSERV_API.replace(/^http/, 'ws')}/y/rare-drops/stream`);
});
