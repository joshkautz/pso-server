# Quest catalog — Blue Burst

_Auto-generated from the live `/api/quests` and per-quest script disassembly._

**196** BB quests · **67** completion-mapped · **40** community-authored, **156** Sega-original.

The quest **ID** (`qNNN`) is the quest's `QuestNumber` from its file metadata, zero-padded — the same number newserv validates against the filename and exposes on the dashboard. **Mapped** = its clear flag is known, so player completions are recorded. **Status**: `mapped` / `repeatable` (success routine sets no clear flag) / `no-success` (no success routine).


## Completion-tracking coverage

| Tier | Quests | Meaning |
|---|---|---|
| **Mapped** | 67 | Clear flag known via disassembly — every player clear is recorded (story / government chains, 1 event). |
| **Repeatable** | 118 | Has a success routine but sets no persistent flag (events, retrieval, VR, extermination, challenge). Can be made trackable by *injecting* a flag — see below. |
| **No success routine** | 11 | Battle (PvP) and a few decoration/lobby quests — no "clear" concept. |

To extend tracking to the **repeatable** tier, newserv can reassemble a quest with a clear flag added: `disassemble-quest-script` → insert `gset <flag>` at the `set_qt_success` routine → `assemble-quest-script` (the assembler resolves labels symbolically, so adding an instruction is safe). The `no-success` quests have no completion concept (battle results are tracked separately by the game).


## Battle — 8 quests, 0 mapped

| ID | Quest | Ep | Source | Mapped | Flag | Status |
|---|---|---|---|---|---|---|
| q88001 | Battle1 | 1 | original | — |  | no-success |
| q88002 | Battle2 | 1 | original | — |  | no-success |
| q88003 | Battle3 | 1 | original | — |  | no-success |
| q88004 | Battle4 | 1 | original | — |  | no-success |
| q88005 | Battle5 | 1 | original | — |  | no-success |
| q88006 | Battle6 | 1 | original | — |  | no-success |
| q88007 | Battle7 | 1 | original | — |  | no-success |
| q88008 | Battle8 | 1 | original | — |  | no-success |

## Challenge (Ep1) — 9 quests, 0 mapped

| ID | Quest | Ep | Source | Mapped | Flag | Status |
|---|---|---|---|---|---|---|
| q88101 | Stage1 | 1 | original | — |  | repeatable |
| q88102 | Stage2 | 1 | original | — |  | repeatable |
| q88103 | Stage3 | 1 | original | — |  | repeatable |
| q88104 | Stage4 | 1 | original | — |  | repeatable |
| q88105 | Stage5 | 1 | original | — |  | repeatable |
| q88106 | Stage6 | 1 | original | — |  | repeatable |
| q88107 | Stage7 | 1 | original | — |  | repeatable |
| q88108 | Stage8 | 1 | original | — |  | repeatable |
| q88109 | Stage9 | 1 | original | — |  | repeatable |

## Challenge (Ep2) — 5 quests, 0 mapped

| ID | Quest | Ep | Source | Mapped | Flag | Status |
|---|---|---|---|---|---|---|
| q88201 | Stage1 | 2 | original | — |  | repeatable |
| q88202 | Stage2 | 2 | original | — |  | repeatable |
| q88203 | Stage3 | 2 | original | — |  | repeatable |
| q88204 | Stage4 | 2 | original | — |  | repeatable |
| q88205 | Stage5 | 2 | original | — |  | repeatable |

## Events — 35 quests, 1 mapped

