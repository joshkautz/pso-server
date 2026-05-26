# Server runtime

What runs on the Lightsail instance.

## Files

- **`config.json`** — the only file you'll regularly edit. Full newserv
  config, vendored from upstream `config.example.json` with our overrides
  applied (server name, addresses, welcome message). Diffs from upstream
  are intentionally small so future upstream changes are easy to merge.
- **`docker-compose.yml`** — runs the prebuilt `ghcr.io/joshkautz/pso-server`
  image with `./` bind-mounted at `/newserv/system` inside the container.
- **`cloud-init.yaml`** — first-boot setup (installs Docker, makes
  directories). Runs *once* per instance via Lightsail's user-data hook.

## How a deploy works

The `.github/workflows/deploy.yml` workflow, on every push to `main` that
touches `server/**`:

1. Looks up the instance's public IP via `aws lightsail get-instance`.
2. `rsync`s the contents of `server/` to `/home/ubuntu/pso-server/system/`
   on the instance (so `config.json` lands at
   `/home/ubuntu/pso-server/system/config.json`, which docker-compose
   mounts into the container at `/newserv/system/config.json`).
3. SSHes in and runs `docker compose pull && docker compose up -d`.

That's the whole deploy. No rebuild, no instance recreation.

## Adding custom quests

Drop `.bin`/`.dat` files into `quests/<category>/` here (matching the
upstream layout under `system/quests/`). They get rsynced and picked up
on the next deploy. Or, for live updates without a redeploy:

```bash
ssh ubuntu@<instance-ip>
docker exec -it newserv newserv  # opens the interactive shell
# in the shell:
reload quest-index
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
