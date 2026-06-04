# Connecting from Batocera + Dolphin

Step-by-step guide for getting PSO Episode I & II — **any GameCube US
version (v1.0, v1.1, or Plus)** — connected to the server from Batocera
Linux running Dolphin. Empirically tested on Batocera v41+ (Mar 2026
build, Dolphin master) against PSO Episode I & II Plus (USA Rev 2). The
v1.0 and v1.1 paths are confirmed by code review of newserv master:
every retail GC disc maps to the same `Version::GC_V3` enum
(`src/Version.hh:10-26`) and goes through identical plain-TCP login on
ports 9100 → 9103. newserv contains no SSL/TLS code anywhere, so no
"License server" / SSL handshake is involved for any GC revision.

You'll do this once per player machine. Plan for ~15 minutes.

> **If you're on desktop Dolphin (macOS / Windows / Linux)** instead of
> Batocera, see [`client-setup-dolphin.md`](client-setup-dolphin.md). The
> idea is the same; the file paths are different.

---

## Before you start

You need:

- A Batocera Linux install that boots to EmulationStation.
- A PSO GameCube disc image at `/userdata/roms/gamecube/`. Any US
  version works:
  - `Phantasy Star Online Episode I & II (USA).rvz` (v1.0 or v1.1)
  - `Phantasy Star Online Episode I & II Plus (USA) (Rev 2).rvz`
  
  All three discs share the disc-ID prefix `GPOE8P`; they differ only
  in the version byte (`0x00`, `0x01`, `0x02`).
- The server's static IP — ask Josh, or run
  `terraform -chdir=infra output instance_public_ip` from the repo.
- Your Batocera machine's **public IPv4** (`curl https://ifconfig.io`
  from SSH, once you're in). Josh adds this to the DNS allowlist.
- A computer that can SSH into Batocera (any laptop on the same Wi-Fi).

---

## Step 1 — Send your public IP to Josh

Until your IP is in the server's DNS allowlist, your PSO client will
silently fail to connect. Josh runs two commands and you're added within
a minute. **Don't skip this step**, even though everything else looks
configured.

---

## Step 2 — SSH into Batocera

Default credentials: `root` / `linux`.

Find Batocera's LAN IP from EmulationStation: **Main Menu → Network
Settings → IP Address**.

Then on your laptop:

```bash
ssh root@<batocera-lan-ip>
# password: linux
```

If SSH is disabled on your Batocera, enable it in **Main Menu →
Network Settings → Enable SSH** and try again.

---

## Step 3 — The critical Dolphin setting: `BBA_BUILTIN_DNS`