| ID | Quest | Ep | Source | Mapped | Flag | Status |
|---|---|---|---|---|---|---|
| q073 | The Tinkerbell's Dog 2 | 1 | original | ✓ | 115 `0x73` | mapped |
| q124 | St. Valentine's Day | 1 | original | — |  | no-success |
| q125 | White Day | 1 | original | — |  | no-success |
| q127 | Sugoroku | 1 | original | — |  | repeatable |
| q144 | Maximum Attack 4th Stage -A- | 1 | custom · Community (Schthack / Ephinea, credited "Matt") (2000) | — |  | repeatable |
| q145 | Maximum Attack 4th Stage -B- | 1 | custom · Community (Schthack / Ephinea, credited "Matt") (2000) | — |  | repeatable |
| q146 | Maximum Attack 4th Stage -C- | 1 | custom · Community (Schthack / Ephinea, credited "Matt") (2000) | — |  | repeatable |
| q201 | Dream Messenger | 2 | original | — |  | repeatable |
| q207 | Pioneer Halloween | 2 | original | — |  | repeatable |
| q211 | Maximum Attack 2 | 2 | original | — |  | repeatable |
| q216 | Singing by the beach | 2 | original | — |  | repeatable |
| q220 | The Principal's Gift | 1 | original | — |  | repeatable |
| q232 | Festivity On The Beach | 2 | original | — |  | repeatable |
| q239 | Beach Laughter | 2 | original | — |  | repeatable |
| q240 | Pioneer Christmas | 2 | original | — |  | repeatable |
| q303 | Maximum Attack 4th Stage -4A- | 4 | custom · Community (Schthack / Ephinea, credited "Matt") (2004) | — |  | repeatable |
| q304 | Maximum Attack 4th Stage -4B- | 4 | custom · Community (Schthack / Ephinea, credited "Matt") (2004) | — |  | repeatable |
| q305 | Maximum Attack 4th Stage -4C- | 4 | custom · Community (Schthack / Ephinea, credited "Matt") (2004) | — |  | repeatable |
| q312 | Claire's Deal 5 | 4 | original | — |  | repeatable |
| q497 | Maximum Attack 4th Stage -2A- | 2 | custom · Community (Schthack / Ephinea, credited "Matt") (2003) | — |  | repeatable |
| q498 | Maximum Attack 4th Stage -2B- | 2 | custom · Community (Schthack / Ephinea, credited "Matt") (2003) | — |  | repeatable |
| q499 | Maximum Attack 4th Stage -2C- | 2 | custom · Community (Schthack / Ephinea, credited "Matt") (2003) | — |  | repeatable |
| q504 | To the Deepest Blue -MA4 Venue- | 2 | original | — |  | repeatable |
| q613 | Christmas Fiasco | 1 | custom · Ephinea | — |  | repeatable |
| q614 | Maximum Attack E: Caves | 1 | custom · Matt (Ephinea) | — |  | repeatable |
| q615 | Maximum Attack E: Forest | 1 | custom · Matt (Ephinea) | — |  | repeatable |
| q616 | Maximum Attack E: Mines | 1 | custom · Matt (Ephinea) | — |  | repeatable |
| q617 | Maximum Attack E: Ruins | 1 | custom · Matt (Ephinea) | — |  | repeatable |
| q634 | Christmas Fiasco | 2 | custom · Ephinea | — |  | repeatable |
| q635 | Maximum Attack E: CCA | 2 | custom · Matt (Ephinea) | — |  | repeatable |
| q636 | Maximum Attack E: Seabed | 2 | custom · Matt (Ephinea) | — |  | repeatable |
| q637 | Maximum Attack E: Spaceship | 2 | custom · Matt (Ephinea) | — |  | repeatable |
| q638 | Maximum Attack E: Temple | 2 | custom · Matt (Ephinea) | — |  | repeatable |
| q639 | Maximum Attack E: Tower | 2 | custom · Matt (Ephinea) | — |  | repeatable |
| q668 | Christmas Fiasco | 4 | custom · Ephinea | — |  | repeatable |

## Extermination — 32 quests, 0 mapped

| ID | Quest | Ep | Source | Mapped | Flag | Status |
|---|---|---|---|---|---|---|
| q101 | Mop-up Operation #1 | 1 | original | — |  | repeatable |
| q102 | Mop-up Operation #2 | 1 | original | — |  | repeatable |
| q103 | Mop-up Operation #3 | 1 | original | — |  | repeatable |
| q104 | Mop-up Operation #4 | 1 | original | — |  | repeatable |
| q108 | Endless Nightmare #1 | 1 | original | — |  | repeatable |
| q109 | Endless Nightmare #2 | 1 | original | — |  | repeatable |
| q110 | Endless Nightmare #3 | 1 | original | — |  | repeatable |
| q111 | Endless Nightmare #4 | 1 | original | — |  | repeatable |
| q117 | Today's Rate | 1 | original | — |  | repeatable |
| q233 | Phantasmal World #1 | 2 | original | — |  | repeatable |
| q234 | Phantasmal World #2 | 2 | original | — |  | repeatable |
| q235 | Phantasmal World #3 | 2 | original | — |  | repeatable |
| q236 | Phantasmal World #4 | 2 | original | — |  | repeatable |
| q605 | Maximum Attack S | 1 | custom · Ephinea | — |  | repeatable |
| q606 | Random Attack Xrd Stage | 1 | custom · Namekemono & Ender | — |  | repeatable |
| q624 | Gal Da Val's Darkness | 2 | custom · Ephinea | — |  | repeatable |
| q626 | Maximum Attack S | 2 | custom · Ephinea | — |  | repeatable |
| q627 | Random Attack Xrd Stage | 2 | custom · Namekemono & Ender | — |  | repeatable |
| q631 | Maximum Attack E: Gal Da Val | 2 | custom · Matt (Ephinea) | — |  | repeatable |
| q632 | Maximum Attack E: VR | 2 | custom · Matt (Ephinea) | — |  | repeatable |
| q663 | Maximum Attack S | 4 | custom · Ephinea | — |  | repeatable |
| q667 | Maximum Attack E: Episode 4 | 4 | custom · Matt (Ephinea) | — |  | repeatable |
| q811 | War of Limits 1 | 4 | original | — |  | repeatable |
| q812 | War of Limits 2 | 4 | original | — |  | repeatable |
| q813 | War of Limits 3 | 4 | original | — |  | repeatable |
| q814 | War of Limits 4 | 4 | original | — |  | repeatable |
| q815 | War of Limits 5 | 4 | original | — |  | repeatable |
| q816 | New Mop-Up Operation #1 | 4 | original | — |  | repeatable |
| q817 | New Mop-Up Operation #2 | 4 | original | — |  | repeatable |
| q818 | New Mop-Up Operation #3 | 4 | original | — |  | repeatable |
| q819 | New Mop-Up Operation #4 | 4 | original | — |  | repeatable |
| q820 | New Mop-Up Operation #5 | 4 | original | — |  | repeatable |

