# pso-server

A personal [newserv](https://github.com/fuzziqersoftware/newserv) deployment
on AWS Lightsail — Phantasy Star Online Episode I & II Plus multiplayer for
friends running Batocera + Dolphin, real GameCube + BBA, or desktop Dolphin.

A public status dashboard lives at <https://pso.joshkautz.com> showing server
stats, the quest catalog, and registered players.

This repo is everything needed to stand up, deploy, and operate it.

```
├── infra/                  Terraform — Lightsail instance, static IP,
│                           firewall rules, GitHub OIDC role, S3 backups
├── server/                 newserv runtime — config.json, cloud-init,
│                           backup script + systemd timer/service
├── dashboard/              Public web dashboard — Node/Express backend +
│                           single-file HTML/CSS/JS frontend
├── docker-compose.yml      Services: newserv, dashboard, caddy
├── Caddyfile               TLS + reverse proxy + security headers
├── scripts/bootstrap.sh    One-time bootstrap (S3 state bucket)
├── docs/
│   ├── operations.md       Day-to-day runbook
│   ├── client-setup.md     Players: Batocera + Dolphin
│   └── client-setup-dolphin.md  Players: desktop Dolphin
├── CLAUDE.md               Project context for AI-assisted dev
└── .github/workflows/
    ├── infra.yml           terraform plan on PR, apply on main
    ├── build-image.yml     builds & pushes newserv image to GHCR
    │                       (stamps the upstream SHA in an OCI label)
    ├── build-dashboard.yml builds & pushes dashboard image to GHCR
    └── deploy.yml          ssh + scp configs + docker compose up
```

## Architecture

```
Friend's Batocera + Dolphin          Browser
  └── PSO GC Plus (Rev 2)              └── https://pso.joshkautz.com
       └── DNS: STATIC_IP                   │
            │                               ▼
            ▼                          Caddy 2 (TLS, HSTS, redirects)
       UDP 53 (newserv DNS)            ─┐         │
       TCP 9000-9204 (newserv game)    ─┼─┬───────┘ docker bridge network "internal"
                                         │            │
                                         ▼            ▼
                              Lightsail Instance (ubuntu_24_04)
                               └── Docker compose
                                    ├── newserv (REST :8081 internal-only)
                                    │     └── /newserv/system ← bind-mount from ./server/
                                    └── dashboard (Node/Express)
                                          ├── /          → index.html
                                          ├── /api/*     → allowlisted, sanitised proxy → newserv
                                          └── /api/build → upstream SHA + freshness vs master

                              + daily Lightsail snapshot
                              + nightly S3 backup of /system/
```

**Why Lightsail Instance and not Container Service:**
Lightsail Container Service only exposes HTTP/HTTPS — we need raw UDP 53
and raw TCP, so it's a non-starter. Plain Lightsail Instance runs Docker
just fine.

**Why a vendored config.json instead of overlaying a diff:**
newserv loads a single complete config file, and git diffs of the full
file are more honest than a custom merge layer. Upstream
`config.example.json` is huge but rarely changes.

**Why upstream image + bind-mounted config:**
Config edits don't require an image rebuild. Image is pinned in
docker-compose.yml; bump that line to upgrade newserv.

## Quick start

Pre-reqs: AWS CLI configured for **personal** account, `jq`, `terraform`
1.10+, `gh` CLI, `rsync`, an SSH keypair.

```bash
# 1. Generate the deploy SSH key
ssh-keygen -t ed25519 -f ~/.ssh/pso-server-deploy -C 'pso-server deploy' -N ''

# 2. Bootstrap the TF state bucket and verify AWS identity
./scripts/bootstrap.sh

# 3. Configure Terraform variables
cd infra
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: paste contents of ~/.ssh/pso-server-deploy.pub

# 4. First apply (runs locally; creates the GH OIDC role)
terraform init \
  -backend-config="bucket=pso-server-tfstate-<your-account-id>" \
  -backend-config="region=us-east-1"
terraform plan
terraform apply

# 5. Wire GitHub Actions to AWS
gh secret set SSH_PRIVATE_KEY < ~/.ssh/pso-server-deploy
gh secret set SSH_PUBLIC_KEY < ~/.ssh/pso-server-deploy.pub
gh variable set AWS_ROLE_ARN --body "$(terraform output -raw github_actions_role_arn)"
gh variable set AWS_REGION --body us-east-1
gh variable set TF_STATE_BUCKET --body "pso-server-tfstate-<your-account-id>"
gh variable set LIGHTSAIL_INSTANCE_NAME --body "$(terraform output -raw instance_name)"

# 6. Trigger first image build + deploy
gh workflow run build-image.yml
# then once that succeeds, deploy.yml will fire automatically.

# 7. Give the IP to friends
terraform output instance_public_ip
```

Players follow [docs/client-setup.md](docs/client-setup.md).

## Ongoing changes

- **Edit `server/config.json`** → push to `main` → `deploy.yml` rsyncs and
  reloads
- **Edit `infra/**.tf`** → open PR → see plan as PR comment → merge →
  `infra.yml` applies
- **Bump newserv** → re-run `build-image` workflow (optionally with a
  specific upstream ref) → `deploy.yml` picks up the new `:main` tag

## Costs (us-east-1, USD/month)

| Item | Cost |
|---|---|
| Lightsail Instance (`small_3_0`, 2GB) | ~$12 |
| Static IP (attached) | $0 |
| Lightsail Auto Snapshots | ~$2 |
| S3 state bucket | <$0.10 |
| GHCR public image storage | $0 |
| GitHub Actions (public repo) | $0 |
| **Total** | **~$14/mo** |

Drop to `nano_3_0` ($5) if you want to gamble on 512MB being enough for
your player count.

## Documentation

| Doc | Audience |
|---|---|
| [`docs/operations.md`](docs/operations.md) | Day-to-day operator. Adding friends, editing config, viewing logs, granting in-game admin, restoring from backup, upgrading newserv, cost management, emergency recovery |
| [`docs/client-setup.md`](docs/client-setup.md) | Each player on Batocera + Dolphin (handhelds, HTPCs) |
| [`docs/client-setup-dolphin.md`](docs/client-setup-dolphin.md) | Each player on desktop Dolphin (macOS / Windows / Linux) |
| [`docs/community-quests.md`](docs/community-quests.md) | Operator. How to install fan-made quest packs on top of the 260 quests newserv ships with |
| [`dashboard/README.md`](dashboard/README.md) | Anyone touching the public dashboard — architecture, allowlist, sanitisers, build pipeline |
| [`infra/README.md`](infra/README.md) | Anyone bootstrapping this from scratch (e.g. forking) |
| [`server/README.md`](server/README.md) | Understanding what runs on the instance and how |
| [`CLAUDE.md`](CLAUDE.md) | Project context for AI-assisted development sessions |

For PSO mechanics (item drops, quest format, chat commands, etc.), the
upstream [`fuzziqersoftware/newserv`](https://github.com/fuzziqersoftware/newserv)
README is canonical. This repo is just the deployment glue around it.

## Security posture

The infrastructure ships with reasonable defaults baked in:

- **Backups**: Nightly tarball of `/home/ubuntu/pso-server/system/` →
  dedicated S3 bucket with 30-day retention, AES-256 SSE, public access
  blocked, versioning enabled. Backup IAM user has `s3:PutObject` only.
- **DNS allowlist**: UDP 53 is restricted to `allowed_dns_cidrs` in
  `infra/terraform.tfvars` — your home IP only by default. See
  [operations runbook](docs/operations.md#add-a-friends-ip-to-the-dns-allowlist)
  for adding friends.
- **OIDC role**: GH Actions has the minimum AWS actions needed for the
  workflows. Scoped to the specific role, bucket, and user this stack
  owns; not broad `lightsail:*` + `s3:*`.
- **Image tag pinning**: `docker-compose.yml` uses `:main` (latest from
  upstream master), but every build also pushes a `:sha-XXXX` tag for
  rollback.
- **Dashboard exposure**: the dashboard backend proxies only a strict
  allowlist of newserv GET routes (`/y/summary`, `/y/lobbies`, `/y/server`,
  `/y/data/quests`, `/y/accounts`) with per-route sanitisers that strip
  account IDs, IPs, sessions, PSO serial numbers, ban times, and other
  PII before responses leave the backend. newserv's REST API (port 8081)
  is **never** published to the host or the public internet — it's only
  reachable from sibling containers on the docker bridge network.
- **TLS**: Caddy 2 sidecar (`caddy:2-alpine`) terminates HTTPS via Let's
  Encrypt and auto-renews. HSTS, X-Frame-Options, X-Content-Type-Options,
  Referrer-Policy, and Permissions-Policy headers are set. Caddy listens
  on 80 + 443; 80 is required for the ACME HTTP-01 challenge plus the
  HTTP → HTTPS redirect.

Worth doing manually:

- **Add yourself as a required reviewer** for the `production` GitHub
  Environment (Settings → Environments → production → Required reviewers).
  Gates infra `apply` and `deploy` behind a manual click — your only
  defense against a bad commit auto-deploying.
- **Rotate the IAM CLI password** if you ever pasted it somewhere it
  shouldn't have lived.
