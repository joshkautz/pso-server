# Server runtime

The newserv-specific bits that ship to the Lightsail instance. The
service definitions (`docker-compose.yml`) and TLS config (`Caddyfile`)
live one level up, at the repo root — see [`../README.md`](../README.md)
for the full stack.

## Files

- **`config.json`** — the only file you'll regularly edit. Full newserv
  config, vendored from upstream `config.example.json` with our overrides
  applied (server name, addresses, welcome message, `HTTPListen` for the
  REST API). Diffs from upstream are intentionally small so future
  upstream changes are easy to merge.
- **`cloud-init.sh`** — first-boot setup (installs Docker, makes
  directories). Runs *once* per instance via Lightsail's user-data hook.
  Lightsail only accepts shell scripts for user_data, not cloud-init
  YAML, so this is plain bash even though the name suggests otherwise.
- **`backup/`** — `pso-backup.sh` + systemd timer/service unit files.
  Installed by `deploy.yml` under `/usr/local/bin/` and `/etc/systemd/system/`,
  runs nightly, tarballs `/home/ubuntu/pso-server/system/` to S3.

## How a deploy works

The `.github/workflows/deploy.yml` workflow, on every push to `main` that
touches `server/**`, `dashboard/**`, `docker-compose.yml`, `Caddyfile`,
or `deploy.yml` itself:

1. Looks up the instance's public IP via `aws lightsail get-instance`.
2. `scp`s `docker-compose.yml` + `Caddyfile` (both repo-root) to
   `/home/ubuntu/pso-server/` on the instance.
3. `docker compose pull` to fetch the latest images (`pso-server:main`,
   `pso-dashboard:main`, `caddy:2-alpine`).
4. Reads `org.opencontainers.image.revision` off the newserv image with
   `docker inspect`, writes `NEWSERV_REV=<sha>` to `.env` so the dashboard
   can show "newserv abc1234 (up to date)" via `/api/build`.
5. Seeds `/home/ubuntu/pso-server/system/` with the image's bundled
   `system/` files (no-clobber, so our overrides win).
6. Substitutes the actual public IP into `config.json` (`LocalAddress` +
   `ExternalAddress` — `0.0.0.0` in the repo).
7. `rsync`s `server/` to `/home/ubuntu/pso-server/system/` (overrides
   land here).
8. `docker compose up -d --remove-orphans` brings the stack up.
9. Installs the backup systemd timer if not already running.

No rebuild, no instance recreation. The container restart picks up
config.json changes automatically; you can also reload without restart
(see *Editing config.json* below).

## Adding custom quests

Drop `.bin`/`.dat` files into `quests/<category>/` here (matching the
upstream layout under `system/quests/`). They get rsynced and picked up
on the next deploy. Or, for live updates without a redeploy (the interactive
shell isn't reachable in Docker, so signal the running process):

```bash
ssh ubuntu@<instance-ip>
docker kill --signal SIGUSR2 newserv  # reload config + quests + everything
```

## Editing config.json

newserv accepts JSON with C++-style comments and hex integer literals.
Don't run it through a strict JSON formatter — it will mangle the hex
numbers and strip the comments. The repo's `.gitignore` does not touch
this file, so just edit and commit.

After editing, you can apply without restarting the container:

```bash
ssh ubuntu@<instance-ip>
docker kill --signal SIGUSR1 newserv  # reloads config.json only
# or
docker kill --signal SIGUSR2 newserv  # reloads config + quests + everything
```
