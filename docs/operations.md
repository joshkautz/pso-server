# Operations runbook

Day-to-day tasks for running and modifying the pso-server. Read top to
bottom or jump to the section you need.

- [Glossary](#glossary)
- [Daily user tasks](#daily-user-tasks) — adding friends, editing config, viewing logs
- [Server admin in PSO](#server-admin-in-pso) — chat commands, granting yourself admin
- [Backups and restore](#backups-and-restore)
- [Modifying the server](#modifying-the-server) — quests, lobby tweaks, welcome message
- [Upgrading newserv](#upgrading-newserv)
- [Cost management](#cost-management)
- [Emergency recovery](#emergency-recovery)
- [Things you should know but probably never need](#things-you-should-know-but-probably-never-need)

---

## Glossary

| Term | What it means here |
|---|---|
| **The instance** | The single AWS Lightsail VM running newserv (currently `pso-server` in `us-east-1`) |
| **The image** | The `ghcr.io/joshkautz/pso-server:main` Docker image, built from upstream `fuzziqersoftware/newserv` |
| **The bucket** | One of two S3 buckets: `pso-server-tfstate-...` (Terraform state) or `pso-server-backups-...` (nightly backups) |
| **The role** | The `github-actions-pso-server` IAM role that GH Actions assumes via OIDC to talk to AWS |
| **A deploy** | Anything that pushes new code/config to the instance. Triggered automatically on push to `main` |

## Mental model

There are three independent change cadences:

1. **Infra changes** (anything under `infra/`): change the cloud resources themselves — instance size, firewall rules, IAM. Push → `infra.yml` runs → `terraform plan` posts on the PR → merge → `terraform apply`.
2. **Server runtime changes** (anything under `server/`): change `config.json`, add quests, edit the backup script. Push → `deploy.yml` runs → rsyncs to instance → restarts container.
3. **newserv version bumps** (rare): bump the upstream ref in `build-image.yml`. Push → `build-image.yml` rebuilds image → `deploy.yml` auto-fires on `workflow_run` → instance pulls new image.

You don't need to know any of the implementation details to use the day-to-day commands below. They all assume you've cloned the repo and have `gh` authed; nothing else.

---

## Daily user tasks

### Edit the server config

`server/config.json` is a vendored copy of upstream's `config.example.json` with our local edits. Edit any field, push, automatic deploy:

```bash
$EDITOR server/config.json   # change something
git add server/config.json
git commit -m "config: <what you changed and why>"
git push
```

The deploy reloads the container. Most fields take effect on container restart (a few seconds of downtime). A few fields require an image rebuild — those are clearly marked in upstream's `README.md`.

If you only want to reload config without restarting the container, SSH to the instance and signal newserv:

```bash
ssh -i ~/.ssh/pso-server-deploy ubuntu@<instance-ip>
docker kill --signal SIGUSR1 newserv     # reload config.json only
docker kill --signal SIGUSR2 newserv     # reload config + quests + everything
```

### Add a friend's IP to the DNS allowlist

The DNS server (UDP 53) is locked down to known IPs. To add a friend:

1. Get their public IPv4 (have them visit https://ifconfig.io).
2. Edit `infra/terraform.tfvars` (local-only file, not in git):
   ```hcl
   allowed_dns_cidrs = [
     "73.242.54.43/32",  # josh - home
     "1.2.3.4/32",       # <friend name> - <location>
   ]
   ```
3. Apply locally (preferred) or via PR.

   **Locally** (faster, one terminal):
   ```bash
   cd infra
   export AWS_ACCESS_KEY_ID="$(op read 'op://Personal/AWS josh/aws_access_key_id' --account my.1password.com)"
   export AWS_SECRET_ACCESS_KEY="$(op read 'op://Personal/AWS josh/aws_secret_access_key' --account my.1password.com)"
   export AWS_REGION=us-east-1
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

   **Via PR** (preferred when you want a review):
   ```bash
   # since terraform.tfvars is gitignored, edit the example file too,
   # then either push the .tfvars from your laptop locally
   git checkout -b add-friend-jane
   $EDITOR infra/terraform.tfvars.example   # so reviewers see the change
   git commit -am "infra: add jane to dns allowlist"
   gh pr create -t "infra: add jane to dns allowlist" -b ""
   ```

The friend can connect within ~30 seconds of `apply` completing.

### View server logs

```bash
ssh -i ~/.ssh/pso-server-deploy ubuntu@<instance-ip>
docker logs -f newserv                 # tail live
docker logs --since=1h newserv         # last hour
docker logs --tail=200 newserv         # last 200 lines
```

You can also `journalctl -u docker` for container lifecycle events.

### Check who's online

In PSO, use `$li` while you're in a lobby. From the shell:

```bash
ssh ... ubuntu@<ip>
docker exec -it newserv newserv   # opens the interactive shell
# in the shell:
help                # see all commands
list-accounts       # all registered accounts
list-clients        # who's currently connected
```

### Restart the server (planned downtime)

```bash
ssh -i ~/.ssh/pso-server-deploy ubuntu@<instance-ip>
cd /home/ubuntu/pso-server
docker compose restart   # ~5-10 seconds offline
```

### Rotate AWS access keys

If your CLI access keys leak or you just want hygiene:

1. AWS Console → IAM → Users → `josh` → Security credentials → Create access key → CLI use case.
2. Update both fields in the "AWS josh" 1Password item with the new key.
3. Delete the old access key in the AWS console.
4. Done. Nothing on the server needs to change — these are *your* credentials, not the server's.

The dedicated backup IAM user's credentials are managed separately by Terraform; bumping them is automated:

```bash
cd infra
terraform taint aws_iam_access_key.backup
terraform apply
# Then push new credentials to GH secrets:
gh secret set AWS_BACKUP_ACCESS_KEY_ID --body "$(terraform output -raw backup_access_key_id)"
gh secret set AWS_BACKUP_SECRET_ACCESS_KEY --body "$(terraform output -raw backup_secret_access_key)"
# Next deploy will install them on the instance.
gh workflow run deploy.yml --ref main
```

---

## Server admin in PSO

### Grant yourself admin

The first time you connect from PSO, newserv auto-creates an account for your guild card serial number. To give that account admin powers:

```bash
ssh -i ~/.ssh/pso-server-deploy ubuntu@<instance-ip>
docker exec -it newserv newserv
# in the shell:
list-accounts                                 # find your account ID
update-account <account-id> flags=root        # grant root
exit
```

Now in-game you can use `$ann`, `$ban`, `$kick`, `$debug`, etc.

### Useful in-game chat commands

(Full list is in upstream `README.md`. Highlights:)

- `$ann <message>` — server-wide announcement
- `$ban <player>` — ban by guild card number
- `$kick <player>` — disconnect a player
- `$silence <player>` — mute
- `$event xmas|val|halloween|...` — set lobby holiday event
- `$debug` — enable debug mode for your client
- `$si` — show server info (uptime, player count)

---

## Backups and restore

### What's backed up

Everything in `/home/ubuntu/pso-server/system/` — accounts, characters, BB system files, Episode 3 tournament state, the works. Done as a single gzipped tar nightly at 08:15 UTC. Retention is 30 days (configurable via `backup_retention_days` in `infra/variables.tf`).

### Where backups live

S3 bucket `pso-server-backups-<account-id>`, with one object per backup named `newserv-system-<UTC timestamp>.tar.gz`.

### Check that backups are running

```bash
# From your laptop:
export AWS_ACCESS_KEY_ID="$(op read 'op://Personal/AWS josh/aws_access_key_id' --account my.1password.com)"
export AWS_SECRET_ACCESS_KEY="$(op read 'op://Personal/AWS josh/aws_secret_access_key' --account my.1password.com)"
aws s3 ls s3://pso-server-backups-315902154426/ --region us-east-1 --human-readable
```

You should see one new file per day at ~08:15 UTC.

### Manually trigger a backup

```bash
ssh -i ~/.ssh/pso-server-deploy ubuntu@<instance-ip>
sudo systemctl start pso-backup.service
sudo journalctl -u pso-backup.service --no-pager -n 20
```

### Restore from a backup

If you lose data (corrupt save, accidental delete, ransomware, full instance loss):

1. Pick which backup to restore from:
   ```bash
   aws s3 ls s3://pso-server-backups-315902154426/ --region us-east-1
   ```

2. SSH to the instance (or a brand-new one if the old one is gone) and download:
   ```bash
   ssh -i ~/.ssh/pso-server-deploy ubuntu@<instance-ip>
   sudo docker compose -f /home/ubuntu/pso-server/docker-compose.yml down
   sudo aws --region us-east-1 s3 cp \
     s3://pso-server-backups-315902154426/newserv-system-<timestamp>.tar.gz \
     /tmp/restore.tar.gz
   ```

   (You'll need an admin AWS key on the instance for this one-off; the backup user only has write access. The simplest is to `export AWS_ACCESS_KEY_ID=…` from your own credentials before the `aws s3 cp`.)

3. Replace `/home/ubuntu/pso-server/system/`:
   ```bash
   sudo rm -rf /home/ubuntu/pso-server/system
   sudo tar -C /home/ubuntu/pso-server -xzf /tmp/restore.tar.gz
   sudo chown -R 1000:1000 /home/ubuntu/pso-server/system
   ```

4. Restart:
   ```bash
   sudo docker compose -f /home/ubuntu/pso-server/docker-compose.yml up -d
   sudo docker logs --tail=30 newserv    # confirm "Ready" appears
   ```

If you're restoring to a freshly-recreated instance, do the rest of the deploy normally — push a no-op commit or run `gh workflow run deploy.yml` to get the systemd timer reinstalled.

---

## Modifying the server

### Change the welcome message

In `server/config.json`, find `WelcomeMessage` and edit. Use newserv's escape codes (`$C6` for yellow, `\n` for newline). Push to deploy.

### Install custom quests

1. Put quest files under `server/quests/<category>/`, named `q###-<version>-<lang>.bin` and `.dat`. See upstream `README.md` for the naming convention.
2. Push. `deploy.yml` rsyncs them to the instance, but newserv won't pick them up automatically.
3. SSH and reload:
   ```bash
   ssh ... ubuntu@<ip>
   docker exec -it newserv newserv
   # in the shell:
   reload quest-index
   ```

Or restart the container (`docker compose restart`).

### Change the server name

In `server/config.json`, `ServerName` (max 16 chars). Push to deploy. Shows in the lobby's upper-right corner.

### Change which client versions can play together

`CompatibilityGroups` in `server/config.json`. See the comments there — each row is a bit field of which other versions that version's games are joinable from. Push to deploy.

---

## Upgrading newserv

When upstream `fuzziqersoftware/newserv` releases new features or fixes:

```bash
# Find a known-good commit in upstream — usually master HEAD.
gh workflow run build-image.yml -f newserv_ref=master
# Or pin to a specific commit:
gh workflow run build-image.yml -f newserv_ref=abc1234

# Wait for build (~8 min). deploy.yml auto-fires on success.
gh run watch $(gh run list --workflow=build-image.yml --limit 1 --json databaseId --jq '.[0].databaseId')
```

If the new image breaks something, roll back:

```bash
# Find the previous good SHA tag from a successful build run:
gh run list --workflow=build-image.yml --status=success --limit 5

# Edit server/docker-compose.yml: replace `:main` with the specific sha tag:
#   image: ghcr.io/joshkautz/pso-server:sha-abc1234def0
# Push — deploy pulls the older tag.
```

To make `:main` track an older version, run `build-image.yml` again with the old ref.

---

## Cost management

Current run rate is ~$14/month, dominated by:

| Item | $/mo | How to reduce |
|---|---|---|
| Lightsail Instance (small_3_0, 2GB) | ~$12 | Change `instance_bundle_id` to `nano_3_0` ($5) or `micro_3_0` ($7). PR + merge. |
| Lightsail auto-snapshots | ~$2 | Set `enable_auto_snapshots = false` in tfvars (loses disaster recovery for the whole disk). |
| S3 storage (state + backups) | <$0.10 | Reduce `backup_retention_days` (default 30). |
| GHCR / GH Actions / OIDC / IAM | $0 | n/a |

To downsize the instance to nano:

```hcl
# infra/terraform.tfvars
instance_bundle_id = "nano_3_0"
```

Apply. The instance is *recreated* (not resized in place) — you'll lose any data not in S3 or snapshot. **Run a backup first** and don't be surprised by ~5 minutes of downtime.

---

## Emergency recovery

### Server is unreachable

1. Try SSH: `ssh -i ~/.ssh/pso-server-deploy ubuntu@<ip>`. If it works, you're probably OK — check `docker logs newserv` for crash loops.
2. Lightsail console → Instances → `pso-server`. Status should be "Running". If not, click the instance → Stop → Start.
3. If SSH times out but Lightsail says "Running", the network rules might have changed. Check `infra/main.tf`'s `port_info` blocks. Verify your laptop's IP is still in `allowed_admin_cidr` (defaults to `0.0.0.0/0` so this is unlikely).
4. Worst case: take a snapshot from Lightsail console → create a new instance from it → reattach the static IP. ~5 minutes.

### State drift / Terraform stuck

If Terraform reports the wrong state (e.g., resource exists but TF doesn't know):

```bash
cd infra
terraform refresh    # reconciles state with reality
terraform plan       # see what's actually different
```

If state is locked from a cancelled CI run:

```bash
cd infra
terraform plan       # will show the lock ID
terraform force-unlock <lock-id>
```

### Lost the SSH key

Generate a new one and re-import:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/pso-server-deploy -C 'pso-server deploy' -N ''
# Update terraform.tfvars with the new public key, then:
cd infra && terraform apply
# Update the GH secret:
gh secret set SSH_PRIVATE_KEY < ~/.ssh/pso-server-deploy
```

`aws_lightsail_key_pair` is recreated, but the instance keeps the new authorized key on its `~ubuntu/.ssh/authorized_keys` automatically because Lightsail injects it. *(Actually, you may need to recreate the instance — Lightsail doesn't dynamically add keys to running instances. Test before relying on this in production.)*

### CI is stuck

```bash
# Find runs in unhealthy state
gh run list --status=in_progress
gh run list --status=failure --limit 5

# Cancel something stuck:
gh run cancel <run-id>

# After cancelling, if Terraform left a stale lock:
cd infra && terraform plan   # shows the lock ID
terraform force-unlock <lock-id>
```

---

## Things you should know but probably never need

### Re-bootstrap the whole stack from scratch

If your AWS account is gone and you need to rebuild:

1. Provision a new personal AWS account.
2. Update IAM user credentials in 1Password.
3. `./scripts/bootstrap.sh` (creates new TF state bucket).
4. `cd infra && terraform init -backend-config="bucket=<new-bucket>" -backend-config="region=us-east-1"`
5. `terraform apply` (creates everything from scratch — instance, IPs, role, backup bucket).
6. Reset GH secrets/variables per `infra/README.md`.
7. `gh workflow run build-image.yml` to seed GHCR.
8. Once `deploy.yml` runs, restore your character data from S3 (manually — there's no automated cross-account restore).

### Modify the OIDC role's permissions

`infra/iam-github-oidc.tf`. Adding new AWS service usage to a workflow usually means adding actions to `data.aws_iam_policy_document.github_actions`. Test locally first (`terraform plan` from your laptop) so a misconfig doesn't lock CI out.

### Change the backup schedule

`server/backup/pso-backup.timer`, edit `OnCalendar=`. Push to deploy — `systemctl daemon-reload` happens automatically.

### Move regions

You'd need to recreate everything: TF state bucket, Lightsail instance, static IP, IAM, OIDC role. Update `aws_region` and `availability_zone` in `terraform.tfvars`. Plan will show all resources being destroyed and recreated. Don't do this casually.
