# Custom quest catalog — a living document

A version-controlled, growing inventory of **fan-made / community-authored**
Phantasy Star Online Blue Burst (and cross-compatible) quests, where to get
them, and which ones we have actually installed on this server.

> **Scope.** This catalogs *custom* quests — community creations that don't
> ship with retail PSO or with newserv's bundled set. Sega-original quests
> (the ~260 newserv already bundles) are tracked separately in
> [`dashboard/quest-provenance.json`](../dashboard/quest-provenance.json),
> not here.

**Maintained alongside:**
- [`community-quest-sources.md`](community-quest-sources.md) — the procurement
  shopping-list (where to register, what to grab).
- [`community-quests.md`](community-quests.md) — the mechanical install guide
  (file naming, quest-number ranges, deploy path).
- [`dashboard/quest-provenance.json`](../dashboard/quest-provenance.json) — the
  per-quest metadata the dashboard reads to classify Original vs Custom.

---

## How to use / maintain this document

1. **Found a new custom quest?** Add a row to the catalog table below with
   status `catalogued`. Always record a source URL.
2. **Downloaded + verified it parses?** Bump status to `verified` and note the
   internal quest number (`newserv decode-qst` reveals it — see the workflow
   section).
3. **Installed it on the server?** Bump to `installed`, add the assigned
   quest number, and add a matching entry to `quest-provenance.json` so the
   dashboard shows it as Custom with the right author + description.
4. **Couldn't / chose not to install it?** Use `skipped` and say why in Notes
   (licensing, duplicate, broken, login-gated, etc.).

Keep the **changelog** at the bottom current — one line per install batch.

### Status legend

| Status | Meaning |
|---|---|
| `catalogued` | Known to exist; source URL recorded. Not yet downloaded. |
| `downloaded` | File pulled to a staging area, not yet validated. |
| `verified` | Parses cleanly through `newserv decode-qst` / `check-quests`. |
| `installed` | Live in `server/quests/`, deployed, visible on the dashboard. |
| `skipped` | Deliberately not installed — see Notes for the reason. |
| `blocked` | Want it, but can't get it (login wall, dead link, etc.). |

---

## ⚠️ Licensing & provenance — read before bulk-installing

PSO's custom-quest scene has a **20-year norm of sharing quest files across
servers**, but that norm is not uniform, and some servers treat their flagship
custom quests as house content. Before lifting a batch wholesale, sort each
source into one of three buckets:

| Bucket | Posture | Examples |
|---|---|---|
| **Clearly shareable** | Author released it standalone, or it predates any single server and circulates freely. | Aleron Ives's PSO-Palace releases; Matt Swift's newserv contributions; classic Schthack community quests. |
| **Gray — server-branded** | Technically downloadable (e.g. mirrored in an open-source tooling repo) but recognizably **one server's signature content**, authored *for* that server. | Ephinea's "Endless Nightmare", "Phantasmal World", "War of Limits", the "Maximum Attack Ver2 / S / Random Attack Xrd" remix families. |
| **Off-limits** | Explicitly all-rights-reserved, or the author has asked it not be redistributed. | Anything an author has said "don't rip" about. |

**Our policy for this repo:** install the *clearly shareable* bucket freely.
For *gray / server-branded* content, the respectful path is to **ask the
author first** (a Pioneer 2 forum DM costs nothing) rather than silently
re-hosting a competing server's headline quests. Where we do install
gray-bucket quests, we credit the original author + server in the provenance
notes and on the dashboard. Items in this catalog are flagged with a
**Bucket** column so the call is explicit per quest.

> This mirrors the guidance in
> [`community-quests.md`](community-quests.md): downloading publicly-posted
> quest files for a private friends' server is normal; wholesale rehosting of
> another server's branded catalog is a different thing.

---

## Source registry

Where custom quests actually live, and what it takes to get them. Verified
2026-06-18.

