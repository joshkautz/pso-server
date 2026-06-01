# Community quest pack procurement guide

A targeted list of where to find PSO GameCube fan-made and community-curated
quests. Most of these gate downloads behind a forum login, so this doc is
organized as a shopping list — register where needed, grab the attachments,
then follow [`community-quests.md`](community-quests.md) to install.

The community quest scene is fragmented by design (each author hosts on
the forum where they're known), so there is no single "PSO community
quest archive" to clone. Plan to spend ~30 minutes spinning up two
forum accounts.

---

## Quick-start — three places to go first

If you have time for exactly one procurement session, hit these in order:

1. **Schtserv community quest thread** — <https://schtserv.com/forums/viewtopic.php?t=1284>
   - Account registration likely required. Free at <https://schtserv.com/forums/ucp.php?mode=register>
   - Format: `.qst` attachments (mixed quest types)
   - Historical name: "Schtserv 42-pack"
2. **PSO Palace forum (Aleron Ives's quests)** — <https://www.pso-palace.com/>
   - Account registration likely required.
   - Format: per-quest threads with `.qst` attachments
   - Filter the Quests subforum by user "Aleron Ives" to find his releases
3. **b0n3zx PSOquest GitHub** — <https://github.com/b0n3zx/PSOquest>
   - Public, no login. 32 `.gci` files in `Quests/psogc_quests/`.
   - **Caveat**: mostly dumps of *Sega-original* download quests (overlaps the existing bundle) plus some cheat / item-creator quests. Filter aggressively.

---

## Tier 1 — public sources (no login required)

### GitHub repos

| Source | URL | Format | Count | Notes |
|---|---|---|---|---|
| **b0n3zx / PSOquest** | <https://github.com/b0n3zx/PSOquest> | `.gci` | 32 | Most are Sega-original download quest dumps; a few item-creators. Use `newserv decode-gci`. |
| **gered / pso_gc_tools** | <https://github.com/gered/pso_gc_tools> | tools | — | Rust tools for `gci_quest_extract` + `psogc_quest_tool`. Alternative to newserv's built-in decoders. |
| **fuzziqersoftware / newserv** | <https://github.com/fuzziqersoftware/newserv/tree/main/system/quests> | `.bin`/`.dat` | 260 | What's already bundled. Browse for reference. |

### Public archives

| Source | URL | Format | Notes |
|---|---|---|---|
| **PSO Archive (Neocities)** | <https://psoarchive.neocities.org/quests/quests> | mixed | Primarily DC-era. Some content directly downloadable. |
| **qedit.info** | <https://qedit.info/> | `.qst` and `.bin`/`.dat` | EN/JP Sega quests + some fan translations. Worth browsing for language fills. |
| **Aleron Ives's GC patches page** | <https://psopalace.sylverant.net/downloads_gamecube.html> | patches (not quests) | The patches here are game-side; per-quest releases are on the PSO Palace forum. |
| **PSO-World quest downloads** | <https://www.pso-world.com/download.php?cat=Download+Quests> | mixed | Historical archive. Returns 403 to scrapers but is browseable in a real browser. |

### English-translation projects

| Source | URL | Notes |
|---|---|---|
| **Ragol — AOL CUP / Sunset Base translation** | <https://ragol.org/forum/viewtopic.php?t=185> | English translation of Sega's Japan-only event quest. Compare to the bundle's q081. |
| **Dreamcast-Talk download-quests guide** | <https://www.dreamcast-talk.com/forum/viewtopic.php?t=2388> | Catalog of DC-era download quests with file links. |

---

## Tier 2 — forum-gated, high-value

### Schtserv community quest archive

- **Registration**: <https://schtserv.com/forums/ucp.php?mode=register> (free, may require email verification + minimum post count before attachments unlock)
- **Main thread**: <https://schtserv.com/forums/viewtopic.php?t=1284>
- **What to look for**: the OP attachment + any follow-up attachments in the thread (multiple pages — check page 2+)
- **Format**: mostly `.qst` (use `newserv decode-qst`)
- **Quality**: long-running community archive; mixed pack from various authors over the years
- **Adjacent threads**: browse the Schtserv "Quests" subforum for stand-alone releases not bundled in the 1284 thread

### PSO Palace forum (Aleron Ives's releases)

- **Registration**: <https://www.pso-palace.com/register/> or via the forum's signup link
- **Forum index**: <https://www.pso-palace.com/forum/>
- **What to look for**:
  - Posts by user **Aleron Ives** in the Quests subforum (he's a prolific long-time quest author — 15+ years of releases)
  - Each thread typically contains the `.qst` attachment + a description of the quest
  - Verify GC-targeted (some threads are PSOBB-only; skip those)
- **License norm**: Aleron Ives generally permits redistribution if credit is preserved. Recommend preserving author + thread URL in your `quest-provenance.json` entry per quest.

### Pioneer 2 (Ephinea) forum

- **URL**: <https://www.pioneer2.net/community/>
- **Account**: free registration
- **What to look for**:
  - Quest-related threads in the Quests/Modding subforums
  - **Important**: Pioneer 2 / Ephinea is primarily a PSOBB community. Many of their quests are BB-format and won't load on GC. Filter for `.qst-gc` or quest threads that explicitly list GC versions.

---

## Tier 3 — worth a sweep

### gc-forever forums

- **URL**: <https://www.gc-forever.com/forums/viewtopic.php?t=2049>
- **Account**: may require registration
- **Format**: scattered across forum posts; no consolidated pack
- **Notes**: gc-forever is the long-running GC hardware/modding community; quest threads here are usually preservation-focused rather than new content

### dcemulation.org

- **Patch Batch thread**: search the forum for "Patch Batch" + "Altimira" — Aleron Ives historically posted here too
- **URL**: <http://dcemulation.org/phpBB/> (dcemulation forum index — phpBB)
- **Format**: per-thread attachments
- **Notes**: DC-focused community; some of Aleron's releases were cross-posted from PSO Palace

### Sylverant (the older private server's archives)

- **URL**: <https://sylverant.net/>
- **Notes**: Sylverant ran DC + GC private servers. Some of their quest archive may still be browsable; check the site map for download sections.

---

## Authors to search for

If you find any of these author handles in a forum's user listing, browse
their post history — most quest authors have a "I made a quest, here's the
attachment" pattern across their threads.

| Author | Primary forum | Notes |
|---|---|---|
| **Aleron Ives** | PSO Palace | 15+ year quest author. **Highest-value source** for new content. |
| **soulja224466** | (rare) | GC modding scene 2004-2006. We already have `q000`. |
| **Matt Swift** | newserv GitHub | Newserv contributor — Story Flag Fixer (q253) and may have other utility quests. |
| **FaNaTiC** | PSO Palace / Schtserv | Co-credited on early GC modding work. |
| **Gcentrex** | Schtserv | Co-credited on early AR codes; may have authored quests. |
| **Sodaboy** | Schtserv (admin) | Schtserv founder. Curates the community archives. |

---

## What to skip

- **PSOBB-only quests** — anything Ephinea-specific or labeled "BB" will not load on GC. The `-bb` filename suffix is a strong signal.
- **Quests that say "Episode 3"** — Ep3 (`pso3char`) has a different format; not the same content as Ep1&2.
- **Item-creator / cheat quests** — recognizable by names like "Item Spawner", "Maxed Mag", "Material Spammer", etc. They work but aren't gameplay quests.
- **Christmas/Halloween reskin clones** — many community packs include re-themed versions of Sega's seasonal quests; usually low value-add.

---

## Procurement checklist

For each pack you grab:

- [ ] Download the attachment(s) to a local working directory
- [ ] Note the original thread URL for the provenance entry
- [ ] Note the author handle
- [ ] Note the approximate release year (visible in the thread post date)
- [ ] Skim the quest's description/screenshots to confirm GC-compatibility
- [ ] Keep an attribution note for each quest

---

## After procurement — install procedure

See [`community-quests.md`](community-quests.md) for the step-by-step.
The short version:

```bash
# 1. Decode (if .qst or .gci)
newserv decode-qst pack/*.qst
# or:
newserv decode-gci pack/*.gci

# 2. Rename to qNNN-gc-e.bin / qNNN-gc.dat per newserv convention
#    Use a quest number in 300-399 (the cleanest free block)

# 3. Drop into the repo overlay
cp q3NN-gc*.bin q3NN-gc*.dat \
   /path/to/pso-server/server/quests/download/

# 4. Add an entry to dashboard/quest-provenance.json:
#    {
#      "3NN": {
#        "classify": "custom",
#        "name": "...",
#        "author": "...",
#        "year": 2020,
#        "platform": "GameCube",
#        "distribution": "community-archive",
#        "sourceUrl": "https://...",
#        "category": "Download",
#        "episode": 1,
#        "notes": "..."
#      }
#    }

# 5. Commit + push
git add server/quests/download/ dashboard/quest-provenance.json
git commit -m "quests: install <pack name> (N quests)"
git push
```

The deploy fires, the dashboard's Custom chip count jumps, each new quest gets the same rich reference-page treatment in the modal.

---

## If a source goes dark

PSO community sites have a habit of vanishing without warning (Schtserv has gone down for months at a time in the past; PSO Palace has had domain changes). If a URL returns nothing:

- **Wayback Machine** — <https://web.archive.org/> often has the forum thread cached with attachments
- **Reddit /r/PSO** — <https://www.reddit.com/r/PSO/> — sometimes mirrors lost content
- **Discord** — both Pioneer 2 and Schtserv communities have Discords; ask there

Worth bookmarking the Wayback page for any forum thread you find quests in.
