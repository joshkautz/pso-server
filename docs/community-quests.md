# Installing community quest packs

newserv ships with 260 quests in its base `system/quests/` directory. A
deep audit (see `dashboard/quest-provenance.json` for the per-quest
catalog) confirmed the binary classification: **258 are Sega-authored
("original"), 2 are community-authored ("custom")**. The 2 custom
entries are:

- `q000` "Tower Mop Up 3/11/06" by soulja224466 (GameCube modding scene,
  2006) — preserved in fuzziqersoftware's pso1212 archive.
- `q253` "Story Flag Fixer" by Matt Swift (2024) — newserv-bundled
  utility quest to unstick offline story progression.

The other 9 entries in the `download/` directory that *appear* community
on first glance are actually Sega's DC-era online download quests
(2000-2003), preloaded on the PSO Plus disc in 2003 and bundled with
newserv since.

If you're looking for *more* community quests beyond those 2, this
document covers the install path. **Honest caveat up front**: the major
community archives (Schtserv, PSO Palace / Aleron Ives) gate their pack
attachments behind forum registration, so installing them is a
manual-action workflow rather than a one-line `curl`.

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

The `<category>` directory determines the in-game quest-menu category
(see `system/config.example.json`'s `QuestCategories` list). It does
**not** determine the dashboard's Original-vs-Custom classification —
that's per-quest data from `dashboard/quest-provenance.json`.

| Directory | CategoryID | In-game menu label |
|---|---|---|
| `government-ep1/`, `government-ep2/`, `government-ep4/` | 18, 19, 20 | "Hero in Red" / "The Military's Hero" / "The Meteor Impact Incident" |
| `extermination/` | 5 | Extermination |
| `retrieval/` | 4 | Retrieval |
| `events/` | 6 | Events |
| `vr/`, `tower/` | 8, 9 | Virtual Reality / Control Tower |
| `solo-story/`, `solo-extra/` | 16, 17 | Story / Solo |
| `team/`, `shops/` | 10, 7 | Team / Shops |
| `challenge-*/`, `battle/` | 11-15 | Challenge / Solo Challenge / Battle |
| `download/` | 21 | Download |
| `hidden/` | 1 | (excluded from menus) |

For brand-new community packs, **`download/` is the right home** —
that's where Sega's online quest distribution went historically and
where private servers have continued to pile community packs since.

To make sure the dashboard surfaces the quest with the correct origin,
add a matching entry to `dashboard/quest-provenance.json` keyed by the
decimal quest number — see the schema docs at the top of that file.

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

### Quest-number ranges to use

newserv's bundled quests already occupy a sparse set of decimal numbers
spread between 0 and 88533. To avoid collisions when adding new packs,
use these free ranges:

| Range | Notes |
|---|---|
| **300–399** | Cleanest first-install block. Plenty of room. |
| **500–599** | Second-best. Use after exhausting 300s. |
| **600–699** | Save for a specific author's pack (e.g. Aleron Ives). |

Avoid: 0, 1-29, 30-37, 50-82, 101-103, 142-179, 187-227, 253, 401-468,
701-712, 8811-8825, 88001+, 88101+, 88201+, 88530+.

### 1. Schtserv community quest archive

- **Source**: <https://schtserv.com/forums/viewtopic.php?t=1284>
- **Format**: Forum attachments, mixed `.qst` (use `newserv decode-qst`)
- **Login required**: yes — Schtserv historically gates attachments
  behind a registered, post-count-verified account. Register at
  schtserv.com, browse to the thread, download the attachment.
- **Count**: variable per thread; the historical "42-pack" number may
  not be the current attachment size — verify after download.

Install:

```bash
# After downloading the attachment via Schtserv forum:
mkdir -p /tmp/schtserv-quests
cd /tmp/schtserv-quests
unzip ~/Downloads/<attachment>.zip

# Decode .qst to .bin/.dat (one per quest)
for f in *.qst; do
  /path/to/newserv-build/newserv decode-qst "$f"
done

# Rename to newserv convention. Inspect each quest's intended number
# via the .bin filename or the in-quest metadata, then renumber into
# the 300-399 range:
#   mv qXXX-gc-e.bin q3NN-gc-e.bin
#   mv qXXX-gc.dat   q3NN-gc.dat

# Drop into the server overlay
cp q3*-gc*.bin q3*-gc*.dat \
   /path/to/pso-server/server/quests/download/

# Add provenance metadata for each new quest in
# dashboard/quest-provenance.json (one entry per number, see schema)

git add server/quests/download/ dashboard/quest-provenance.json
git commit -m "quests: install Schtserv pack (N quests)"
git push
```

### 2. PSO Palace (Aleron Ives + others)

- **Source**: <https://www.pso-palace.com/> (forum) and
  <https://psopalace.sylverant.net/downloads_gamecube.html> (patches)
- **Format**: Per-quest threads with `.qst` attachments
- **Login required**: typically yes
- **Quality**: high (Aleron Ives is a long-time quest creator)
- **Count**: distributed one-quest-per-thread; not packaged as a single
  archive — enumerate manually

Recommended approach: register at PSO Palace, filter the Quests
subforum by Aleron Ives's posts, download each `.qst` you want, decode
with `newserv decode-qst`, renumber into the **600–699** range.

### 3. b0n3zx PSOquest GitHub repo

- **Source**: <https://github.com/b0n3zx/PSOquest> — folder
  `Quests/psogc_quests/`
- **Format**: `.gci` (GameCube memory card download-quest dumps)
- **Login required**: no — public GitHub repo
- **Count**: 32 files
- **Important caveat**: most of these are *Sega-original DC download
  quests* (the same q050-q082 series already bundled with newserv), not
  fan-made content. Plus a few item-creator / cheat quests. Filter
  carefully before install.

```bash
git clone --depth=1 https://github.com/b0n3zx/PSOquest.git
cd PSOquest/Quests/psogc_quests

# Decode all
for f in *.gci; do
  /path/to/newserv-build/newserv decode-gci "$f"
done

# Inspect the resulting .bin files for quest names. Drop anything that
# duplicates the existing bundle (most of them will), keep genuinely
# new entries. Renumber survivors into 300-399.
```

### Why this is more manual than ideal

Earlier versions of this doc promised one-line installs. The honest
reality after research: **community quest distribution is fragmented
across forum attachments** (Schtserv, PSO Palace) **that gate downloads
behind registered accounts**. There is no curated CC-licensed
GitHub-hosted "PSO community quest collection" you can `curl` in a
script.

That's a community-norms thing, not a tooling problem — pack authors
preserve credit by hosting their work on the forums where they're
known. The install path requires a one-time forum registration per
source.

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