| Source | URL | Login? | What's there | Bucket |
|---|---|---|---|---|
| **phantasmal-world** (GitHub) | [DaanVandenBosch/phantasmal-world](https://github.com/DaanVandenBosch/phantasmal-world) `web/assets-generation/.../ephinea/ship-config/quest/` | No | A full mirror of **Ephinea's** Episode 1/2/4 custom quest tree, as tooling test-assets. `.qst`, all verified HTTP 200. **The only substantial no-login source of custom BB quests found.** | Gray (Ephinea-branded) |
| **Pioneer 2 forum** | [pioneer2.net/community](https://www.pioneer2.net/community/) → Quests subforum | **Yes** (free) | The real home of independently-authored community quests. Attachments gated behind a free account. | Mixed — check per author |
| **PSO Palace forum** | [pso-palace.com](https://www.pso-palace.com/) | **Yes** (free) | Aleron Ives's releases + others. Per-quest threads with `.qst` attachments. | Mostly clearly-shareable |
| **MEGA collection** (linked from P2) | mega.nz link in the ["PsoBB Quest Files" thread](https://www.pioneer2.net/community/threads/psobb-quest-files.3126/) | No (MEGA) | A quest collection; contents couldn't be enumerated headlessly. Needs a human with a browser. | Unknown — inspect |
| **qedit.info** | [qedit.info](https://qedit.info/index.php?title=Quests) + hidden `/quests/BB Quest Directory/` tree | No | **Sega-originals only** (EN/JP + fan translations). No custom section (every custom-folder probe 404'd). | N/A (not custom) |
| **b0n3zx / PSOquest** (GitHub) | [github.com/b0n3zx/PSOquest](https://github.com/b0n3zx/PSOquest) | No | 32 GameCube `.gci` — **Sega-original download-quest dumps**, tied to serial/access-key, not BB, not custom. | N/A (not custom) |
| **Tethealla v0.143 set** (in phantasmal-world) | `psolib/src/commonTest/resources/tethealla_v0.143_quests/` | No | 145 `.qst` — the **stock Sega quest set** every BB server ships. Not custom; newserv already bundles equivalents. | N/A (not custom) |
| **Schtserv forums** | schtserv.com | **Yes** | Historically the "42-pack". Threads linked from older guides now 404. | Mixed |
| **PSO Palace (forumotion mirror)** | [psopalace.forumotion.com](https://psopalace.forumotion.com/t13-downloads-custom-quests) | **Yes** | A real "Custom Quests" thread, but **GameCube Ver.1/2 era**, not BB. | Mostly shareable (GC) |
| **psoarchive.neocities** | [psoarchive.neocities.org](https://psoarchive.neocities.org/quests/quests) | No | Dreamcast `.vmi/.vmu`, Sega-originals. Wrong format + not custom. | N/A |

### Tools (not quests, but how you make/inspect them)

| Tool | URL | Use |
|---|---|---|
| newserv (`decode-qst`, `check-quests`, `disassemble-quest-script`) | [fuzziqersoftware/newserv](https://github.com/fuzziqersoftware/newserv) | Validate + inspect any quest file. We run it from the deployed Docker image. |
| Quest Assembler/Disassembler + source | [files.pioneer2.net/quest_asmdisasm.zip](https://files.pioneer2.net/quest_asmdisasm.zip) | Inspect/modify `.bin` scripts. |
| Phantasmal World (browser quest editor) | [DaanVandenBosch/phantasmal-world](https://github.com/DaanVandenBosch/phantasmal-world) | Modern editor; also the mirror source above. |
| PsoQE (quest editor) | [Lemonilla/PsoQE](https://github.com/Lemonilla/PsoQE) | Active QEdit-lineage editor. Tools-only, no bundled quests. |

---

## The catalog

Quest-by-quest inventory. **Bucket** column drives the install policy above.
**#** is the internal quest number (from the file header / `decode-qst`) where
known — note this can collide with existing quests and may be reassigned at
install time. **Status** tracks our own install progress.

### Ephinea custom tree — Episode 1 (via phantasmal-world mirror)

All `.qst`, no-login, verified downloadable. Source path prefix:
`…/ephinea/ship-config/quest/episode_1/guild/`

| Quest | Author/origin | # | Episode | Bucket | Status | Notes |
|---|---|---|---|---|---|---|
| Endless Nightmare #1 | Ephinea | 108 | 1 | Gray | verified | `extermination/`. Decodes clean (2159 B bin + 14628 B dat). Pending owner OK to install. |
| Endless Nightmare #2 | Ephinea | ? | 1 | Gray | catalogued | `extermination/` |
| Endless Nightmare #3 | Ephinea | ? | 1 | Gray | catalogued | `extermination/` |
| Endless Nightmare #4 | Ephinea | ? | 1 | Gray | catalogued | `extermination/` |
| Maximum Attack 1 Ver2 | Ephinea | ? | 1 | Gray | catalogued | `maximum_attack/`. Remix of Sega's MA1. |
| Maximum Attack S E1 | Ephinea | ? | 1 | Gray | catalogued | `maximum_attack/` |
| Random Attack Xrd E1 | Ephinea | ? | 1 | Gray | catalogued | `maximum_attack/` |
| MA4 -1A- / -1B- / -1C- | Ephinea | ? | 1 | Gray | catalogued | `maximum_attack/`. Three-part. |
| Dark Research 2.0 | Ephinea | ? | 1 | Gray | catalogued | `retrieval/` |
| Simulator 2.0 | Ephinea | ? | 1 | Gray | catalogued | `vr/` |
| Mine Offensive | Ephinea | ? | 1 | Gray | catalogued | `vr/` |
| Christmas Fiasco | Ephinea | ? | 1 | Gray | catalogued | `event/`. Seasonal. |
| MAE Caves / Forest / Mines / Ruins | Ephinea | ? | 1 | Gray | catalogued | `event/`. Four area-specific. |

### Ephinea custom tree — Episode 2 (via phantasmal-world mirror)

Source path prefix: `…/ephinea/ship-config/quest/episode_2/guild/`

| Quest | Author/origin | # | Episode | Bucket | Status | Notes |
|---|---|---|---|---|---|---|
| Phantasmal World #1 | Ephinea | ? | 2 | Gray | catalogued | `extermination/` |
| Phantasmal World #2 | Ephinea | ? | 2 | Gray | catalogued | `extermination/` |
| Phantasmal World #3 | Ephinea | ? | 2 | Gray | catalogued | `extermination/` |
| Phantasmal World #4 | Ephinea | ? | 2 | Gray | catalogued | `extermination/` |
| Gal Dal Val's Darkness | Ephinea | ? | 2 | Gray | catalogued | `extermination/` |
| Maximum Attack 2 Ver2 | Ephinea | ? | 2 | Gray | catalogued | `maximum_attack/` |
| Maximum Attack S | Ephinea | ? | 2 | Gray | catalogued | `maximum_attack/` |
| Random Attack Xrd II | Ephinea | ? | 2 | Gray | catalogued | `maximum_attack/` |
| MA4 -2A- / -2B- / -2C- | Ephinea | ? | 2 | Gray | catalogued | `maximum_attack/` |
| Dolmolm Research | Ephinea | ? | 2 | Gray | catalogued | `retrieval/` |
| Christmas Fiasco II | Ephinea | ? | 2 | Gray | catalogued | `event/` |
| MAE CCA / Seabed / Spaceship / Temple / Tower | Ephinea | ? | 2 | Gray | catalogued | `event/`. Five area-specific. |

### Ephinea custom tree — Episode 4 (via phantasmal-world mirror)

Source path prefix: `…/ephinea/ship-config/quest/episode_4/guild/`

| Quest | Author/origin | # | Episode | Bucket | Status | Notes |
|---|---|---|---|---|---|---|
| New Mop-Up Operation #1–#5 | Ephinea | ? | 4 | Gray | catalogued | `extermination/`. Five-part. |
| The Robots' Reckoning | Ephinea | ? | 4 | Gray | catalogued | `extermination/` |
| Point of Disaster | Ephinea | ? | 4 | Gray | catalogued | `extermination/` |
| War of Limits 1–5 | Ephinea | ? | 4 | Gray | catalogued | `extermination/`. Five-part. |
| Maximum Attack 3 Ver2 | Ephinea | ? | 4 | Gray | catalogued | `maximum_attack/` |
| MA4 -4A- / -4B- / -4C- | Ephinea | ? | 4 | Gray | catalogued | `maximum_attack/` |
| Christmas Fiasco IV | Ephinea | ? | 4 | Gray | catalogued | `event/` |

### Independently-authored quests (clearly-shareable bucket)

Quests with clear standalone-author provenance and explicit sharing intent.
**This is the bucket we install without reservation.** Most require a free
forum login to download, hence `blocked` until someone grabs them.

| Quest | Author | # | Episode | Bucket | Status | Notes |
|---|---|---|---|---|---|---|
| (Aleron Ives releases) | Aleron Ives | — | — | Shareable | blocked | PSO-Palace forum, login required. His "Aberrant Grove" is already bundled in newserv as q075. Browse [pso-palace.com](https://www.pso-palace.com/) Quests subforum filtered by author. |
| Subterranean Patrol #3 | Varista | — | 1 | Unknown | blocked | Ephinea June 2026 release. Ask [@Varista on Pioneer 2](https://www.pioneer2.net/community/) if available standalone. |
| Underworld Patrol #1 | Varista | — | 1 | Unknown | blocked | Ephinea June 2026 release. Same as above. |

### Already bundled in newserv (for reference — not re-installed)

These custom quests are **already** present via newserv's base set and tracked
in `quest-provenance.json`. Listed here so we don't double-install.

| Quest | Author | # | Episode | Status |
|---|---|---|---|---|
| Tower Mop Up 3/11/06 | soulja224466 | 0 | 2 | installed (bundled) |
| Aberrant Grove | Aleron Ives (via Matt Swift) | 75 | 1 | installed (bundled) |
| Story Flag Fixer | Matt Swift | 253 | — | installed (bundled) |
| Solo Challenge Ep1 ×9 | Matt Swift | 8811–8819 | 1 | installed (bundled) |
| Solo Challenge Ep2 ×5 | Matt Swift | 8821–8825 | 2 | installed (bundled) |

---

## Install workflow (reference)

Proven end-to-end 2026-06-18. Run newserv from the deployed image — no local
build needed.

```bash
# 1. Download (example: a .qst from the phantasmal-world mirror)
curl -sS -o staging/<name>.qst "<raw-github-url>"

# 2. Validate + reveal the internal quest number
docker run --rm --platform linux/amd64 -v "$PWD/staging:/work" \
  --entrypoint /usr/local/bin/newserv ghcr.io/joshkautz/pso-server:main \
  decode-qst /work/<name>.qst
#   → produces <name>.qst-questNNN.bin  +  <name>.qst-questNNN.dat
#     NNN is the internal quest number — check it against existing quests.

# 3. Rename to newserv's convention + drop into a category dir
#    (see community-quests.md for the naming + free quest-number ranges)
#    e.g. server/quests/download/q3NN-bb-e.bin  + q3NN-bb.dat

# 4. Add a quest-provenance.json entry keyed by the assigned number
#    (classify: "custom", author, sourceUrl, description, episode, …)

# 5. Commit → deploy → newserv reloads the quest index → dashboard shows it
```

Free quest-number ranges (from `community-quests.md`): **300–399** first,
then **500–599**, then **600–699**.

---

## Changelog

| Date | Change |
|---|---|
| 2026-06-18 | Document created. Source registry verified. Ephinea custom tree (Ep 1/2/4) catalogued from the phantasmal-world mirror; download + `decode-qst` pipeline proven on "Endless Nightmare #1" (internal q108). Nothing installed yet — gray-bucket items pending owner decision on provenance. |
