# Installing community quest packs

newserv ships with 260 quests in its base `system/quests/` directory. About
245 of those are Sega's original content and 11 are community-distributed
quests under `download/` (CategoryID 21, surfaced as **Community** on the
dashboard). This document covers how to add more community packs.

## Where quest files live

```
server/quests/<category>/qNNN-<version>-<lang>.bin
server/quests/<category>/qNNN-<version>.dat
```

- `server/quests/<category>/` in the repo is rsynced to
  `/home/ubuntu/pso-server/system/quests/<category>/` on the Lightsail box
  during deploy.
- Inside the container that path is `/newserv/system/quests/<category>/`.
- newserv picks up new files on `reload quest-index` (no restart needed).

The `<category>` directory determines how the quest is classified:

| Directory | CategoryID | Dashboard "Source" |
|---|---|---|
| `download/` | 21 | **Community** (matches the community-pack convention) |
| `government-ep1/`, `government-ep2/`, `government-ep4/` | 18, 19, 20 | Official |
| `extermination/`, `retrieval/`, `events/`, `vr/`, `tower/`, `solo-story/`, `solo-extra/`, `team/`, `shops/` | 2-17 (per `config.example.json`) | Official |
| `hidden/` | 1 | (excluded from the public library) |

For brand-new packs from the wider community, **`download/` is the right
home** — that's the bucket the dashboard expects and what other server
operators use for community-distributed content.

## File naming convention

```
qNNN-XX-Y.bin    BIN script file for quest N, version XX, language Y
qNNN-XX.dat      DAT enemy/map file for quest N, version XX (all languages)
```