## Hero in Red (Ep1) — 15 quests, 15 mapped

| ID | Quest | Ep | Source | Mapped | Flag | Status |
|---|---|---|---|---|---|---|
| q401 | 1-1:Planet Ragol | 1 | original | ✓ | 501 `0x1F5` | mapped |
| q402 | 1-2:Torrential Woods | 1 | original | ✓ | 503 `0x1F7` | mapped |
| q403 | 1-3:Subterranean Den | 1 | original | ✓ | 505 `0x1F9` | mapped |
| q404 | 2-1:Infernal Cavern | 1 | original | ✓ | 507 `0x1FB` | mapped |
| q405 | 2-2:Deep Within | 1 | original | ✓ | 509 `0x1FD` | mapped |
| q406 | 2-3:The Mutation | 1 | original | ✓ | 511 `0x1FF` | mapped |
| q407 | 2-4:Waterway Shadow | 1 | original | ✓ | 513 `0x201` | mapped |
| q408 | 3-1:The Facility | 1 | original | ✓ | 515 `0x203` | mapped |
| q409 | 3-2:Machines Attack | 1 | original | ✓ | 517 `0x205` | mapped |
| q410 | 3-3:Central Control | 1 | original | ✓ | 519 `0x207` | mapped |
| q411 | 4-1:The Lost Ruins | 1 | original | ✓ | 521 `0x209` | mapped |
| q412 | 4-2:Buried Relics | 1 | original | ✓ | 523 `0x20B` | mapped |
| q413 | 4-3:Hero & Daughter | 1 | original | ✓ | 525 `0x20D` | mapped |
| q414 | 4-4:The Tomb Stirs | 1 | original | ✓ | 527 `0x20F` | mapped |
| q415 | 4-5:Dark Inheritance | 1 | original | ✓ | 529 `0x211` | mapped |

## The Military's Hero (Ep2) — 18 quests, 18 mapped

| ID | Quest | Ep | Source | Mapped | Flag | Status |
|---|---|---|---|---|---|---|
| q451 | 5-1:Test/VR Temple 1 | 2 | original | ✓ | 531 `0x213` | mapped |
| q452 | 5-2:Test/VR Temple 2 | 2 | original | ✓ | 533 `0x215` | mapped |
| q453 | 5-3:Test/VR Temple 3 | 2 | original | ✓ | 535 `0x217` | mapped |
| q454 | 5-4:Test/VR Temple 4 | 2 | original | ✓ | 537 `0x219` | mapped |
| q455 | 5-5:Test/VR Temple 5 | 2 | original | ✓ | 539 `0x21B` | mapped |
| q456 | 6-1:Test/Spaceship 1 | 2 | original | ✓ | 541 `0x21D` | mapped |
| q457 | 6-2:Test/Spaceship 2 | 2 | original | ✓ | 543 `0x21F` | mapped |
| q458 | 6-3:Test/Spaceship 3 | 2 | original | ✓ | 545 `0x221` | mapped |
| q459 | 6-4:Test/Spaceship 4 | 2 | original | ✓ | 547 `0x223` | mapped |
| q460 | 6-5:Test/Spaceship 5 | 2 | original | ✓ | 549 `0x225` | mapped |
| q461 | 7-1:From the Past | 2 | original | ✓ | 551 `0x227` | mapped |
| q462 | 7-2:Seeking Clues | 2 | original | ✓ | 553 `0x229` | mapped |
| q463 | 7-3:Silent Beach | 2 | original | ✓ | 555 `0x22B` | mapped |
| q464 | 7-4:Central Control | 2 | original | ✓ | 557 `0x22D` | mapped |
| q465 | 7-5:Isle of Mutants | 2 | original | ✓ | 559 `0x22F` | mapped |
| q466 | 8-1:Below the Waves | 2 | original | ✓ | 561 `0x231` | mapped |
| q467 | 8-2:Desire's End | 2 | original | ✓ | 563 `0x233` | mapped |
| q468 | 8-3:Purple Lamplight | 2 | original | ✓ | 565 `0x235` | mapped |

