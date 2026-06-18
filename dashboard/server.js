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
import crypto from 'node:crypto';
import { WebSocketServer, WebSocket } from 'ws';
import {
  CostExplorerClient,
  GetCostAndUsageCommand,
  GetCostForecastCommand,
} from '@aws-sdk/client-cost-explorer';

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

// Two repos in play for the build/upstream indicator:
//   - FORK     = our patched fork. The deployed image is built from here,
//                and our master is where the deployed SHA must live.
//   - UPSTREAM = fuzziqersoftware/newserv. We watch its master so we
//                know when there are upstream commits we should pull in.
//
// The dashboard's "up to date" indicator answers: does our fork's master
// already contain upstream's HEAD commit? If yes → up to date. If no →
// there are upstream commits to merge into our fork.
const NEWSERV_FORK_REPO = 'joshkautz/newserv';
const NEWSERV_FORK_BRANCH = 'master';
const NEWSERV_UPSTREAM_REPO = 'fuzziqersoftware/newserv';
const NEWSERV_UPSTREAM_BRANCH = 'master';
// GitHub unauth rate limit is 60/hr per IP. We make at most 2 calls
// per cache miss (commits/master + compare), so 1h TTL keeps us at
// ~2 calls/hr — comfortably under budget even with sporadic restarts.
const BUILD_INFO_TTL_MS = 60 * 60 * 1000;

// Level tables are static once newserv has loaded them at boot — there's
// no reason to re-fetch every few seconds. An hour TTL keeps us off the
// hot path for the lifetime of a typical container instance.
const LEVEL_TABLES_TTL_MS = 60 * 60 * 1000;

// HMAC secret used to derive AccountToken from AccountID before any data
// leaves the backend. Generated per-process so a token from one container
// can't be replayed against another, and so the raw account_id (which
// equals the player's PSO serial number for disc versions) is never
// recoverable from the public response. The frontend uses the token as
// a stable Map key for the lifetime of a page load; it doesn't need to
// persist across restarts.
const ACCOUNT_TOKEN_SECRET = crypto.randomBytes(32);

// =========================================================================
// PSO class-name → index map. Mirrors name_for_char_class() in newserv's
// StaticGameData.cc — needed to look up rows in the level-table arrays,
// which are indexed by enum value (not class name).
// =========================================================================
const CLASS_NAME_TO_INDEX = Object.freeze({
  HUmar:     0,
  HUnewearl: 1,
  HUcast:    2,
  RAmar:     3,
  RAcast:    4,
  RAcaseal:  5,
  FOmarl:    6,
  FOnewm:    7,
  FOnewearl: 8,
  HUcaseal:  9,
  FOmar:     10,
  RAmarl:    11,
});

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
  // /api/characters has its own dedicated route below — it has to
  // cross-reference /y/accounts and /y/data/level-tables to derive
  // AccountToken (HMAC of account_id), IsLikelyBB (which decides whether
  // EXP / PlayTime are trustworthy), and EXPToNextLevel. The generic
  // allowlist passthrough pattern only handles single-source fetches.
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
// AccountToken derivation
//
// For disc-version players (DC/GC/PC/Xbox), `account_id` happens to equal
// the PSO serial number printed on the player's HUNTER's License — i.e.
// half their login credential. Even leaking just the serial gives an
// attacker who already knows or guesses the access key the ability to
// impersonate. We never want to surface the raw value publicly.
//
// AccountToken is a deterministic HMAC of the account_id keyed by a
// per-process secret. It preserves the property the frontend needs
// (stable identifier for grouping characters by account, keying Map
// lookups, matching modal selections) without exposing the original.
// Reverse-mapping is computationally infeasible without the secret;
// brute-forcing requires generating tokens for every plausible 10-digit
// PSO serial and comparing — which would still only narrow to "this is
// account #N on the server," not yield the credential.
// =========================================================================

function accountToken(accountId) {
  // Numeric account_ids come through as JS numbers; stringify so the
  // HMAC input is deterministic regardless of upstream type.
  return crypto
    .createHmac('sha256', ACCOUNT_TOKEN_SECRET)
    .update(String(accountId))
    .digest('hex')
    .slice(0, 16);
}

