# Connecting from Dolphin (macOS / Windows / Linux)

Step-by-step guide for getting **PSO Episode I & II Plus (USA Rev 2)**
connected to the server from a desktop Dolphin install. Tested on
Dolphin 2603a on macOS (Apple Silicon, Metal renderer, HLE BBA). The
same INI snippets work on Windows and Linux Dolphin — only the file
paths differ.

Plan for ~15 minutes per player, ~one minute of that on the server
side (Josh adds your IP to the allowlist).

If you're on a **Batocera Linux** machine instead, see
[`client-setup.md`](client-setup.md).

---

## Before you start

You need:

- **Dolphin emulator.** Get a recent build from
  https://dolphin-emu.org/download/ — anything 2024-or-newer is fine.
- **A PSO Episode I & II Plus disc image** (USA Rev 2 is what's tested;
  v1.0 / v1.1 also work, possibly with a slightly different `[Core]` /
  per-game INI). Provide your own; we don't ship one.
- **Your machine's public IPv4** — visit https://ifconfig.io from a
  browser on the machine you'll play from. You'll send this to Josh so
  he can add it to the server's DNS allowlist.
- **A controller** (Dolphin maps keyboards too if you must, but PSO
  controls are designed for a gamepad).

---

## Step 1 — Send your public IP to Josh

Until your IP is in the server's allowlist, Dolphin's DNS queries from
PSO will silently fail. Josh runs `terraform apply` and you'll be in
within a minute. **Don't skip this step.**

---

## Step 2 — Locate Dolphin's config directory

The exact path depends on your OS:

| OS | Path |
|---|---|
| macOS | `~/Library/Application Support/Dolphin/` |
| Windows (installed) | `%APPDATA%\Dolphin Emulator\` |
| Windows (portable) | `<dolphin folder>\User\` |
| Linux | `~/.config/dolphin-emu/` |

Inside it you'll see `Config/`, `GameSettings/`, `GC/`, etc.

---

## Step 3 — Set the BBA DNS (the magic line)

This is the **one config change that makes PSO Plus talk to your
server** instead of the default Schtserv. Open
`Config/Dolphin.ini` in a text editor and add a single line under the
`[Core]` section:

```ini
[Core]
BBA_BUILTIN_DNS = 54.173.68.119
```

That's the public IP of Josh's server. Save and close.

> **Why this matters.** Dolphin's emulated GameCube Broadband Adapter
> intercepts every DNS packet from the game and silently rewrites the
> destination IP to whatever `BBA_BUILTIN_DNS` is set to. The default
> is Schtserv (`3.18.217.27`), which is why PSO normally connects to
> Schtserv without anyone configuring DNS. Pointing it at our server
> makes PSO query *our* DNS instead. (Source: Dolphin's
> [`BuiltIn.cpp`](https://github.com/dolphin-emu/dolphin/blob/master/Source/Core/Core/HW/EXI/BBA/BuiltIn.cpp).)
>
> Important: this MUST go in the global `Dolphin.ini`. A per-game INI
> at `GameSettings/GPOE8P.ini` won't work — Dolphin only reads
> `BBA_BUILTIN_DNS` from the global config.

---

## Step 4 — Per-game settings for PSO Plus

Create `GameSettings/GPOE8P.ini` inside the Dolphin config directory
with the following contents. Substitute the `MemcardAPath` path for
your OS.

```ini
[Core]
# Broadband Adapter (HLE) on Serial Port 1 — required for online.
SerialPort1 = 12

# Dual-core CPU emulation — Plus's online code is heavy.
CPUThread = True

# CRITICAL: raw memcard format, not Dolphin's default GCI Folder.
# Folder mode corrupts PSO's network info file every boot.
SlotA = 1
MemcardAPath = /Users/<you>/Library/Application Support/Dolphin/GC/USA/MemoryCardA-PSO.USA.raw

