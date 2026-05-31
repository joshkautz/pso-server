# Dashboard

Public-facing status + quest browser for the PSO Josh server.

Open `index.html` in any modern browser. The prototype currently runs on
mock data; the real newserv REST API integration points are commented
inline in `<script>` so you can see where each section's data comes from.

## Design principles

- **Tasteful Pioneer-2 aesthetic, not nostalgia cosplay.** Deep navy
  surfaces, cyan as the primary, magenta as the rare-drop accent. The
  Orbitron display font carries the sci-fi flavor in headings; Inter
  handles all body copy for legibility; JetBrains Mono for numbers
  and codes.
- **WCAG 2.1 AA throughout.** Foreground/background pairings tested at
  ≥7.6:1 for body text. Focus rings via `:focus-visible` are present
  on every interactive element. Semantic HTML — `<header>`,
  `<main>`, `<section>`, `<article>`, `<nav>`, `<footer>`,
  `<fieldset>` + `<legend>` for chip groups, `<dl>` for the
  identity panel. ARIA only where semantics aren't enough
  (`aria-live` for the rare-drop ticker and metric counters,
  `aria-pressed` for chip-style toggles, `aria-current` for nav).
- **Keyboard reachable.** Tab order matches visual order. Quest cards
  are focusable via `tabindex="0"`. Skip-link at the top.
- **Honours `prefers-reduced-motion`.** Pulse animations and
  transitions collapse to ~0ms.
- **Works without JS.** Static content is in the HTML; JS only
  hydrates dynamic sections.
- **Mobile-first.** Single-column under 720px; the layout grows into
  a 12-column grid as space allows.

## Sections

1. **Top bar** — server name, status pill (live state), nav.
2. **Hero** — server description + identity card (host/port/region/build).
3. **Live** — four metric cards + active games panel + rare-drop ticker.
4. **Quest library** — search, filter by episode + source, grid of
   quest cards with completion progress.
5. **What this server supports** — features grid.
6. **Joining** — three-step setup pointing at the client setup docs.

## Mapping mock data → real newserv REST API

| UI section | API endpoint | Notes |
|---|---|---|
| Metric: Hunters online | `GET /y/summary.connected_clients` | Or count from `/y/clients` |
| Metric: Active games | `GET /y/summary.active_games` | Or count from `/y/lobbies` |
| Metric: Registered accounts | `GET /y/summary.account_count` | |
| Metric: Available quests | `GET /y/data/quests` | Count the response |
| Active games panel | `GET /y/lobbies` | Filter for `is_game === true` |
| Rare drop ticker | `WS /y/rare-drops/stream` | Push events arrive as JSON |
| Server identity | `GET /` + `GET /y/server` | Build date, revision, host |
| Quest library | `GET /y/data/quests` | Returns metadata for every quest |

## Quest completion tracking

The dashboard mockup shows per-quest completion counts (e.g. "38 of 42
accounts"). **This data is not exposed by newserv's current REST API.**

To make it real, you have two paths:

1. **Extend newserv with a new endpoint.** Quest completion flags
   are tracked in BB character files (and per-game flag state for
   v1/v2/GC). Adding `GET /y/data/quests/<id>/completions` that
   walks the account database and counts completions would be a
   small PR to newserv. This is the right long-term move and
   useful upstream.

2. **Derive from server logs.** newserv emits structured log lines
   when quests start and end. A tiny log-tailing service on the
   server could write per-quest completion counters into a small
   SQLite DB the dashboard reads from.

Path 1 is correct; path 2 is faster to ship.

## Wiring up the real API (when ready)

newserv's REST API is **off by default** because two endpoints
(`/y/accounts`, `/y/shell-exec`) leak sensitive data or execute
arbitrary code. To enable it safely:

1. In `pso-server/server/config.json`, add an `HTTPListen` entry
   bound to localhost only:

   ```json
   "HTTPListen": ["127.0.0.1:8080"]
   ```

   Or, if you're running newserv inside Docker on Lightsail and the
   dashboard backend is on the same host, you can use the docker
   bridge address. Either way: do not bind to `0.0.0.0`.

2. Stand up a small backend on the same Lightsail instance (Node,
   Python, Caddy with reverse-proxy + JSON transform, whatever) that:
   - Polls or proxies the safe endpoints (`/y/summary`,
     `/y/lobbies`, `/y/data/quests`)
   - Exposes a public-facing whitelist to the dashboard
   - Strips PII (player real-name fields, IPs)
   - Never proxies `/y/accounts` or `/y/shell-exec`

3. In `index.html`, replace the `MOCK_*` constants and uncomment the
   `refresh()` + WebSocket setup. The renderers (`renderGames`,
   `renderDrops`, `renderQuests`) are written to accept the API's
   actual data shapes — minimal adapter code.

## Hosting

A few realistic options:

- **Same Lightsail instance, served from nginx/Caddy alongside the
  dashboard backend.** Simplest. One certificate to manage.
- **Cloudflare Pages or GitHub Pages** with the dashboard backend
  exposed via a separate small subdomain. Free tier covers it; CDN
  edge caching helps if the dashboard gets shared.
- **Bundled into newserv's static directory.** newserv has a
  `static/` directory; you could PR an "optional dashboard" target.

## Not yet built but worth considering

- **Episode 3 card browser.** newserv's API has
  `/y/data/ep3-cards` — there's a whole card game in there for
  someone who wants to surface it.
- **Per-player public profile.** Opt-in only — let a hunter
  generate a shareable URL showing their character + quest
  completions + favourite rare drop.
- **Discord webhook for rare drops.** Same WebSocket the dashboard
  uses can also feed a Discord bot.
- **Weekly leaderboard.** Top hunters by quest completions, longest
  online time, biggest rare-drop find.

## Files

- `index.html` — the entire dashboard, self-contained.
- `README.md` — this file.

When the design is locked, split `index.html` into separate
`index.html`, `styles.css`, `app.js`, and add a build step (Vite is
overkill; a one-line bundler is fine).