// Reverse the AccountToken HMAC for routes that need to forward an
// account-scoped request to newserv. The HMAC isn't actually invertible —
// we just build a token → account_id index by computing accountToken()
// for every known account and remembering the mapping. Total account
// count is small (10s–100s), so a fresh build per request is cheap.
// Re-fetches /y/accounts via the same 10s TTL cache the public
// /api/accounts route uses, so this lookup is effectively O(1) most of
// the time.
async function resolveAccountToken(token) {
  if (typeof token !== 'string' || !/^[0-9a-f]{16}$/.test(token)) {
    return null;
  }
  const rawAccounts = await fetchCached('accounts-internal', `${NEWSERV_API}/y/accounts`);
  if (!Array.isArray(rawAccounts)) return null;
  for (const a of rawAccounts) {
    if (a && typeof a.AccountID === 'number' && accountToken(a.AccountID) === token) {
      return a.AccountID;
    }
  }
  return null;
}

// =========================================================================
// Character sanitiser
//
// Takes the raw /y/characters response, plus side-data from /y/accounts
// (for BB-likelihood inference) and /y/data/level-tables (for EXP-to-next
// computation), and produces the dashboard-safe shape:
//
//   {
//     AccountToken:    "deadbeef12345678",  // 16-hex HMAC of account_id
//     SlotIndex:       0,
//     Name:            "Sonic",
//     Class:           "HUmar",
//     SectionID:       "Pinkal",
//     Level:           42,
//     Meseta:          99999,
//     Stats:           {...},
//     // EXP-related fields. Only trustworthy for BB (server-authoritative);
//     // for disc versions they reflect whatever the client last uploaded
//     // at a 61/98 boundary, which lags behind real progression. We pass
//     // IsLikelyBB so the frontend can decide whether to render literals
//     // or "—" with a tooltip.
//     IsLikelyBB:      true | false | null,
//     EXP:             123456 | null,         // cumulative since L1
//     EXPToNextLevel:  4321   | null,
//     PlayTimeSeconds: 720000 | null,
//   }
//
// IsLikelyBB resolution:
//   - account has BBLicenses AND no other licenses → true (snapshot is BB)
//   - account has non-BB licenses AND no BBLicenses → false (snapshot is disc)
//   - account has both kinds, or lookup fails       → null (can't tell)
//
// "null" means "we don't trust EXP/PlayTime for this character"; the
// frontend hides those fields rather than guessing.
// =========================================================================

function buildAccountBBIndex(rawAccounts) {
  // /y/accounts comes from inside the docker network — it returns full
  // account records including license arrays. We only read here, never
  // surface; the public /api/accounts goes through stripAccountIdentities.
  const out = new Map();
  if (!Array.isArray(rawAccounts)) return out;
  for (const a of rawAccounts) {
    if (!a || typeof a.AccountID !== 'number') continue;
    const hasBB =
      Array.isArray(a.BBLicenses)    && a.BBLicenses.length    > 0;
    const hasOther =
      (Array.isArray(a.GCLicenses)    && a.GCLicenses.length    > 0) ||
      (Array.isArray(a.PCLicenses)    && a.PCLicenses.length    > 0) ||
      (Array.isArray(a.XBLicenses)    && a.XBLicenses.length    > 0) ||
      (Array.isArray(a.DCLicenses)    && a.DCLicenses.length    > 0) ||
      (Array.isArray(a.DCNTELicenses) && a.DCNTELicenses.length > 0);
    let isLikelyBB;
    if (hasBB && !hasOther) isLikelyBB = true;
    else if (!hasBB && hasOther) isLikelyBB = false;
    else isLikelyBB = null;  // both or neither — can't infer
    out.set(a.AccountID, isLikelyBB);
  }
  return out;
}

