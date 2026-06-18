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

> **Owner decision (2026-06-18):** proceed with the full Ephinea tree, each
> credited to Ephinea in provenance + on the dashboard. See the install
> results below.

---

## Install results — 2026-06-18

The first install pass against the Ephinea tree surfaced a notable fact:
**newserv already bundles a large chunk of Ephinea's custom quests** in its
base set — but our provenance had them mislabeled as Sega `original`. So the
57 quests we pulled split three ways:

### ✅ Newly installed — 28 quests (`server/quests/`, BB-only)

Not present in newserv's bundle; downloaded, decoded, verified via
`newserv check-quests`, and assigned numbers in the free **600–699** block.

| # | Quest (in-game name) | Ep | Category |
|---|---|---|---|
| q605 | Maximum Attack S | 1 | Extermination |
| q606 | Random Attack Xrd Stage | 1 | Extermination |
| q610 | Dark Research 2.0 | 1 | Retrieval |
| q611 | Simulator 2.0 | 1 | Virtual Reality |
| q612 | Mine Offensive | 1 | Virtual Reality |
| q613 | Christmas Fiasco | 1 | Events |
| q614–q617 | Maximum Attack E: Caves / Forest / Mines / Ruins | 1 | Events |
| q624 | Gal Da Val's Darkness | 2 | Extermination |
| q626 | Maximum Attack S | 2 | Extermination |
| q627 | Random Attack Xrd Stage | 2 | Extermination |
| q628–q630 | Maximum Attack 4th Stage -2A- / -2B- / -2C- | 2 | Extermination |
| q631 | Maximum Attack E: Gal Da Val | 2 | Extermination |
| q632 | Maximum Attack E: VR | 2 | Extermination |
| q633 | Dolmolm Research | 2 | Retrieval |
| q634 | Christmas Fiasco | 2 | Events |
| q635–q639 | Maximum Attack E: CCA / Seabed / Spaceship / Temple / Tower | 2 | Events |
| q663 | Maximum Attack S | 4 | Extermination |
| q667 | Maximum Attack E: Episode 4 | 4 | Extermination |
| q668 | Christmas Fiasco | 4 | Events |

### ♻️ Already bundled — reclassified (then partly corrected — see audit below)

> **⚠️ This subsection's original reclassification was PARTLY WRONG and was
> corrected the same day.** See "[2026-06-18 — Audit & corrections](#2026-06-18--audit--corrections)"
> below. Short version: of the families listed here, only the *Maximum Attack*
> ones (q144–146, q237, q303–305, q314, q494) are genuinely community. The
> rest — **Endless Nightmare, Phantasmal World, Point of Disaster, The Robots'
> Reckoning, War of Limits, New Mop-Up Operation** — are **Sega-original** and
> were reverted to `original`.

These Ephinea-tree quests already ship in newserv at their original numbers,
so rather than installing duplicates we adjusted their `quest-provenance.json`
classification:

- ~~Endless Nightmare #1–#4 → q108–q111~~ → **Sega-original** (reverted)
- Maximum Attack 4th Stage -1A/-1B/-1C- → **q144–q146** (custom ✓)
- ~~Phantasmal World #1–#4 → q233–q236~~ → **Sega-original** (reverted)
- Maximum Attack 1 Ver2 → **q237** (custom ✓)
- Maximum Attack 4th Stage -4A/-4B/-4C- → **q303–q305** (custom ✓)
- Maximum Attack 3 Ver2 → **q314** (custom ✓); Maximum Attack 2 Ver2 → **q494** (custom ✓)
- ~~Point of Disaster q709; Robots' Reckoning q710~~ → **Sega-original** (reverted)
- ~~War of Limits 1–5 → q811–q815~~ → **Sega-original** (reverted)
- ~~New Mop-Up Operation #1–#5 → q816–q820~~ → **Sega-original** (reverted)

### ⏭️ Skipped / deferred

- **Borderline-provenance names** (Forsaken Friends, Rescue From Ragol,
  Tyrell's Ego, Sugoruku, Dream Messenger, Revisiting Darkness, Reach for the
  Dream, Respective Tomorrow, Beyond The Horizon, LOGiN) — left `catalogued`,
  not installed. Many are likely renamed Sega-originals; needs per-file
  confirmation before tagging custom.
- **Mop Up Operation #1–4, Today's Rate, Lost weapons series, Towards the
  Future, Labyrinthine Trial, Fragments of a Memory, etc.** — Sega-originals
  in the Ephinea tree; intentionally skipped (already covered by the bundled
  Sega set).