[DSP]
EnableJIT = True
```

If the `.raw` file doesn't exist yet, Dolphin creates it on first boot
with PSO Plus. You don't need to download anything.

---

## Step 5 — Boot PSO and register your account

Launch Dolphin, double-click your PSO Plus disc image, and let it boot
through the Sega/Sonic Team logos, EULA, and date prompt. Then:

1. **Press START** at the title screen.
2. Select **ONLINE GAME**.
3. PSO will ask which memory card slot to use → **Slot A**.
4. PSO will tell you it's creating a fresh network info file → confirm.
5. PSO will show "**In order to play PSO Episode 1 and 2 online, you
   must purchase a Hunter's License.**" — this is just informational.
   Select **Agree** to continue.
6. **Enter a Serial Number** — exactly 10 alphanumeric characters.
   PSO doesn't validate the value; type whatever you want. Example:
   `0123456789`.
7. **Enter an Access Key** — 12 alphanumeric characters. Same deal.
   Example: `0123456789AB`.
8. **Enter a Password** — 1 to 8 alphanumeric characters. Example:
   `password`. **Write this one down** — if you don't save it to the
   memcard at the next prompt, you'll re-enter it every session.
9. **Game Certificate Confirmation** screen — verify and press Yes.
10. **Save Password to Memory Card?** — Yes (saves you typing it next
    time).

PSO will then:
- DNS-resolve `game04.st-pso.games.sega.net` (Dolphin redirects to
  Josh's server)
- Open TCP to that IP on port 9103
- Receive the `0x17` "DreamCast Port Map" welcome packet from newserv
- Drop you into the lobby

If you see **"Welcome to PSO Josh!"** in a yellow text box, you're in.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Device connected to Serial Port 1 cannot be recognized` | BBA HLE not active | Verify `SerialPort1 = 12` in `GameSettings/GPOE8P.ini` |
| `The network information file on the Memory Card in Slot A is corrupt` | Slot A is in GCI Folder mode | Verify `SlotA = 1` and `MemcardAPath = ...` in the per-game INI |
| `(No.100) You are banned from this server.` | Dolphin sent DNS to Schtserv default — your `BBA_BUILTIN_DNS` line is in the wrong place | Re-check it's in the **global** `Dolphin.ini` under `[Core]`, not in `GameSettings/GPOE8P.ini`. Restart Dolphin after editing. |
| `(No.102) You could not be connected to the server.` | DNS resolved to a host that's not actually listening, OR your public IP isn't in the allowlist | Ping Josh — he'll check `docker logs newserv` for your IP |
| `Connecting to the DNS server.` hangs forever | Your machine has no internet route to the server, OR Josh's Lightsail instance is down | Check your own connectivity, then ping Josh |
| Stays at title screen, never gets to ONLINE GAME | Wrong disc revision OR per-game INI for a different game ID | Right-click the disc in Dolphin's game list → Properties → "Game ID" field shows what version you have |

Any other weirdness: send Josh the output of
```bash
ls -la ~/Library/Application\ Support/Dolphin/Config/Dolphin.ini
grep BBA_BUILTIN_DNS ~/Library/Application\ Support/Dolphin/Config/Dolphin.ini
cat ~/Library/Application\ Support/Dolphin/GameSettings/GPOE8P.ini
```
and he can usually tell what's off in 30 seconds.

---

## How this differs from real GameCube + BBA hardware

If you have an actual GameCube with a Broadband Adapter, you don't
need any of the Dolphin INI configuration — instead you set
**Primary DNS** in PSO's in-game network setup to Josh's server IP
(`54.173.68.119`). PSO writes that value to the memory card and uses
it for all subsequent DNS queries directly.

The Dolphin BBA HLE quirk (the silent DNS redirect via
`BBA_BUILTIN_DNS`) doesn't exist on real hardware — the BBA there
honors whatever DNS the in-game config tells it to use.

---

## Reference

- **Server static IP:** `54.173.68.119`
- **Plus's login server hostname / port** (what `BBA_BUILTIN_DNS`
  routes to): `game04.st-pso.games.sega.net:9103`
- **Plus's USA Rev 2 disc ID:** `GPOE8P` (game-code `GPOE`, maker
  `8P`, disc `00`, version `02`)
- **Dolphin BBA HLE source:** the `BBA_BUILTIN_DNS` default of
  `3.18.217.27` (Schtserv) is set in
  [`MainSettings.cpp`](https://github.com/dolphin-emu/dolphin/blob/master/Source/Core/Core/Config/MainSettings.cpp)
- **Plus's protocol** is byte-identical to v1.0's `0x17` "DreamCast
  Port Map" welcome / login handshake. newserv supports it as the
  built-in `gc-us3` version (port 9103 in `system/config.json`).
- **Server admin's contact:** josh@joshkautz.com
