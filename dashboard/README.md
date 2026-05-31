# Dashboard

Public-facing status + quest browser for the private newserv PSO server.

Two files do the work:

- **`index.html`** — the dashboard itself. All HTML, CSS, and frontend
  JS in one self-contained file. Renders mock data immediately and
  overlays live data from `/api/*` once the backend responds.
- **`server.js`** — tiny Node.js + Express backend. Serves `index.html`
  and proxies a hardcoded allowlist of newserv REST endpoints under
  `/api/*`. Everything outside the allowlist is rejected.

## How the pieces connect

```
public internet
      │
      ▼
   Lightsail :80
      │
      ▼
┌───────────────────────────┐
│ dashboard container        │
│   /        → index.html    │
│   /api/*   → proxy + strip │
└───────────────┬────────────┘
                │ docker bridge network (private)
                ▼
┌───────────────────────────┐
│ newserv container          │
│   REST API on :8081        │
│   (HTTPListen in           │
│    server/config.json)     │
└────────────────────────────┘
```

The newserv REST API is **never** published to the host. It's only
reachable from sibling containers on the `internal` docker network.
The dashboard container is the only thing on that network that talks
to it, and it only forwards `GET` requests for a small set of safe
routes.

## Safe-endpoint allowlist

Defined in `server.js`. As of v1:

| Public path | Upstream | Sanitiser |
|---|---|---|
| `GET /api/summary` | `GET /y/summary` | Drops per-client identifiers, keeps counts + names |
| `GET /api/lobbies` | `GET /y/lobbies` | Strips player remote addresses, keeps names |
| `GET /api/server` | `GET /y/server` | Passthrough |
| `GET /api/quests` | `GET /y/data/quests` | Passthrough |

Adding new endpoints is a deliberate act — never proxy
`/y/shell-exec` (arbitrary code execution) or `/y/accounts` (PII)
without thinking through what gets surfaced.

## Mapping deferred to v2

Two things in the design are still "coming soon" because they need
newserv-side work:

1. **Quest completion stats.** Per-quest "who completed this" + per-
   player "what have I completed" both require new endpoints on
   newserv that walk the saved character files and read their
   `quest_flags` arrays (offset `0x460` in the character struct).
   Plan: re-fork newserv when ready, add `GET /y/accounts/<id>/
   quest-completions` + `GET /y/data/quests/<num>/completions`,
   submit upstream as a small PR.
2. **Rare drop ticker live data.** newserv exposes `WS /y/rare-drops
   /stream` already; the dashboard backend just needs a WebSocket
   proxy hop. Not in v1 because the WS bridge is more involved than
   plain HTTP forwarding.

The frontend renders mock data for both so the page is complete-looking
in the meantime.

## Local development

```bash
# Install deps
cd dashboard
npm install

# Start the backend pointed at a local newserv (optional — without
# newserv running, you'll see mock data with API errors in the console).
NEWSERV_API=http://localhost:8081 npm run dev
```

Then open <http://localhost:8080>.

If you just want to look at the design, opening `index.html` directly
in a browser works too — the mock data is the fallback for anything
the API can't supply.

## Deployment

1. Push to `main`. GitHub Actions:
   - `.github/workflows/build-dashboard.yml` rebuilds the container image
     on any change under `dashboard/**` and pushes
     `ghcr.io/joshkautz/pso-dashboard:main`.
   - `.github/workflows/deploy.yml` pulls the new image onto the
     Lightsail instance and runs `docker compose up -d`.

2. Open `pso.joshkautz.com` (or whatever DNS you point at the Lightsail
   IP).

For HTTPS, the recommended path is proxying the domain through
Cloudflare — they terminate HTTPS at their edge and connect back to
your Lightsail box over plain HTTP. Zero server-side cert management.
If you'd rather not use Cloudflare, add a Caddy or nginx sidecar to
`docker-compose.yml` later; nothing about the current setup changes
either way.

## Files

- `Dockerfile` — Node 22 alpine. Builds in CI.
- `package.json` — express only.
- `server.js` — backend (proxy + allowlist + static serving).
- `index.html` — frontend (single self-contained file).
- `README.md` — this file.
