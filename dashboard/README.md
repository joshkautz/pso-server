# Dashboard

Public stats + quest browser + player roster for the private newserv PSO server,
served at <https://pso.joshkautz.com>.

Two files do the work:

- **`index.html`** — single-file frontend. All HTML, CSS, and JS inline. Reads
  data from `/api/*` on this same origin and falls back to a clean empty state
  if the API can't be reached. No build step.
- **`server.js`** — ~250 lines of Node + Express. Serves `index.html` and
  proxies a strict allowlist of newserv REST endpoints under `/api/*` with
  per-route sanitisers. Everything outside the allowlist returns 404.

## How the pieces connect

```
public internet
  │
  ▼  HTTPS (Let's Encrypt cert, auto-renewing)
Caddy 2 (caddy:2-alpine) ── listens on 80 + 443 on the Lightsail box
  │
  ▼  HTTP, docker bridge network "internal"
┌────────────────────────────────────────┐
│ dashboard container                    │
│   GET /                → index.html    │
│   GET /api/<resource>  → allowlist     │
│   GET /api/build       → GitHub-cached │
│   GET /healthz         → 200 OK        │
└──────────────┬─────────────────────────┘
               │  HTTP, docker bridge network "internal"
               ▼
┌────────────────────────────────────────┐
│ newserv container                      │
│   REST API on :8081                    │
│   (HTTPListen in server/config.json)   │
└────────────────────────────────────────┘
```

The newserv REST API is **never** published to the host — port 8081 is reachable
only from sibling containers on the `internal` docker network. The dashboard
container is the only thing on that network that talks to it, and it only
forwards `GET` requests for a small allowlisted set of routes.

Caddy is the TLS terminator (see the repo-root `Caddyfile`). It also adds
security headers (HSTS, X-Frame-Options, X-Content-Type-Options,
Referrer-Policy, Permissions-Policy, removes `Server`).

## Safe-endpoint allowlist

Defined in `server.js`. Each entry passes its response through a sanitiser
before the dashboard frontend ever sees it.

| Public path        | Upstream                | Sanitiser                                              |
|--------------------|-------------------------|--------------------------------------------------------|
| `GET /api/summary` | `GET /y/summary`        | `stripSensitive` — drops account_id, session_id, IP    |
| `GET /api/lobbies` | `GET /y/lobbies`        | `stripPlayerIdentities` — drops remote addresses       |
| `GET /api/server`  | `GET /y/server`         | passthrough                                            |
| `GET /api/quests`  | `GET /y/data/quests`    | passthrough                                            |
| `GET /api/accounts`| `GET /y/accounts`       | `stripAccountIdentities` — keeps only {name, platforms[]}, drops PSO serials / passwords / bans / auto-replies / account IDs; filters out banned accounts |
| `GET /api/build`   | (none — calls GitHub)   | n/a — see "Build SHA" below                            |

Adding a new entry is a deliberate act. **Never** proxy `/y/shell-exec`
(arbitrary code execution) or expose anything that returns a PSO serial,
access key, password, account ID, IP address, or session token. When in doubt,
write a new sanitiser.

There's also a 10-second in-memory TTL cache so dashboard refreshes don't
hammer newserv on every poll.

## Build SHA + freshness check

`/api/build` is the only `/api/*` route that doesn't proxy newserv. It returns:

```json
{
  "local":      "93bad47c03e3697e87093c04b930eabfc2db5237",
  "upstream":   "93bad47c03e3697e87093c04b930eabfc2db5237",
  "behindBy":   0,
  "commitUrl":  "https://github.com/fuzziqersoftware/newserv/commit/93bad47…",
  "compareUrl": null
}
```

