# Project context for Claude

## What this is

A self-hosted [newserv](https://github.com/fuzziqersoftware/newserv) deployment
on AWS Lightsail — Phantasy Star Online private server for the maintainer's
friends. Plus a public dashboard at <https://pso.joshkautz.com> showing server
status, the quest catalog, and registered players.

Not a fork of newserv; the upstream image is consumed unchanged via GHCR.
"Custom" lives in this repo only — Terraform, Docker compose, the dashboard,
client-setup docs, the deploy pipeline.

## Architecture in one box

```
                      ┌──────── pso.joshkautz.com (HTTPS) ─────────┐
public internet ──────│                                            │
                      │   Caddy 2  →  dashboard (Node/Express)     │
                      │                    │                        │
                      │                    │ /api/* (allowlist)     │
                      │                    ▼                        │
PSO GC client ────────│   newserv (master image from upstream)      │
  via DNS+game ports  │     ├ DNS  :53/udp                          │
                      │     ├ game :9000-9204/tcp                   │
                      │     └ REST :8081 (internal-only)            │
                      │                                            │
                      └────────── Lightsail (small_3_0) ────────────┘
```

## Repository layout

```
infra/                    Terraform — Lightsail instance, static IP, firewall,
                          OIDC role for GH Actions, S3 backup bucket
server/                   newserv-side config — system/ overlay, cloud-init.sh,
                          backup script + systemd timer/service
server/config.json        newserv runtime config. HTTPListen[8081] gives the
                          dashboard backend its REST hop.
dashboard/                Public web UI (see dashboard/README.md)
  index.html              Single-file frontend (HTML+CSS+JS inline)
  server.js               Express backend (proxy + allowlist + sanitisers)
  Dockerfile, package.json
docker-compose.yml        repo-root — services: newserv, dashboard, caddy
Caddyfile                 repo-root — TLS + reverse proxy + security headers
docs/
  operations.md           Day-to-day runbook (admin, backup, restore, costs)
  client-setup.md         Player-facing Batocera + Dolphin guide
  client-setup-dolphin.md Player-facing desktop Dolphin guide
scripts/bootstrap.sh      One-time TF state bucket bootstrap
.github/workflows/
  infra.yml               terraform plan/apply, gated by production env
  build-image.yml         builds newserv image, stamps OCI revision label
  build-dashboard.yml     builds dashboard image
  deploy.yml              scps configs, reads label → .env, docker compose up
```

## Tech stack

| Layer | What | Notes |
|---|---|---|
| Cloud | AWS Lightsail (us-east-1, `small_3_0`, ~$12/mo) | Lightsail Instance, not Container Service — need raw UDP 53 / TCP for game ports |
| IaC | Terraform 1.10+ with S3 state backend | OIDC role for GH Actions |
| CI/CD | GitHub Actions | Path-filtered triggers; deploy via SSH + scp + docker compose |
| Containers | Docker compose on the Lightsail box | One bridge network, no host ports for newserv REST |
| Reverse proxy / TLS | Caddy 2 (caddy:2-alpine) | Auto Let's Encrypt, redirects HTTP → HTTPS |
| PSO server | newserv (fuzziqersoftware/newserv) | Image pinned by tag, upstream master via build-image.yml |
| Dashboard backend | Node 22 + Express 4 | ESM modules, `npm run dev` is `node --watch` |
| Dashboard frontend | Vanilla HTML/CSS/JS, no framework | Single file, no build step |
| DNS | Squarespace (formerly Google Domains) | A record `pso.joshkautz.com` → static IP |

## Conventions

### newserv data shape — PascalCase

newserv emits PascalCase JSON keys: `Server.ClientCount`, `Quests[].Metadata.Episode`,
`a.LastPlayerName`. The dashboard must match what newserv sends — don't pre-
normalise to snake_case anywhere in the adapter or the page silently fails to
populate. There was a long-running bug where the dashboard read
`s.connected_clients` and silently fell back to mock numbers because the real
field was `s.Server.ClientCount`. Don't repeat that.

### No mock data on screen

`MOCK_GAMES` / `MOCK_DROPS` are empty arrays. There used to be hardcoded
`7 hunters online` / `42 accounts` etc. as static HTML; they silently looked
like real numbers when JS broke. Initial render shows empty state or `—`,
which the API overwrites within ~100ms. If the API is down, you see an honest
empty state. Don't reintroduce static placeholders that look like real values.

### Escape user-supplied strings

Quest names, descriptions, player names come from API JSON. They could in
principle contain `<`, `&`, `'`, `"`. Always pass through `escapeHtml()`
before interpolating into `innerHTML`. Don't bypass.

### Sanitisers, not allowlists alone

Every entry in `dashboard/server.js`'s `ALLOWLIST` map has a `strip` function
that mutates the upstream response before it leaves the backend. Even if a
route looks safe, write a sanitiser. Examples of what gets dropped: PSO
serial numbers, access keys, passwords, IP addresses, account IDs, session
tokens, ban times, internal flags.

`/y/shell-exec` and any POST routes are off-limits — adding them is a hard
"talk to me first" change.

### Accessibility

WCAG 2.1 AA contrast. Semantic landmarks (`<header>`, `<main>`, `<section>`,
`<nav>`, `<footer>`). Visible `:focus-visible` rings, never removed.
`prefers-reduced-motion` respected. Quest cards are `role="button"` +
`aria-haspopup="dialog"` + keyboard-activatable. Modal uses native `<dialog>`
for built-in focus trap. Countdown timer refreshes `aria-label` only on day
boundaries — never spam screen readers per second.

### Commit messages

Conventional `area: imperative description`. Body explains *why* (not *what*
the diff already shows). No emoji. No mention of Claude / Claude Code / AI
in commit or PR text — read as if a human engineer wrote it. See per-user
rules in `~/.claude/CLAUDE.md`.

### Git safety

- Never `push --force` to `main`, never `reset --hard` without asking.
- Never disable GPG signing. If the 1Password SSH agent fails, retry the
  same command.
- Never skip pre-commit hooks (`--no-verify`).
- Prefer small focused commits over large ones.

## Build + deploy pipeline

```
git push main
  ├── if dashboard/** changed:
  │     build-dashboard.yml → push ghcr.io/joshkautz/pso-dashboard:main
  │
  ├── if .github/workflows/build-image.yml changed:
  │     build-image.yml → push ghcr.io/joshkautz/pso-server:main + sha-XXXX
  │       (stamps org.opencontainers.image.revision OCI label)
  │
  ├── if infra/** changed:
  │     infra.yml → terraform plan → terraform apply  (gated by production env)
  │
  └── if dashboard/** OR docker-compose.yml OR Caddyfile OR deploy.yml changed:
        deploy.yml → ssh ubuntu@lightsail
                       ├── scp docker-compose.yml + Caddyfile
                       ├── docker compose pull
                       ├── read OCI revision label → write NEWSERV_REV to .env
                       ├── seed system/ (no-clobber)
                       ├── substitute instance IP into config.json
                       ├── rsync server/ overrides
                       ├── docker compose up -d
                       └── install backup systemd timer

# When build-image / build-dashboard completes, deploy.yml fires again via
# workflow_run so the new image is rolled out without a follow-up push.
```

## How `NEWSERV_REV` reaches the browser

The dashboard's identity card shows `newserv abc1234 (up to date)`. The SHA
flow:

1. `build-image.yml` checks out `fuzziqersoftware/newserv` at `master`,
   captures `git rev-parse HEAD`, passes it to `docker/build-push-action`'s
   `labels:` input as `org.opencontainers.image.revision`.
2. `deploy.yml` runs `docker inspect ghcr.io/joshkautz/pso-server:main
   --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}'`,
   writes `NEWSERV_REV=<sha>` to `/home/ubuntu/pso-server/.env`.
3. `docker-compose.yml` interpolates `${NEWSERV_REV:-unknown}` into the
   dashboard's `environment:` block.
4. `dashboard/server.js` reads `process.env.NEWSERV_REV`, surfaces it via
   `/api/build` alongside the upstream master SHA from GitHub (cached 1h).
5. The frontend renders the comparison and links to the GitHub compare view
   if the deploy is behind.

If any step breaks, the identity card shows `newserv —` — never a misleading
value.

## What's deferred to upstream changes

Tracked as separate tasks; mention if relevant during planning.

- **#60 Rare-drops WebSocket bridge** — newserv exposes `WS /y/rare-drops/stream`;
  dashboard needs WS proxy support.
- **#61 Per-quest + per-player completion tracking** — requires newserv-side
  endpoints reading `FlagsArray<0x400>` at offset `0x460` in character files.
  Path forward: re-fork newserv, add `/y/character/<account>/quest-flags` and
  `/y/data/quests/<num>/completions`, PR upstream.
- **#53 Community quest packs** — operational. Drop quest files under
  `server/system/quests/download/`; the existing CategoryID 21 path classifies
  them as "Community" automatically.

## Pointers

- Day-to-day operator stuff (admin commands, backups, costs, recovery):
  `docs/operations.md`
- Player onboarding (set up Batocera + Dolphin, real GameCube + BBA):
  `docs/client-setup.md`, `docs/client-setup-dolphin.md`
- Bootstrap from scratch (fork-ing this stack): `infra/README.md`
- Dashboard architecture, allowlist, build SHA flow:
  `dashboard/README.md`
- Upstream PSO mechanics (drop tables, quest format, chat commands):
  fuzziqersoftware/newserv README is canonical