function computeExpToNextLevel(charClass, currentLevel, currentExp, levelTables, isLikelyBB) {
  // We don't know which version's curve was used to produce the snapshot.
  // For BB we use v4; for disc versions we default to v3 (the only disc
  // family in active use here is GC). For "unknown" / mixed accounts we
  // skip the computation rather than guess — the EXP value itself is
  // already untrustworthy in that case.
  if (isLikelyBB === null) return null;
  if (!levelTables || typeof levelTables !== 'object') return null;
  const table = isLikelyBB ? levelTables.v4 : levelTables.v3;
  if (!table || !Array.isArray(table.LevelDeltas)) return null;
  const classIndex = CLASS_NAME_TO_INDEX[charClass];
  if (typeof classIndex !== 'number') return null;
  const row = table.LevelDeltas[classIndex];
  if (!Array.isArray(row)) return null;
  // `Level` from /y/characters is 1-based (in-game level). The level table
  // is 0-indexed and row[k].EXP is the cumulative EXP needed to reach
  // internal level k = in-game level k+1. To advance from in-game
  // currentLevel to currentLevel+1, look up row[currentLevel] (since
  // internal level = currentLevel = in-game level - 1 + 1 = currentLevel).
  // Wait through that: in-game Lv.2 → internal level 1 → next is internal
  // level 2 → row index 2 → which the table calls "to reach in-game Lv.3".
  // So the index we want is `currentLevel` (1-based in-game = next
  // internal level = next row index).
  const nextRow = row[currentLevel];
  if (!nextRow || typeof nextRow.EXP !== 'number') return null;
  const remaining = nextRow.EXP - (typeof currentExp === 'number' ? currentExp : 0);
  return remaining > 0 ? remaining : 0;
}

function stripCharacters(rawCharacters, rawAccounts, levelTables) {
  if (!Array.isArray(rawCharacters)) return [];
  const bbIndex = buildAccountBBIndex(rawAccounts);
  const out = [];
  for (const c of rawCharacters) {
    if (!c || typeof c !== 'object') continue;
    if (typeof c.AccountID !== 'number') continue;
    const isLikelyBB = bbIndex.has(c.AccountID) ? bbIndex.get(c.AccountID) : null;
    // EXP / play-time are server-authoritative (and therefore trustworthy) when
    // the SNAPSHOT itself was taken from a Blue Burst session — which newserv
    // now records per snapshot as SnapshotVersion. This is more precise than the
    // old account-license heuristic: an account can hold both BB and disc
    // licenses, which left isLikelyBB null and wrongly hid BB EXP. Fall back to
    // the license heuristic for legacy snapshots predating the .version sidecar.
    const snapshotVersion = typeof c.SnapshotVersion === 'string' ? c.SnapshotVersion : null;
    const isBBSnapshot = snapshotVersion
      ? snapshotVersion.startsWith('BB')
      : isLikelyBB === true;
    const expToNext = computeExpToNextLevel(
      c.Class,
      typeof c.Level === 'number' ? c.Level : 0,
      typeof c.EXP === 'number' ? c.EXP : 0,
      levelTables,
      isBBSnapshot,
    );
    out.push({
      AccountToken:    accountToken(c.AccountID),
      SlotIndex:       c.SlotIndex,
      Name:            c.Name,
      Class:           c.Class,
      SectionID:       c.SectionID,
      Level:           c.Level,
      Meseta:          c.Meseta,
      Stats:           c.Stats,
      IsLikelyBB:      isLikelyBB,
      SnapshotVersion: snapshotVersion,
      // IsBBSnapshot drives the EXP / play-time trust gate in the frontend.
      IsBBSnapshot:    isBBSnapshot,
      // EXP / PlayTime: raw values for BB snapshots (server-authoritative),
      // null otherwise (frontend renders "—"). The dashboard never shows a
      // misleading "0" for EXP/play-time on a disc-version character.
      EXP:             isBBSnapshot ? (typeof c.EXP === 'number' ? c.EXP : null) : null,
      EXPToNextLevel:  isBBSnapshot ? expToNext : null,
      PlayTimeSeconds: isBBSnapshot ? (typeof c.PlayTimeSeconds === 'number' ? c.PlayTimeSeconds : null) : null,
      // Inventory passthrough — already sanitized server-side:
      // newserv's /y/characters resolves names via describe_item and
      // returns just {Name, Kind, Equipped} per entry. No raw item
      // bytes / IDs reach the dashboard. Inventory is more useful than
      // EXP for disc versions because gear changes are infrequent
      // enough that "as of last lobby return" is still good UI — we
      // pass it through for every version, BB or not.
      Inventory:       Array.isArray(c.Inventory) ? c.Inventory : [],
    });
  }
  return out;
}