- `local` comes from the `NEWSERV_REV` env var (set by `deploy.yml` after
  reading the deployed image's `org.opencontainers.image.revision` OCI label).
- `upstream` + `behindBy` come from GitHub's `commits/master` and `compare`
  APIs, cached server-side for 1 hour to stay well under the 60/hour unauth
  rate limit (~2 calls per cache miss).

The identity card renders `newserv 93bad47 (up to date)` in green when even
with master, or `(N behind)` linking to the compare view in warning yellow.
Older images that pre-date the label landing pass `NEWSERV_REV=unknown` and
the row renders as `newserv —`.

## Frontend sections

- **Hero** — countdown to a configured target date (currently July 20, 2026)
  in the eyebrow slot. Live ticker via `setInterval`, paused on `visibilitychange`
  so background tabs don't waste cycles.
- **Server identity card** — Login host, ports, `newserv <sha> (up to date)`.
- **Live metrics** — Hunters online, Active games, Uptime, Available quests.
  Sourced from `/api/summary` + `/api/quests`. Uses newserv's PascalCase
  field names (`Server.ClientCount`, `Server.GameCount`, `Server.UptimeUsecs`,
  `Quests[]`) — easy place to break the page if you snake-case anything here.
- **Live activity** — "Now playing" from `/api/lobbies`, "Rare drops" empty
  until the WebSocket bridge lands (task #60).
- **Players** — registered hunters from `/api/accounts`. Shows last character
  name + platform badges. Levels / classes / quest completions aren't exposed
  by any current newserv endpoint (task #61).
- **Quest library** — cards from `/api/quests`, filtered to quests that
  have a **GameCube variant** (the operator's primary client base is
  Dolphin + real-GameCube hardware). The server enables every PSO
  platform newserv supports — DC, PC, GC, XB, BB — so non-GC players
  can still join games and play any quest where their version's variant
  also exists. With newserv's current bundle the GC-playable subset is
  ~142 of 260 quests. Cards are classified by Episode (1/2/4) and Source
  (Original Sega / Custom community), paginated at 9 per page. Each
  card is a button — `cursor: pointer`, `role="button"`,
  `aria-haspopup="dialog"`, click + Enter + Space — opening a native
  `<dialog>` modal with full briefing, all quest metadata, and badge
  pair.
- **Features / Join / Resources** — static content.

## Frontend conventions

- **PascalCase**: newserv emits PascalCase JSON keys (`Server.ClientCount`,
  `Quests[].Metadata.Episode`, etc.). Match what newserv sends — don't
  pre-normalise to snake_case in the adapter or the page will silently
  fail to populate.
- **No mock data on screen**: mock arrays exist only as a "shape doc" in code
  comments. Initial render shows empty state / "Loading…", which the API
  overwrites within ~100ms. Never use `7` / `42` / etc. as static HTML
  placeholders again — those silently look like real numbers if the JS
  ever breaks (see commit `5346011`).
- **Accessibility**: WCAG 2.1 AA contrast, semantic landmarks (`<header>`,
  `<main>`, `<section>`, `<footer>`, `<nav>`), `:focus-visible` rings,
  keyboard-reachable. `prefers-reduced-motion` respected for the modal
  open animation. Quest cards have `role="button"` + `aria-haspopup="dialog"`
  + `tabindex="0"` so they're announced as clickable. Countdown timer
  refreshes the `aria-label` only on day boundaries to avoid spammy
  re-announcement.
- **Escape user-supplied strings**: quest names + descriptions + player names
  come from the API and could in principle contain `<`, `&`, `'`, `"`.
  `escapeHtml()` is called on every interpolation that goes through
  `innerHTML`. Don't bypass it.

## Local development

```bash
# Install deps
cd dashboard
npm install

# Start the backend
NEWSERV_API=http://localhost:8081 npm run dev
```

`npm run dev` is `node --watch server.js` — restarts on file change.

Without a local newserv process, every `/api/*` call returns 502 and the page
renders honest empty states for everything except the static content + the
countdown timer. To get real data locally, point `NEWSERV_API` at a running
newserv (e.g. via SSH tunnel to the production box, or by running newserv
locally in another container).

## Deployment

Every push to `main` that touches `dashboard/**`:

1. **`.github/workflows/build-dashboard.yml`** builds the container, pushes
   `ghcr.io/joshkautz/pso-dashboard:main` to GHCR.
2. **`.github/workflows/deploy.yml`** (triggered by `workflow_run` from the
   build) pulls the new image onto the Lightsail box and runs
   `docker compose up -d`.

Pushes that only touch `dashboard/` don't rebuild newserv. Same in reverse —
`build-image.yml` triggers don't rebuild the dashboard.

Pushes that touch infra (`infra/**`) hit `infra.yml` which does
`terraform plan` then `apply` automatically — see the root README.

## Files

- `Dockerfile` — Node 22 alpine, runs as `node` user. Built in CI.
- `package.json` — express ^4.21.2; engines: node ^20+; scripts: start, dev.
- `server.js` — backend (proxy + allowlist + sanitisers + GitHub build check).
- `index.html` — single-file frontend (HTML + CSS + JS inline).
- `README.md` — this file.

## Quest provenance

`dashboard/quest-provenance.json` is a per-quest overlay the frontend fetches
on load. Entries override the default CategoryID-based source classification
+ provide a human-readable `originLabel` and external `sourceUrl` for the
modal "Origin" link.

The current state of newserv's bundled `system/quests/download/` was
surveyed by web research (commit `d5f0555`): of the 11 quests under
CategoryID 21 ("Download"), only 2 are genuinely fan-made (`q000` by
soulja224466; `q253` is Matt Swift's Story Flag Fixer utility added in
2024). The other 9 are official Sega DC/GC download quests historically
distributed via download channel. The provenance file reclassifies them
with `classify: "original"` so they appear under the "Original game"
filter chip with an Ephinea wiki / PSO-World article link in the modal.

When community packs land (via task #53's documented install flow),
add their entries here mapping quest numbers to attribution.

## newserv fork

The dashboard depends on two read endpoints that don't ship in upstream
`fuzziqersoftware/newserv` — `/y/characters` (sanitized walk of saved
character files) and `/y/data/quest/:num/completions` (which characters
have completed quest N). Those live on `joshkautz/newserv@master`, a
fork we maintain. The intent is to **stay forked**, not PR upstream;
the features are dashboard-specific and the upstream project hasn't
asked for them.

`build-image.yml` defaults `NEWSERV_REPO`/`NEWSERV_REF` to
`joshkautz/newserv`/`master`. To pick up upstream fixes:

```bash
cd /path/to/joshkautz/newserv-checkout
git remote add upstream https://github.com/fuzziqersoftware/newserv.git
git fetch upstream master
git merge upstream/master
git push origin master   # CI sees the new master, rebuilds the image
```

## Pending

- **#60 Rare-drops WebSocket** — `WS /y/rare-drops/stream` exists on
  newserv. The dashboard backend needs a WebSocket proxy hop on
  `/api/drops/stream` and the frontend ticker needs to consume the
  stream + prepend events with a capped buffer.
- **#53 Community quest packs** — operational; install pack files under
  `server/quests/download/` per the procedure in
  [`docs/community-quests.md`](../docs/community-quests.md) and they show up
  via the existing CategoryID 21 path automatically. Add per-pack entries
  to `quest-provenance.json` so each new quest gets a proper Origin link.
