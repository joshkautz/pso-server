# Moving characters between platforms

PSO characters are **per-version** — a GameCube character and a Blue Burst
character are separate saves. But newserv can copy a character from one to the
other through **server-side save slots**, so you can carry your progress between,
say, GameCube/Dolphin and the PC (Blue Burst) client.

This works best when you play both platforms on the **same account**. Every
account on this server already has both a Blue Burst license (UserID/password) and
a GameCube license (serial / access key / password), so one character can hop
between them.

## The commands

Type these in the in-game chat (open chat, type the command, send):

| Command | What it does |
|---|---|
| `$savechar <slot>` | Save your **current** character into a server slot (1–N). |
| `$loadchar <slot>` | **Replace** your current character with the one in that slot. |
| `$checkchar <slot>` | Show basic info about what's saved in a slot. |
| `$deletechar <slot>` | Delete a saved slot. |
| `$bbchar <username> <password> <slot>` | Save your current character into **another account's** Blue Burst slot (for handing a character to a friend). |

The important part: **`$loadchar` can load a character that was saved from a
different version of PSO** — that's what makes cross-platform transfer work.

## Move a character GameCube → Blue Burst (most common)

1. **On GameCube/Dolphin**, log into your account and load the character you want
   to move.
2. Open chat and run **`$savechar 1`** (any free slot number). You'll get a
   confirmation.
3. **On the PC (Blue Burst) client**, log into the **same account** and pick (or
   make) a character slot you don't mind overwriting.
4. Run **`$loadchar 1`**. Your GameCube character is now on Blue Burst.

Going the other way (BB → GC) is the same — `$savechar` on Blue Burst, `$loadchar`
on the GameCube — with one caveat below.

## Hand a character to a friend

On the character you want to copy, run
**`$bbchar <their-UserID> <their-password> <slot>`**. It writes a copy into that
account's Blue Burst slot. (You need their login for this, so it's a "share with a
friend" tool, not a steal-a-character one.)

## Caveats — read before you rely on it

- **Back up the target first.** `$loadchar` **overwrites** the character in your
  current slot. If that slot has a character you care about, `$savechar` it to a
  spare slot first.
- **Conversions aren't lossless.** The versions don't have identical feature sets
  — Blue Burst has Episode 4, mag behavior and a few items differ between the V3
  (GameCube) and V4 (Blue Burst) generations — so expect minor differences after a
  cross-version move. Treat it as "continue your progress," not a perfect clone.
- **GameCube *Plus* and Episode III are save-only** by default — you can
  `$savechar` from them but not `$loadchar` onto them — unless
  `EnableSendFunctionCallQuestNumber` is turned on in `server/config.json`. (Plain,
  non-Plus GameCube saves and restores fine.) Ask the admin to flip that if you
  want full two-way transfer on Plus.
- **Episode III characters are a separate namespace** and can't convert to or from
  the other versions.

## Admin note

`$savechar`/`$loadchar` slots and the resulting character files live under
`system/players/` on the server (and are included in the nightly backup). To
enable two-way transfer for GC Plus / Ep3 players, set
`EnableSendFunctionCallQuestNumber` in `server/config.json` and redeploy.
