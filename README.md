# pso-server

A personal [newserv](https://github.com/fuzziqersoftware/newserv) deployment
on AWS Lightsail, so I can host Phantasy Star Online Episode I & II Plus
multiplayer for friends running Batocera + Dolphin.

This repo is everything needed to stand up, deploy, and operate the server.

```
├── infra/                   Terraform — Lightsail instance, static IP,
│                            firewall rules, GitHub OIDC role
├── server/                  Runtime — docker-compose, newserv config.json,
│                            cloud-init for first-boot setup
├── scripts/bootstrap.sh     One-time bootstrap (S3 state bucket)
├── docs/client-setup.md     How players configure Batocera + Dolphin
└── .github/workflows/
    ├── infra.yml            terraform plan on PR, apply on main
    ├── build-image.yml      builds & pushes newserv image to GHCR
    └── deploy.yml           rsync config + docker compose up on instance
```

## Architecture

```
Friend's Batocera + Dolphin
  └── PSO GC Plus (Rev 2)
       └── DNS: AWS_LIGHTSAIL_STATIC_IP
            │
            ▼
       UDP 53 (newserv DNS)             ─┐
       TCP 9103 (newserv game server)   ─┼─→  Lightsail instance (ubuntu_24_04)
                                          │     └── Docker
                                          │          └── ghcr.io/joshkautz/pso-server:main
                                          │               └── newserv binary
                                          │                    └── /newserv/system/  ← bind-mounted from ./server/
                                          │                         ├── config.json
                                          │                         ├── accounts/    (player data, persisted on host)
                                          │                         └── ...
                                          └─ (snapshots → daily Lightsail backup)
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

## Security notes

- The `production` GitHub Environment is referenced in workflows. **Add
  yourself as a required reviewer in repo settings** to gate `apply` and
  `deploy` behind a manual approval click.
- The IAM role granted to GH Actions has `lightsail:*` and broad S3
  access. Narrow if you care; see [`infra/README.md`](infra/README.md).
- UDP 53 defaults to open to the world. To prevent your DNS server from
  being abused for reflection, set `allowed_dns_cidr` in
  `terraform.tfvars` to a comma-separated list of your friends' public
  IPs (or `203.0.113.0/24` etc).
- Account data lives at `/home/ubuntu/pso-server/system/accounts/` on the
  Lightsail instance. Daily snapshots cover this. For extra paranoia,
  add a cron that uploads `accounts/` to S3.

## Upstream

newserv: https://github.com/fuzziqersoftware/newserv (MIT). Upstream
README is the canonical reference for everything PSO-specific.

This repo is just the deployment glue around it.