## The Meteor Impact Incident (Ep4) — 8 quests, 8 mapped

| ID | Quest | Ep | Source | Mapped | Flag | Status |
|---|---|---|---|---|---|---|
| q701 | 9-1:Missing Research | 4 | original | ✓ | 701 `0x2BD` | mapped |
| q702 | 9-2:Data Retrieval | 4 | original | ✓ | 702 `0x2BE` | mapped |
| q703 | 9-3:Reality & Truth | 4 | original | ✓ | 703 `0x2BF` | mapped |
| q704 | 9-4:Pursuit | 4 | original | ✓ | 704 `0x2C0` | mapped |
| q705 | 9-5:The Chosen (1/2) | 4 | original | ✓ | 705 `0x2C1` | mapped |
| q706 | 9-6:The Chosen (2/2) | 4 | original | ✓ | 706 `0x2C2` | mapped |
| q707 | 9-7:Sacred Ground | 4 | original | ✓ | 707 `0x2C3` | mapped |
| q708 | 9-8:The Final Cycle | 4 | original | ✓ | 708 `0x2C4` | mapped |

## Retrieval — 13 quests, 0 mapped

| ID | Quest | Ep | Source | Mapped | Flag | Status |
|---|---|---|---|---|---|---|
| q058 | Lost HEAT SWORD | 1 | original | — |  | repeatable |
| q059 | Lost ICE SPINNER | 1 | original | — |  | repeatable |
| q060 | Lost SOUL BLADE | 1 | original | — |  | repeatable |
| q061 | Lost HELL PALLASCH | 1 | original | — |  | repeatable |
| q068 | The Missing Maracas | 1 | original | — |  | repeatable |
| q119 | Fragments of a Memory | 1 | original | — |  | repeatable |
| q137 | Rappy's Holiday | 1 | original | — |  | repeatable |
| q138 | Garon's Treachery | 1 | original | — |  | repeatable |
| q610 | Dark Research 2.0 | 1 | custom · Ephinea | — |  | repeatable |
| q633 | Dolmolm Research | 2 | custom · Ephinea | — |  | no-success |
| q670 | Forsaken Friends | 1 | custom · FireFox276 | — |  | repeatable |
| q671 | Rescue from Ragol | 1 | custom · Tofuman | — |  | repeatable |
| q673 | Revisiting Darkness | 2 | custom · RikaPSO & Ilitsa | — |  | repeatable |

## Shops — 2 quests, 0 mapped

| ID | Quest | Ep | Source | Mapped | Flag | Status |
|---|---|---|---|---|---|---|
| q204 | Gallon's Shop | 2 | original | — |  | repeatable |
| q205 | Item Present | 2 | original | — |  | repeatable |

## Solo — 8 quests, 0 mapped

| ID | Quest | Ep | Source | Mapped | Flag | Status |
|---|---|---|---|---|---|---|
| q030 | Warrior's Pride | 4 | original | — |  | repeatable |
| q031 | Black Paper's Deal | 4 | original | — |  | repeatable |
| q032 | The Restless Lion | 4 | original | — |  | repeatable |
| q033 | Pioneer Spirit | 4 | original | — |  | repeatable |
| q034 | Black Paper's Dangerous Deal 2 | 4 | original | — |  | repeatable |
| q035 | Gallon's Plan | 1 | original | — |  | repeatable |
| q126 | Good Luck! | 1 | original | — |  | repeatable |
| q143 | AOL CUP -Sunset Base- | 1 | original | — |  | repeatable |

## Story (solo) — 27 quests, 25 mapped