This is the one setting that actually makes your PSO talk to Josh's
server instead of to Schtserv (Dolphin's hardcoded default).

```bash
mkdir -p /userdata/system/configs/dolphin-emu
INI=/userdata/system/configs/dolphin-emu/Dolphin.ini

# Ensure a [Core] section exists, then add or replace BBA_BUILTIN_DNS.
touch "$INI"
grep -q '^\[Core\]' "$INI" || printf '\n[Core]\n' >> "$INI"
if grep -q '^BBA_BUILTIN_DNS' "$INI"; then
  sed -i 's|^BBA_BUILTIN_DNS *=.*|BBA_BUILTIN_DNS = 54.173.68.119|' "$INI"
else
  sed -i '/^\[Core\]/a BBA_BUILTIN_DNS = 54.173.68.119' "$INI"
fi

# Verify
grep BBA_BUILTIN_DNS "$INI"
```

You should see `BBA_BUILTIN_DNS = 54.173.68.119` echoed back.

> **Why this matters — and the trap underneath it.**  Dolphin's
> emulated GameCube Broadband Adapter (BBA HLE) silently rewrites the
> destination IP of every DNS packet from the game to whatever
> `BBA_BUILTIN_DNS` is set to. Whatever DNS server PSO thinks it's
> querying — whether that's the one in PSO's in-game network config or
> the one provided by DHCP — Dolphin ignores it and sends the packet
> to `BBA_BUILTIN_DNS` instead.
>
> The Dolphin default is `3.18.217.27`, which is
> [Schtserv](https://schtserv.com/), the long-running public PSO
> private server. That's why almost every Dolphin PSO player ends up
> on Schtserv "by magic" — because Dolphin ships with Schtserv's IP
> hardcoded.
>
> Two related traps that cost the maintainer of this doc many hours:
>
> 1. **`BBA_DNS` is a different setting** (older / TAP-mode) and does
>    nothing in HLE mode. The name is similar enough to be misleading.
> 2. **`BBA_BUILTIN_DNS` is a global-only setting** — it lives under
>    `System::Main`. Placing it in `GameSettings/<game-id>.ini` does
>    nothing; Dolphin silently ignores it there.
>
> See Dolphin source:
> [`BBA/BuiltIn.cpp`](https://github.com/dolphin-emu/dolphin/blob/master/Source/Core/Core/HW/EXI/BBA/BuiltIn.cpp)
> for the DNS-rewrite mechanism and
> [`Config/MainSettings.cpp`](https://github.com/dolphin-emu/dolphin/blob/master/Source/Core/Core/Config/MainSettings.cpp)
> for the default-value definition.

---

## Step 4 — Per-game settings (BBA HLE + raw memcard)

The per-game INI carries two settings that *can* live per-game and
matter for PSO specifically: the BBA HLE serial-port assignment, and a
raw memory card to replace Dolphin's default GCI Folder format (which
corrupts PSO's saved network info every boot).

```bash
mkdir -p /userdata/system/configs/dolphin-emu/GameSettings
mkdir -p /userdata/saves/dolphin-emu/GC/USA

cat > /userdata/system/configs/dolphin-emu/GameSettings/GPOE8P.ini <<'EOF'
# Per-game overrides for PSO Episode I & II / Plus (USA).

[Core]
# Serial Port 1 device = Broadband Adapter (HLE).
SerialPort1 = 12

# Dual-core CPU emulation — PSO's online code is heavy without it.
CPUThread = True

# Use a raw memory-card file in Slot A, NOT Dolphin's default
# GCI Folder. PSO writes a network-info file that the folder
# format corrupts on every boot.
SlotA = 1
MemcardAPath = /userdata/saves/dolphin-emu/GC/USA/MemoryCardA-PSO.USA.raw

[DSP]
# DSPHLE audio JIT for performance.
EnableJIT = True
EOF

cat /userdata/system/configs/dolphin-emu/GameSettings/GPOE8P.ini
```

> **Why `SerialPort1 = 12`?** It's the numeric ID Dolphin uses for
> "Broadband Adapter (HLE)" in its `EXIDeviceType` enum
> ([source](https://github.com/dolphin-emu/dolphin/blob/master/Source/Core/Core/HW/EXI/EXI_Device.h#L43)).
> This value is stable across all recent Dolphin and Batocera releases
> (2022 onward). Old values you might see online (`6`, `10`) are from
> pre-2021 Dolphin and silently *won't* be the HLE BBA — typical
> failure mode: PSO sees no network device at all and refuses to
> connect.

The `.raw` file doesn't have to exist beforehand — Dolphin creates it
the first time PSO writes anything to memcard.

---

## Step 5 — Verify Dolphin sees the BBA (optional but recommended)

Boot the game in EmulationStation: GameCube → PSO Episode I & II (or
Plus).

At the PSO main menu, **just check that Dolphin didn't error**. If
something's wrong with the BBA configuration, Dolphin throws an error
overlay (visible in the OSD) or silently disables network — both will
manifest as a connection failure in the next step.

You can also exit EmulationStation to Dolphin's standalone GUI:
**EmulationStation Main Menu → Quit → Launch Kodi/Other UI**. Then in
Dolphin: **Config → GameCube → SP1**. The dropdown should show
**"Broadband Adapter (HLE)"** selected.

---

## Step 6 — Configure PSO and connect

Boot the game and select **ONLINE GAME** from the title menu. What
happens next depends on which disc you're using:

### Original Episode I & II (v1.0 / v1.1)

PSO walks you through a one-time network configuration the first time
you connect. The screens are slightly different across disc revisions,
but the values are always the same:

| Setting | Value |
|---|---|
| IP Address | Automatic (DHCP) |
| DNS Server | Manual |
| Primary DNS | `54.173.68.119` |
| Secondary DNS | leave blank |
| User ID / Password | anything, or blank |

Save the config to Slot A and select **CONNECT**.

> *Why set Primary DNS if Dolphin's BBA HLE ignores it?* It doesn't
> matter on Dolphin — but it doesn't hurt either, and the same value
> is what real hardware needs (see the "real hardware" note at the
> bottom of this file). Setting it keeps the configuration portable.

### Plus (v1.2, USA Rev 2)

Plus has an additional 3-field registration screen Sega added as an
anti-piracy/anti-private-server measure. The server now requires a
registered account, so **enter the GameCube credentials the admin
assigned to you** — they must match exactly:

| Field | Length | Source |
|---|---|---|
| Serial Number | 10-digit number | from the admin |
| Access Key | 12 characters | from the admin |
| Password | up to 8 characters | from the admin |

When Plus asks "Save Password to Memory Card?" choose **Yes** so you
don't have to re-enter the password every session.

Plus may also walk you through the same network-setup screen as the
original. Same values as above; the in-game DNS doesn't matter on
Dolphin (Dolphin overrides it), but the settings still get saved.

### What happens behind the scenes

- PSO sends a DNS query for `game04.st-pso.games.sega.net` (Plus) or
  `gc01.st-pso.games.sega.net` (v1.0 / v1.1).
- **Dolphin's BBA HLE silently rewrites the destination to
  `BBA_BUILTIN_DNS` = `54.173.68.119`** — Josh's server.
- The server's DNS returns its own IP for that hostname.
- PSO opens a TCP connection to that IP on **port 9103** (Plus) or
  **port 9100** (v1.0 / v1.1).
- newserv's game-server handler accepts the connection and you land
  in the lobby.

If it works you'll see a welcome message like "Welcome to PSO Josh!"
in the upper-right corner.

---

## Step 7 — Play

You're online. Lobbies, games, quests, chat all work normally.
Cross-version play is enabled — friends on a different disc revision
(v1.0/v1.1/Plus) can play with you.

To use admin commands (only if your account has been granted `root` —
see [operations.md](operations.md#grant-yourself-admin)):

- `$ann <message>` — server-wide announcement
- `$debug` — enable debug mode for your client
- `$ban <player>` / `$kick <player>` / `$silence <player>`
- Full list: `$help` in-game, or
  [newserv's chat commands list](https://github.com/fuzziqersoftware/newserv/blob/master/README.md#chat-commands).

---

## Troubleshooting

When something fails, the order to diagnose is:

1. **Did your DNS query reach the server?** Have Josh tail the server log:
   ```bash
   ssh -i ~/.ssh/pso-server-deploy ubuntu@<server-ip>
   docker logs -f newserv | grep -i dns
   ```
   If your queries don't show up, the firewall is blocking you — you're
   not in `allowed_dns_cidrs`. Your IP probably changed; have Josh re-add
   it.

2. **Did your TCP connection reach the server?** Same place:
   ```bash
   docker logs -f newserv
   ```
   Look for `[GameServer] Client connected` when PSO opens its TCP
   connection.

3. **Did PSO accept the server's response?** The error message on
   PSO's screen is usually informative.

### Common failures

| Symptom | Likely cause | Fix |
|---|---|---|
| PSO connects to the wrong server (lobby looks unfamiliar, "Welcome to" message isn't yours) | `BBA_BUILTIN_DNS` not set; Dolphin defaulted to Schtserv | Re-run Step 3. Confirm with `grep BBA_BUILTIN_DNS /userdata/system/configs/dolphin-emu/Dolphin.ini` |
| `(No.100) You are banned from this server.` | Same as above — you're on Schtserv | Same fix |
| `(No.102) You could not be connected to the server.` | DNS resolved to your server but TCP failed — usually your IP isn't in `allowed_dns_cidrs` | Have Josh re-add your current public IP |
| `The network information file on the Memory Card in Slot A is corrupt` | Slot A is in GCI Folder mode | Re-run Step 4; confirm `SlotA = 1` and `MemcardAPath = ...` are in `GPOE8P.ini` |
| `Device connected to Serial Port 1 cannot be recognized.` | BBA HLE not active | Confirm `SerialPort1 = 12` in `GPOE8P.ini`; restart Dolphin |
| PSO sits at "Connecting to server..." forever | PSO's timeout is long. Wait 60s, then it'll error out clearly | Wait for the error message, then look at the table above |
| Save data appears corrupt after a disconnect | Don't pull the power on Dolphin mid-game | Restore from PSO's auto-save, or have Josh restore your character from the nightly S3 backup |

If something weird happens that's not in the table, run this on the
server and send Josh the output:

```bash
ssh -i ~/.ssh/pso-server-deploy ubuntu@<server-ip>
docker logs --since=5m newserv 2>&1 | tail -100
```

---

## Optional: making it work from outside your home

If you take your Batocera machine somewhere else, your public IP
changes. Two options:

- **Easy:** text Josh your new IP from `https://ifconfig.io` and wait a
  minute. He runs `terraform apply` to add it.
- **Less easy:** open the DNS allowlist a bit wider — e.g.
  `73.242.0.0/16` for your ISP's whole block. Josh sets this in
  `infra/terraform.tfvars`. Slightly less secure but you stop
  bothering him every time you change networks.

---

## Real GameCube hardware (FYI)

If you ever set this up on actual GameCube hardware with a Broadband
Adapter, the setup is the same logically but **all configuration happens
inside PSO** — there's no emulator config involved, and no
`BBA_BUILTIN_DNS` silent override to worry about.

On real hardware:

1. Plug a [GameCube BBA](https://en.wikipedia.org/wiki/GameCube_Broadband_Adapter)
   into the GameCube's high-speed serial port; connect to your home
   router via Ethernet.
2. Boot PSO → ONLINE GAME → Network Setup → set **Primary DNS** to
   `54.173.68.119`. Save to memcard.
3. Connect.

That's it. The BBA respects whatever DNS PSO tells it to use — no
emulator quirks. The catches are practical, not technical: BBAs are
rare and expensive on the secondary market, and the BBA's 2002 network
stack can be cranky on modern home routers (anything with mesh Wi-Fi
or unusual subnets).

---

## Reference

- **Server static IP:** `54.173.68.119`
- **Plus's login port:** TCP `9103`
- **Original disc's login port:** TCP `9100`
- **Dolphin's HLE BBA SerialPort1 value:** `12`
- **PSO Episode I & II (USA) game-ID prefix:** `GPOE8P` (version byte
  `0x00` = v1.0, `0x01` = v1.1, `0x02` = Plus)
- **Dolphin BBA HLE source — DNS rewrite mechanism:**
  [`BBA/BuiltIn.cpp`](https://github.com/dolphin-emu/dolphin/blob/master/Source/Core/Core/HW/EXI/BBA/BuiltIn.cpp)
- **Dolphin BBA HLE default DNS server (`3.18.217.27` = Schtserv):**
  [`Config/MainSettings.cpp`](https://github.com/dolphin-emu/dolphin/blob/master/Source/Core/Core/Config/MainSettings.cpp)
- **Server admin's contact:** josh@joshkautz.com