// Quest-completion lists also include raw AccountID (so the frontend can
// match a completion entry to a character row by account). Same security
// concern, same fix.
function stripQuestPlays(rawPlays) {
  if (!Array.isArray(rawPlays)) return [];
  const out = [];
  for (const entry of rawPlays) {
    if (!entry || typeof entry !== 'object') continue;
    if (typeof entry.AccountID !== 'number') continue;
    out.push({
      AccountToken:    accountToken(entry.AccountID),
      SlotIndex:       entry.SlotIndex,
      Name:            entry.Name,
      PlayCount:       typeof entry.PlayCount === 'number' ? entry.PlayCount : 0,
      LastPlayedUsecs: typeof entry.LastPlayedUsecs === 'number' ? entry.LastPlayedUsecs : 0,
    });
  }
  return out;
}

// =========================================================================
// Small TTL cache to avoid hammering newserv on every dashboard refresh
// =========================================================================

const cache = new Map();

async function fetchCached(key, url) {
  return fetchCachedLongTTL(key, url, CACHE_TTL_MS);
}

async function fetchCachedLongTTL(key, url, ttlMs) {
  const now = Date.now();
  const cached = cache.get(key);
  if (cached && now - cached.at < ttlMs) {
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
// /api/quest/:num/plays
//
// Per-quest "who has played this" — proxies newserv's parameterized
// /y/data/quest/:num/plays endpoint. Quest number must be a non-negative
// integer; anything else returns 400 without touching newserv. newserv
// records a play whenever a quest is loaded into a game (the only quest
// event the server authoritatively observes — online quests run
// client-side, so there is no reliable "completed" signal). Each entry is
// {AccountID, SlotIndex, Name, PlayCount, LastPlayedUsecs}; AccountID is
// HMAC'd to AccountToken before it reaches the browser.
// =========================================================================

// =========================================================================
// /api/character/:token/:slot/quest-plays
//
// The inverse of /api/quest/:num/plays — for one character, the quests
// they've played with per-quest play count, last-played time, and the
// difficulties seen. The frontend renders this as "Quests played" in the
// player modal, mirroring how /api/quest/:num/plays feeds "Played by" in
// the quest modal.
//
// :token is the AccountToken (HMAC of the real account_id); we reverse
// it via the per-process token index before forwarding. Slot is a
// 0–3 integer (PSO's per-account character slot range).
// =========================================================================

app.get('/api/character/:token/:slot/quest-plays', async (req, res) => {
  const slot = Number.parseInt(req.params.slot, 10);
  if (!Number.isInteger(slot) || slot < 0 || slot > 3 || String(slot) !== req.params.slot) {
    return res.status(400).json({ error: 'slot must be 0..3' });
  }
  const accountId = await resolveAccountToken(req.params.token);
  if (accountId == null) {
    return res.status(404).json({ error: 'unknown account' });
  }
  try {
    const data = await fetchCached(
      `character-quest-plays:${accountId}:${slot}`,
      `${NEWSERV_API}/y/character/${accountId}/${slot}/quest-plays`,
    );
    // Response is pure quest data — {QuestNumber, PlayCount, LastPlayedUsecs,
    // Difficulties[]} entries, no account or character PII. Passthrough is safe.
    res.json(Array.isArray(data) ? data : []);
  } catch (err) {
    console.error(`[api/character/${req.params.token}/${slot}/quest-plays] ${err.message}`);
    res.status(502).json({ error: 'upstream unavailable' });
  }
});

app.get('/api/quest/:num/plays', async (req, res) => {
  const num = Number.parseInt(req.params.num, 10);
  if (!Number.isInteger(num) || num < 0 || String(num) !== req.params.num) {
    return res.status(400).json({ error: 'quest number must be a non-negative integer' });
  }
  try {
    const data = await fetchCached(
      `quest-plays:${num}`,
      `${NEWSERV_API}/y/data/quest/${num}/plays`,
    );
    // newserv's response includes raw AccountID — strip it through the same
    // HMAC path /api/characters uses so the frontend can still match plays
    // against character rows without ever seeing the underlying serial.
    res.json(stripQuestPlays(data));
  } catch (err) {
    console.error(`[api/quest/${num}/plays] ${err.message}`);
    res.status(502).json({ error: 'upstream unavailable' });
  }
});

// =========================================================================
// /api/characters
//
// Dedicated route because it joins three upstream sources:
//   - /y/characters     — the raw character snapshots
//   - /y/accounts       — to infer IsLikelyBB per account
//   - /y/data/level-tables — to compute EXP-to-next-level
//
// The strict allowlist passthrough pattern handles single-source fetches
// only; characters needs all three sources cross-referenced before the
// dashboard-safe shape can be produced. See stripCharacters for the
// sanitisation contract.
// =========================================================================

app.get('/api/characters', async (req, res) => {
  try {
    const [rawCharacters, rawAccounts, levelTables] = await Promise.all([
      fetchCached('characters', `${NEWSERV_API}/y/characters`),
      fetchCached('accounts-internal', `${NEWSERV_API}/y/accounts`),
      // level tables are static — long TTL keyed separately so the
      // hot-path cache (10s) doesn't accidentally evict them.
      fetchCachedLongTTL('level-tables', `${NEWSERV_API}/y/data/level-tables`, LEVEL_TABLES_TTL_MS),
    ]);
    res.json(stripCharacters(rawCharacters, rawAccounts, levelTables));
  } catch (err) {
    console.error(`[api/characters] ${err.message}`);
    res.status(502).json({ error: 'upstream unavailable', resource: 'characters' });
  }
});

// Sub-resources handled by dedicated routes registered below — none of
// them proxy newserv, so they must fall through this allowlist handler
// to their own routes.
const RESERVED_RESOURCES = new Set(['build', 'cost']);

app.get('/api/:resource', async (req, res, next) => {
  if (RESERVED_RESOURCES.has(req.params.resource)) return next();
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
// /api/build — surfaces the running newserv SHA and whether our fork is
// in sync with fuzziqersoftware/newserv:master.
//
// "Up to date" here means: our fork's master already contains upstream's
// HEAD commit in its history. The check is fork-vs-upstream, NOT
// deployed-vs-upstream — once an upstream change is merged into the
// fork, the indicator flips to "up to date" even before we've rebuilt
// the image. That matches the user's intent: an at-a-glance signal for
// "is there anything new to pull in from fuzziqersoftware/newserv?"
//
// Implementation: GitHub's cross-fork compare endpoint compares two
// branches across forks in one call. With base = fork master, head =
// upstream master:
//   ahead_by  = commits in head (upstream) not in base (fork)
//             = upstream commits we haven't merged → "behind upstream"
//   behind_by = commits in base (fork) not in head (upstream)
//             = our fork-only patches sitting on top of the merge base
//
// Note: the GitHub field names look backwards because they describe
// movement relative to the base branch; "ahead_by" being the count of
// commits we're missing is correct.
// =========================================================================

let buildInfoCache = null;

async function fetchBuildInfo() {
  const headers = {
    'User-Agent': 'pso-dashboard',
    Accept: 'application/vnd.github+json',
  };

  let upstreamSha = null;
  let forkSha = null;
  let behindUpstream = null;
  let forkPatchCount = null;
  let upstreamError = null;

  try {
    // 1) Upstream HEAD sha (display only — the compare endpoint gives
    //    us the actual ahead/behind numbers, this is just for tooltips
    //    and parity with the fork field).
    const upstreamHeadRes = await fetch(
      `https://api.github.com/repos/${NEWSERV_UPSTREAM_REPO}/commits/${NEWSERV_UPSTREAM_BRANCH}`,
      { headers, signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS) },
    );
    if (upstreamHeadRes.ok) {
      const head = await upstreamHeadRes.json();
      upstreamSha = typeof head?.sha === 'string' ? head.sha : null;
    } else {
      upstreamError = `github upstream HEAD: ${upstreamHeadRes.status}`;
    }

    // 2) Our fork's HEAD sha.
    const forkHeadRes = await fetch(
      `https://api.github.com/repos/${NEWSERV_FORK_REPO}/commits/${NEWSERV_FORK_BRANCH}`,
      { headers, signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS) },
    );
    if (forkHeadRes.ok) {
      const head = await forkHeadRes.json();
      forkSha = typeof head?.sha === 'string' ? head.sha : null;
    } else if (!upstreamError) {
      upstreamError = `github fork HEAD: ${forkHeadRes.status}`;
    }

    // 3) Cross-fork compare: base = fork master, head = upstream master.
    //    GitHub takes head as `{owner}:{branch}` to reach across forks
    //    within the same repo network.
    if (upstreamSha && forkSha) {
      const upstreamOwner = NEWSERV_UPSTREAM_REPO.split('/')[0];
      const cmpRes = await fetch(
        `https://api.github.com/repos/${NEWSERV_FORK_REPO}/compare/${NEWSERV_FORK_BRANCH}...${upstreamOwner}:${NEWSERV_UPSTREAM_BRANCH}`,
        { headers, signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS) },
      );
      if (cmpRes.ok) {
        const cmp = await cmpRes.json();
        behindUpstream = typeof cmp?.ahead_by === 'number' ? cmp.ahead_by : null;
        forkPatchCount = typeof cmp?.behind_by === 'number' ? cmp.behind_by : null;
      } else if (!upstreamError) {
        upstreamError = `github compare api: ${cmpRes.status}`;
      }
    }
  } catch (err) {
    upstreamError = err.message;
  }

  const upstreamOwner = NEWSERV_UPSTREAM_REPO.split('/')[0];
  return {
    // The SHA of the running container's newserv build, baked into the
    // image at build time. Rendered as the visible "newserv <sha>"
    // label. May be slightly behind the fork's master HEAD if there are
    // unpushed-to-image commits — that's a separate concern from the
    // upstream-tracking indicator.
    local: NEWSERV_REV,
    commitUrl:
      NEWSERV_REV !== 'unknown'
        ? `https://github.com/${NEWSERV_FORK_REPO}/commit/${NEWSERV_REV}`
        : null,
    // Reference points for the upstream check.
    fork: {
      repo: NEWSERV_FORK_REPO,
      branch: NEWSERV_FORK_BRANCH,
      headSha: forkSha,
    },
    upstream: {
      repo: NEWSERV_UPSTREAM_REPO,
      branch: NEWSERV_UPSTREAM_BRANCH,
      headSha: upstreamSha,
    },
    // Number of upstream commits our fork hasn't merged in yet. 0 means
    // we're in sync with upstream → green "(up to date)" indicator.
    behindUpstream,
    // Number of fork-only patches we have on top of the merge base.
    // Surfaced as "+N patches" context, never gates the up-to-date
    // status — these are intentional additions, not staleness.
    forkPatchCount,
    // GitHub web view of the same cross-fork compare we ran, so the
    // "(N behind)" chip can be a click-to-inspect link.
    compareUrl:
      forkSha && upstreamSha
        ? `https://github.com/${NEWSERV_FORK_REPO}/compare/${NEWSERV_FORK_BRANCH}...${upstreamOwner}:${NEWSERV_UPSTREAM_BRANCH}`
        : null,
    upstreamError,
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

// =========================================================================
// /api/cost — hosting cost from AWS Cost Explorer
//
// Powers the Live-section "Hosting cost" card: a small MTD figure, an
// end-of-month forecast, a 30-day daily-spend chart, a per-service
// breakdown, and a tag-filtered-vs-account-wide cross-check.
//
// Cost discipline. Cost Explorer charges $0.01 per API request. Each
// cache miss makes 4 calls:
//   1) GetCostAndUsage, daily, last 60 days, no group  — chart + month sums
//   2) GetCostAndUsage, monthly, current month, group=SERVICE  — breakdown
//   3) GetCostAndUsage, monthly, current month, Tag filter      — crosscheck
//   4) GetCostForecast, MONTHLY                                 — forecast
//
// Cache TTL = 12h. Cost Explorer data itself lags real spend by ~24h, so
// refreshing more often than that buys nothing real. 2 misses/day × 4
// calls = ~$2.40/month worst case, with the dashboard's rare-visitor
// pattern keeping it lower in practice.
//
// Resilience. Any single CE call that fails is reported in the response
// `errors` field but doesn't break the rest — e.g. if the forecast call
// errors (it returns "insufficient history" for fresh accounts), the
// MTD/chart/breakdown still render with a small "forecast unavailable"
// note on the card.
//
// Auth. Reads AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY from the
// container env (written into /home/ubuntu/pso-server/.env by the
// deploy workflow from the AWS_COST_READER_* GitHub secrets, which in
// turn were emitted by terraform output on the cost-reader IAM user).
// The user has only ce:GetCostAndUsage + ce:GetCostForecast — no other
// AWS access.
// =========================================================================

const COST_INFO_TTL_MS = 12 * 60 * 60 * 1000; // 12 hours
const COST_PROJECT_TAG = 'Project';
const COST_PROJECT_VALUE = 'pso-server';

let costInfoCache = null;
let costExplorerClient = null;

function getCostExplorerClient() {
  if (costExplorerClient) return costExplorerClient;
  if (!process.env.AWS_ACCESS_KEY_ID || !process.env.AWS_SECRET_ACCESS_KEY) {
    return null;
  }
  // Cost Explorer is a global service but its single API endpoint lives
  // in us-east-1. We force the region rather than reading from env so a
  // misconfigured AWS_REGION can't silently misroute the calls.
  costExplorerClient = new CostExplorerClient({ region: 'us-east-1' });
  return costExplorerClient;
}

// ISO-date helpers. Cost Explorer takes inclusive start, exclusive end.
function isoDate(d) { return d.toISOString().slice(0, 10); }
function startOfMonth(d) { return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1)); }
function nextMonth(d) { return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 1)); }
function daysAgo(d, n) { const r = new Date(d); r.setUTCDate(r.getUTCDate() - n); return r; }