| ID | Quest | Ep | Source | Mapped | Flag | Status |
|---|---|---|---|---|---|---|
| q001 | Magnitude of Metal | 1 | original | ✓ | 101 `0x65` | mapped |
| q002 | Claiming a Stake | 1 | original | ✓ | 103 `0x67` | mapped |
| q003 | The Value of Money | 1 | original | ✓ | 105 `0x69` | mapped |
| q004 | Battle Training | 1 | original | ✓ | 107 `0x6B` | mapped |
| q005 | Journalistic Pursuit | 1 | original | ✓ | 109 `0x6D` | mapped |
| q006 | The Fake in Yellow | 1 | original | ✓ | 111 `0x6F` | mapped |
| q007 | Native Research | 1 | original | ✓ | 113 `0x71` | mapped |
| q008 | Forest of Sorrow | 1 | original | ✓ | 115 `0x73` | mapped |
| q009 | Gran Squall | 1 | original | ✓ | 117 `0x75` | mapped |
| q010 | Addicting Food | 1 | original | ✓ | 119 `0x77` | mapped |
| q011 | The Lost Bride | 1 | original | ✓ | 121 `0x79` | mapped |
| q012 | Waterfall Tears | 1 | original | ✓ | 123 `0x7B` | mapped |
| q013 | Black Paper | 1 | original | ✓ | 125 `0x7D` | mapped |
| q014 | Secret Delivery | 1 | original | ✓ | 127 `0x7F` | mapped |
| q015 | Soul of a Blacksmith | 1 | original | ✓ | 129 `0x81` | mapped |
| q016 | Letter from Lionel | 1 | original | ✓ | 131 `0x83` | mapped |
| q017 | The Grave's Butler | 1 | original | ✓ | 133 `0x85` | mapped |
| q018 | Knowing One's Heart | 1 | original | ✓ | 135 `0x87` | mapped |
| q019 | The Retired Hunter | 1 | original | ✓ | 137 `0x89` | mapped |
| q020 | Dr. Osto's Research | 1 | original | ✓ | 139 `0x8B` | mapped |
| q021 | Unsealed Door | 1 | original | ✓ | 141 `0x8D` | mapped |
| q022 | Soul of Steel | 1 | original | — |  | repeatable |
| q023 | Doc's Secret Plan | 1 | original | ✓ | 145 `0x91` | mapped |
| q024 | Seek my Master | 1 | original | ✓ | 147 `0x93` | mapped |
| q025 | From the Depths | 1 | original | ✓ | 149 `0x95` | mapped |
| q026 | Central Dome Fire Swirl | 1 | original | — |  | repeatable |
| q027 | Seat of the Heart | 2 | original | ✓ | 161 `0xA1` | mapped |

## Team — 2 quests, 0 mapped

| ID | Quest | Ep | Source | Mapped | Flag | Status |
|---|---|---|---|---|---|---|
| q709 | Point of Disaster | 4 | original | — |  | repeatable |
| q710 | The Robots' Reckoning | 4 | original | — |  | repeatable |

## Control Tower — 2 quests, 0 mapped

| ID | Quest | Ep | Source | Mapped | Flag | Status |
|---|---|---|---|---|---|---|
| q223 | The East Tower | 2 | original | — |  | repeatable |
| q224 | The West Tower | 2 | original | — |  | repeatable |

## Virtual Reality — 12 quests, 0 mapped

| ID | Quest | Ep | Source | Mapped | Flag | Status |
|---|---|---|---|---|---|---|
| q118 | Towards the Future | 1 | original | — |  | repeatable |
| q141 | Labyrinthine Trial | 1 | original | — |  | repeatable |
| q142 | AOL CUP -Maximum Attack- | 1 | original | — |  | repeatable |
| q203 | Reach for the dream | 2 | original | — |  | repeatable |
| q230 | Blue Star Memories | 2 | original | — |  | repeatable |
| q231 | Respective Tomorrow | 2 | original | — |  | repeatable |
| q237 | MAXIMUM ATTACK 1 Ver2 | 1 | custom · Ephinea (2003) | — |  | repeatable |
| q313 | Beyond the Horizon | 4 | original | — |  | repeatable |
| q494 | MAXIMUM ATTACK 2 Ver2 | 2 | custom · Ephinea (2003) | — |  | repeatable |
| q611 | Simulator 2.0 | 1 | custom · Ephinea | — |  | repeatable |
| q612 | Mine Offensive | 1 | custom · Ephinea | — |  | repeatable |
| q672 | Tyrell's Ego | 1 | custom · Tofuman | — |  | repeatable |