- `NNN` — a quest number unique within the version. Avoid colliding with
  existing quests (`grep -r "QuestNumber" /home/ubuntu/pso-server/system/
  quests/` will tell you what's taken).
- `XX` — version family: `gc` (GameCube), `xb` (Xbox), `bb` (Blue Burst),
  `pc` (PC), `dc` (Dreamcast).
- `Y` — language: `e` (English), `j` (Japanese), `d` (German),
  `f` (French), `s` (Spanish), `k` (Korean), etc. Omit `-Y` on the
  `.dat` since enemy/map data is language-agnostic.

Examples:

```
q205-gc-e.bin   English BIN for quest 205, GameCube
q205-gc-j.bin   Japanese BIN for quest 205, GameCube
q205-gc.dat     Shared DAT for quest 205, GameCube
```

## Recommended packs to install

### 1. Schtserv 42-quest pack (easiest)

- **Source**: <https://schtserv.com/forums/viewtopic.php?t=1284>
  (forum login may be required to grab the attachment)
- **Format**: Already `.bin`/`.dat` — drop-in, no decode step
- **Count**: 42 GC-targeted quests
- **Examples**: "Below the Waves", "Buried Relics",
  "Schtserv Spring Cleaning"

Install:

```bash
# On your laptop, after downloading and unzipping the pack:
mkdir -p server/quests/download
cp path/to/schtserv-pack/*.bin server/quests/download/
cp path/to/schtserv-pack/*.dat server/quests/download/

# Verify nothing collides with existing quest numbers:
ls server/quests/download/ | sort

git add server/quests/download/
git commit -m "quests: install Schtserv 42-quest pack"
git push
```

Deploy runs, the pack lands at
`/home/ubuntu/pso-server/system/quests/download/`, newserv restarts, the
dashboard's Community filter chip count jumps by 42.

### 2. b0n3zx PSOquest (32 quests, requires decode)

- **Source**: <https://github.com/b0n3zx/PSOquest> — folder
  `Quests/psogc_quests/`
- **Format**: `.gci` (GameCube memory card download-quest dumps)
- **Count**: 32 quests, `8P-GPOE-PSO______006.gci` through `037.gci`
- **Note**: Some overlap with Sega's bundled download quests; some are
  item-creator / cheat quests — review before install.

The `.gci` format is GameCube memory card images. newserv ships with a
`decode-gci` subcommand that extracts the `.bin`/`.dat` pair. Run it
once per file:

```bash
# On your laptop with newserv built locally — see fuzziqersoftware/newserv
# README for build instructions. Alternatively run inside the deployed
# container:
ssh ubuntu@$(terraform -chdir=infra output -raw instance_public_ip)
docker exec -it newserv sh

cd /tmp
git clone --depth=1 https://github.com/b0n3zx/PSOquest.git pack
mkdir converted

for f in pack/Quests/psogc_quests/*.gci; do
  /newserv/newserv decode-gci "$f"
done
mv pack/Quests/psogc_quests/*.bin pack/Quests/psogc_quests/*.dat converted/

# Inspect — drop cheat/item-creator entries if you don't want them.
# Then renumber to avoid quest-number collisions before copying into
# the live quests dir:
#   for f in converted/*.bin; do mv "$f" "$(...)"; done

cp converted/*.bin converted/*.dat /home/ubuntu/pso-server/system/quests/download/
docker exec newserv newserv reload quest-index
```

For a cleaner workflow, do the decode + rename steps on your laptop and
commit the final `.bin`/`.dat` pairs to `server/quests/download/` so they
flow through the standard rsync deploy path.

### 3. PSO Palace (Aleron Ives, scattered)

- **Source**: <https://psopalace.sylverant.net/downloads_gamecube.html>
  (patches only — quest threads are at <https://psopalace.forumotion.com/>)
- **Format**: Mostly `.qst` (use `newserv decode-qst` to get
  `.bin`/`.dat`)
- **Count**: Dozens of quests authored / modified by Aleron Ives over
  ~15 years; distributed one-per-forum-thread.

PSO Palace is worth a second pass once the easy wins are in. The
per-quest manual download makes it tedious as a first install but the
quality is high.

## Decoding non-native formats

newserv has first-class decoders for the formats you'll encounter
(see upstream README's "decode-*" subcommands):

| Input | Command |
|---|---|
| `.gci` (with or without encryption) | `newserv decode-gci FILE.gci` (use `--seed=HEXSERIAL` if encrypted) |
| `.qst` (online or download) | `newserv decode-qst FILE.qst` |
| `.dlq` | `newserv decode-dlq FILE.dlq` |
| `.vms` (Dreamcast) | `newserv decode-vms FILE.vms` |

All emit `.bin`/`.dat` pairs ready to drop into the quest directory.

newserv does **not ingest `.qst` directly at runtime** — convert first,
then drop the `.bin`/`.dat` into a category directory.

## Reloading the quest index

After dropping new files, the server picks them up without a restart:

```bash
ssh ubuntu@<instance-ip>
docker exec -it newserv newserv  # opens the interactive shell
# in the shell:
reload quest-index
```

Or send a signal from outside the shell:

```bash
docker kill --signal SIGUSR2 newserv  # full reload (config + quests + everything)
docker kill --signal SIGUSR1 newserv  # config-only — will NOT pick up new quests
```

Games already in progress keep the old version of any modified quest
until they end.

## Verifying after install

1. **Dashboard chip count**: <https://pso.joshkautz.com/#quests> — the
   "Community" filter chip count should reflect the new total. Refresh
   if it doesn't update (the page polls every 15s but a hard refresh
   forces a fresh `/api/quests` fetch).
2. **In-game**: connect with PSO, go to the quest counter, pick the
   "Download" / "Community" category, look for the new entries.
3. **Server logs** on the host: `docker logs newserv --tail=50 | grep -i
   quest` shows the reload result. Corrupt or unknown-format files are
   logged but don't fail startup.

## Notes on legality + redistribution

Most fan-made PSO quests have unclear or unstated redistribution
licenses. Treat each pack on its own terms:

- **Sega-original quests dumped from discs** (the bulk of b0n3zx's set,
  the "official Sega download quests" portions of community archives)
  are technically Sega's IP. The PSO private-server community has
  operated on a no-takedown gentleman's-agreement basis for two
  decades, but distributing them in a *public* GitHub repo carries
  some risk. The upstream `fuzziqersoftware/newserv` repo ships a
  curated set; everything beyond that is the operator's call.
- **Genuinely fan-authored quests** (Schtserv pack, PSO Palace's
  Aleron Ives quests, named community releases) are typically
  free-to-redistribute within the PSO server community; check the
  pack's README or forum thread before committing to a public repo.
- The safe move is to keep large packs as deploy-time pulls from
  external sources (decode + drop into `download/` on the
  Lightsail box directly) rather than committing them to this repo.