function monthLabel(d) {
  return d.toLocaleString('en-US', { month: 'long', year: 'numeric', timeZone: 'UTC' });
}

async function fetchCostInfo() {
  const client = getCostExplorerClient();
  if (!client) {
    return { error: 'AWS credentials not configured', errors: [] };
  }

  // Resolve windows once so all four calls reference the same notion of
  // "today" / "this month" — avoids edge cases where the calls span a
  // UTC-midnight boundary mid-request.
  const now = new Date();
  const thisMonthStart = startOfMonth(now);
  const nextMonthStart = nextMonth(now);
  const lastMonthStart = startOfMonth(daysAgo(thisMonthStart, 1));
  const dailyStart = daysAgo(now, 60);
  // Cost Explorer's daily granularity rounds to UTC days; end is
  // exclusive, so to cover "today" we ask for tomorrow.
  const dailyEnd = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1));

  const errors = [];
  const safeRun = async (label, fn) => {
    try { return await fn(); }
    catch (err) { errors.push({ label, message: err.message }); return null; }
  };

  // 1) Daily, last 60 days. Used to build both the chart and the
  //    current-month + last-month sums (cheaper than separate monthly
  //    calls per period).
  const dailyRes = await safeRun('daily', () => client.send(new GetCostAndUsageCommand({
    TimePeriod: { Start: isoDate(dailyStart), End: isoDate(dailyEnd) },
    Granularity: 'DAILY',
    Metrics: ['UnblendedCost'],
  })));

  // 2) Monthly, current month, grouped by service. Used for the
  //    per-service chip breakdown.
  const serviceRes = await safeRun('byService', () => client.send(new GetCostAndUsageCommand({
    TimePeriod: { Start: isoDate(thisMonthStart), End: isoDate(nextMonthStart) },
    Granularity: 'MONTHLY',
    Metrics: ['UnblendedCost'],
    GroupBy: [{ Type: 'DIMENSION', Key: 'SERVICE' }],
  })));

  // 3) Monthly, current month, tag-filtered. Same window as the
  //    account-wide MTD; the difference between this and the account-
  //    wide sum is the "untagged drift" cross-check.
  const tagFilteredRes = await safeRun('tagFiltered', () => client.send(new GetCostAndUsageCommand({
    TimePeriod: { Start: isoDate(thisMonthStart), End: isoDate(nextMonthStart) },
    Granularity: 'MONTHLY',
    Metrics: ['UnblendedCost'],
    Filter: { Tags: { Key: COST_PROJECT_TAG, Values: [COST_PROJECT_VALUE] } },
  })));

  // 4) End-of-month forecast. Window is "today through first-of-next-
  //    month" with MONTHLY granularity, so AWS returns a single
  //    aggregate value covering the rest of the current month — what
  //    we want to add to MTD for the end-of-month projection.
  //    Most prone to fail (insufficient history on young accounts) —
  //    caller treats null gracefully.
  const forecastRes = await safeRun('forecast', () => client.send(new GetCostForecastCommand({
    TimePeriod: { Start: isoDate(now), End: isoDate(nextMonthStart) },
    Granularity: 'MONTHLY',
    Metric: 'UNBLENDED_COST',
  })));

  // Build the daily series + monthly sums from the daily response.
  const daily = [];
  let thisMonthSum = 0;
  let lastMonthSum = 0;
  for (const row of dailyRes?.ResultsByTime ?? []) {
    const date = row.TimePeriod?.Start;
    const usd = Number(row.Total?.UnblendedCost?.Amount ?? 0);
    if (!date) continue;
    daily.push({ date, usd });
    const d = new Date(date + 'T00:00:00Z');
    if (d >= thisMonthStart && d < nextMonthStart) thisMonthSum += usd;
    if (d >= lastMonthStart && d < thisMonthStart) lastMonthSum += usd;
  }

  // Per-service chips, sorted by spend descending so the largest line
  // items render first. Cost Explorer returns the SERVICE name verbatim
  // ("Amazon Lightsail", "Amazon Simple Storage Service", …).
  const byService = ((serviceRes?.ResultsByTime?.[0]?.Groups) ?? [])
    .map((g) => ({
      service: g.Keys?.[0] ?? 'Unknown',
      usd: Number(g.Metrics?.UnblendedCost?.Amount ?? 0),
    }))
    .filter((s) => s.usd > 0)
    .sort((a, b) => b.usd - a.usd);

  const tagFilteredUSD = Number(
    tagFilteredRes?.ResultsByTime?.[0]?.Total?.UnblendedCost?.Amount ?? 0,
  );

  const forecastUSD = forecastRes?.Total?.Amount
    ? Number(forecastRes.Total.Amount)
    : null;

  return {
    asOf: new Date().toISOString(),
    currency: 'USD',
    currentMonth: {
      label: `${monthLabel(thisMonthStart)} (MTD)`,
      spendUSD: thisMonthSum,
      forecastUSD,
    },
    lastMonth: {
      label: monthLabel(lastMonthStart),
      spendUSD: lastMonthSum,
    },
    daily,
    byService,
    crosscheck: {
      tagFilteredUSD,
      accountWideUSD: thisMonthSum,
      // Positive drift = there's spend in the account that isn't tagged
      // Project=pso-server. With Phase 1 cleanup this should be ~$0.
      untaggedDriftUSD: Math.max(0, thisMonthSum - tagFilteredUSD),
    },
    stalenessNote: 'Cost Explorer data lags real spend by ~24h.',
    errors: errors.length > 0 ? errors : null,
    error: null,
  };
}

app.get('/api/cost', async (_req, res) => {
  try {
    const now = Date.now();
    if (!costInfoCache || now - costInfoCache.at > COST_INFO_TTL_MS) {
      const info = await fetchCostInfo();
      costInfoCache = { at: now, info };
    }
    res.json(costInfoCache.info);
  } catch (err) {
    console.error(`[api/cost] ${err.message}`);
    res.status(502).json({ error: 'cost info unavailable', detail: err.message });
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