> **Caveat — all Ephinea quests are Blue Burst format.** They're playable by
> BB clients only. Our GameCube-centric group won't see them in-game until
> someone connects via Blue Burst; they appear on the dashboard quest list
> regardless (tagged Episode + Custom).

---

## 2026-06-18 — Audit & corrections

A bidirectional classification audit (cross-referenced against the
**[Sylverant quest-list](https://sylverant.net/quest-list/)** "Common (Sega)
Quests" split and the **[Ephinea wiki](https://wiki.pioneer2.net/w/Quests)**
per-quest `Author` fields) found the initial install batch had errors in
**both** directions. All fixed in `quest-provenance.json`.

### Direction 2 — Sega-original wrongly marked custom (the over-correction)

The first pass assumed "in Ephinea's quest tree ⇒ Ephinea custom." That's
false — **Ephinea hosts Sega-original quests too.** Sylverant lists Endless
Nightmare and Phantasmal World under "Common (Sega) Quests"; the Ephinea wiki
credits the Ep4 families to "Sonic Team." **20 quests reverted to
`original`:** Endless Nightmare (q108–111), Phantasmal World (q233–236),
Point of Disaster (q709), The Robots' Reckoning (q710), War of Limits
(q811–815), New Mop-Up Operation (q816–820).

### Direction 1 — community wrongly marked original

The **Maximum Attack 4th Stage (MA4)** series is fan-made (originated on
Schthack, hosted by Ephinea, credited "Matt"); Sega never made an MA4. **5
flipped to `custom`:** q147, q497, q498, q499, q500 — for consistency with
the already-custom q144–146 / q303–305.

### Real duplicates removed

My install of "MA4 -2A-/-2B-/-2C-" (q628–630) duplicated bundled
**q497–499** ("Maximum Attack 4th Stage -2A-…"). My dedup missed it because I
compared the *short* source name ("MA4 -2A-") against the *long* bundled name.
**q628–630 removed.** This is the bug the alias system below now prevents.

### Held for manual review

- **q504** "To The Deepest Blue -MA4 Venue-" — "-MA4 Venue-" implies community,
  but the wiki says Author: Sonic Team. Left `original`, flagged.
- **q501 / q502** "Maximum Attack E: VR / Gal Da Val" (GC/XB, classified
  `original`) — the "Maximum Attack E" prefix is an Ephinea community-series
  marker, but they're GC/XB-bundled (odd for a BB-era series). Left `original`,
  flagged; the BB versions (my q631/q632) are confirmed custom and kept.

### Borderline names resolved (Agent research)

| Quest | Verdict | Author |
|---|---|---|
| Forsaken Friends | **custom** | FireFox276 |
| Rescue from Ragol | **custom** | Tofuman |
| Tyrell's Ego | **custom** | Tofuman |
| Revisiting Darkness | **custom** | RikaPSO & Ilitsa |
| Sugoroku, Dream Messenger, Reach for the Dream, Respective Tomorrow, Beyond the Horizon, LOGiN | **Sega-original** | Sonic Team |

The four customs above aren't in our set (Ephinea server-side only); they're
listed as future candidates in the independently-authored table. The six Sega
ones are correctly `original` already — no change.

Net: custom-classified quests **74 → 56** of **285** total (after reverts +
dup removal).

---

## Dedup / alias system

To stop the same quest entering the catalog twice under different names, every
provenance entry may carry an **`aliases`** list (short forms, source-filename
variants, case/spacing variants). The checker normalizes names + aliases and
folds the common `MA4`↔`Maximum Attack 4th Stage`, `MAE`↔`Maximum Attack E`
abbreviations.

```bash
# Before installing a download, check it isn't already present:
python3 scripts/quest-dedup-check.py "MA4 -2A-"
#   → ✗ DUPLICATES existing: q497 (Maximum Attack 4th Stage -2A-)

# Audit the whole catalog for collisions (CI / pre-commit gate):
python3 scripts/quest-dedup-check.py --self-check

# Check a folder of freshly-downloaded .qst files by filename:
python3 scripts/quest-dedup-check.py --dir /tmp/new-quests
```

`--self-check` suppresses the expected noise of Sega quests bundled at multiple
version-numbers (e.g. Planet Ragol at DC q151 / GC q180 / BB q401) and only
flags collisions that involve a custom entry, annotating each with platform so
genuine per-version copies (BB vs GC) are distinguishable from true duplicates.

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
| **PSO Palace — Aleron Ives/Jodin** | [psopalace.sylverant.net/downloads.html](https://psopalace.sylverant.net/downloads.html) + [downloads_pc.html](https://psopalace.sylverant.net/downloads_pc.html) | No (torrents/zips) | The richest genuinely-**custom** vein: 100%-original fan quests (Christmas Catastrophe, Lost HAVOC VULCAN, Resurgent Darkness, Frantic Fauna, Halloween Horror, Acrid Aquifer…). Shipped as **DC/PC disc torrents** + a no-login `Ives_PC_PSO_Quests.zip` and `Offline_Quest_Pack` (11 `.qst`). **DC/PC format → needs `newserv` conversion to BB.** | Shareable (Ives released them) |
| **waytim/psobb** (GitHub) | [github.com/waytim/psobb](https://github.com/waytim/psobb) `quest/` | No | 145 `.qst` — the standard **Sega/Tethealla** bundle (whiteday, ma1, sunset base, etc.). Clean no-login mirror of the Sega set; **not custom**, redundant with our bundle. | N/A (not custom) |

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
| Forsaken Friends | FireFox276 | q670 | 1 | Shareable | **installed** | Installed 2026-06-18 (BB). Confirmed community (Ephinea wiki Author field). |
| Rescue from Ragol | Tofuman | q671 | 1 | Shareable | **installed** | Installed 2026-06-18 (BB). Boss-rush of every Ep1 boss. |
| Tyrell's Ego | Tofuman | q672 | 1 | Shareable | **installed** | Installed 2026-06-18 (BB). |
| Revisiting Darkness | RikaPSO & Ilitsa | q673 | 2 | Shareable | **installed** | Installed 2026-06-18 (BB). |
| (Aleron Ives / Jodin releases) | Aleron Ives, Jodin | — | — | Shareable | blocked | PSO Palace. **100% custom** quests (Christmas Catastrophe, Lost HAVOC VULCAN, Resurgent Darkness, Frantic Fauna, Acrid Aquifer…). Distributed as **DC/PC disc torrents** + a no-login `Ives_PC_PSO_Quests.zip` / `Offline_Quest_Pack` (11 `.qst`). DC/PC format → needs newserv conversion to BB. See source registry. |
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
| 2026-06-18 | Document created. Source registry verified. Ephinea custom tree (Ep 1/2/4) catalogued from the phantasmal-world mirror; download + `decode-qst` pipeline proven. |
| 2026-06-18 | Owner approved the full Ephinea tree. Installed **28 new** Ephinea quests (q605–q668, BB) into `server/quests/`; found **29 already bundled** in newserv and reclassified them `original`→`custom` in `quest-provenance.json`; skipped 1 name-dup (Maximum Attack 2 Ver2 = bundled q494) + borderline-provenance names. Custom-classified quests in the dashboard: 17 → **74**. See "Install results" above. |
| 2026-06-18 | **Audit & correction.** Bidirectional classification audit vs Sylverant + Ephinea wiki. Reverted **20** Sega-original quests wrongly flipped to custom (Endless Nightmare, Phantasmal World, Point of Disaster, Robots' Reckoning, War of Limits, New Mop-Up); flipped **5** genuine MA4 community quests to custom; removed **3** real duplicates (q628–630 = bundled q497–499). Added the **`aliases`** field + `scripts/quest-dedup-check.py` (the alias gap is what let the q628–630 dup through). Resolved 10 borderline names (4 custom future-candidates, 6 confirmed Sega). Flagged q501/q502/q504 for manual review. New sources: PSO Palace (Aleron Ives/Jodin customs), waytim/psobb mirror. Custom now **56 / 285**. See "Audit & corrections" above. |
| 2026-06-18 | **Loose-end tidy.** Resolved the review flags: **q501/q502** ("Maximum Attack E: VR/Gal Da Val") flipped to **custom** — Ephinea wiki confirms Maximum Attack E is a community series by Matt (the GC/XB versions of our BB q631/q632); **q504** kept **original** (wiki Author: Sonic Team — it's the MA4-event shop venue). Installed **4** confirmed-community quests dedup-checked first: **q670** Forsaken Friends (FireFox276), **q671** Rescue from Ragol (Tofuman), **q672** Tyrell's Ego (Tofuman), **q673** Revisiting Darkness (RikaPSO & Ilitsa). Fixed the deploy quest-removal gap (seed step now rebuilds `system/quests` from the image each deploy). Custom now **62 / 289**; installed q6xx = **29**. |
