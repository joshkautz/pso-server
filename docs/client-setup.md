# Connecting from Batocera + Dolphin

Step-by-step guide for getting PSO Episode I & II Plus (USA) connected to
the server from Batocera Linux running Dolphin. Tested on Batocera v41+ (Mar
2026 build, Dolphin master).

You'll do all of this once per player machine. Plan for ~15 minutes.

---

## Before you start

You need:

- A Batocera Linux install that boots to EmulationStation.
- The PSO disc image in your GameCube ROMs folder:
  `Phantasy Star Online Episode I & II Plus (USA) (Rev 2).rvz` at
  `/userdata/roms/gamecube/`.
- The server's static IP — ask Josh, or run
  `terraform -chdir=infra output instance_public_ip` from the repo.
- Your Batocera machine's public IPv4 (visit https://ifconfig.io from a
  browser on that machine, or `curl https://ifconfig.io` from SSH).
  You'll send this to Josh so he can add it to the DNS allowlist.
- A computer that can SSH into Batocera (any laptop on the same Wi-Fi).

---

## Step 1 — Send your public IP to Josh

Until your IP is in the server's DNS allowlist, your PSO client will
silently fail to connect (DNS queries to UDP 53 will time out). Josh runs
two commands and you'll be added within a minute. Don't skip this step.

---

## Step 2 — SSH into Batocera

Batocera's default credentials are `root` / `linux`. You'll need a
terminal program (Terminal on Mac, PuTTY or Windows Terminal on Windows,
any terminal on Linux).

Find Batocera's LAN IP from EmulationStation: **Main Menu → Network
Settings → IP Address**.

Then on your laptop:

```bash
ssh root@<batocera-lan-ip>
# password: linux
```

If SSH is disabled on your Batocera, enable it in **Main Menu → Network
Settings → Enable SSH** and try again.

---

## Step 3 — Configure Dolphin's broadband adapter

Dolphin has three different ways to emulate the GameCube's Broadband
Adapter (BBA); we use the **HLE** ("high-level emulation") variant which
routes the emulated GameCube's traffic through Batocera's network stack
directly. No virtual interfaces, no `tapserver` daemon — just works.

**Approach A — per-game config (recommended, doesn't affect other GC games):**

```bash
mkdir -p /userdata/system/configs/dolphin-emu/GameSettings
cat > /userdata/system/configs/dolphin-emu/GameSettings/GPSE8P.ini <<'EOF'
[Core]
SerialPort1 = 12
EOF
```

Why `GPSE8P`? That's the 6-character game ID for "PSO Episode I & II Plus
(USA)". Dolphin reads game-specific settings from
`GameSettings/<game-id>.ini` and they override the global Dolphin.ini.
You can confirm the ID by booting the game once and pressing **Tab** in
Dolphin's window — the title bar shows it. (If your title is different
or the ID is different, use that instead.)

**Approach B — global Dolphin config (simpler, affects all GameCube games
in Dolphin):**

```bash
# Make sure the config dir exists
mkdir -p /userdata/system/configs/dolphin-emu

# If Dolphin.ini already exists, edit it in place. If not, create it.
# This sed replaces the line if present, or appends it if not.
if [ -f /userdata/system/configs/dolphin-emu/Dolphin.ini ]; then
  grep -q '^\[Core\]' /userdata/system/configs/dolphin-emu/Dolphin.ini || \
    echo '[Core]' >> /userdata/system/configs/dolphin-emu/Dolphin.ini
  if grep -q '^SerialPort1' /userdata/system/configs/dolphin-emu/Dolphin.ini; then
    sed -i 's/^SerialPort1 *=.*/SerialPort1 = 12/' /userdata/system/configs/dolphin-emu/Dolphin.ini
  else
    sed -i '/^\[Core\]/a SerialPort1 = 12' /userdata/system/configs/dolphin-emu/Dolphin.ini
  fi
else
  printf '[Core]\nSerialPort1 = 12\n' > /userdata/system/configs/dolphin-emu/Dolphin.ini
fi
```

Either approach: confirm by reading the file back:

```bash
cat /userdata/system/configs/dolphin-emu/GameSettings/GPSE8P.ini
# or
cat /userdata/system/configs/dolphin-emu/Dolphin.ini
```

You should see `SerialPort1 = 12` somewhere under `[Core]`.

> **Why `12`?** It's the numeric ID Dolphin uses for "Broadband Adapter
> (HLE)" in its `EXIDeviceType` enum
> ([source](https://github.com/dolphin-emu/dolphin/blob/master/Source/Core/Core/HW/EXI/EXI_Device.h#L43)).
> This value is stable across all recent Dolphin and Batocera releases
> (2022 onward). Old values you might see online (`6`, `10`) are from
> pre-2021 Dolphin and will silently *not* be the HLE BBA — typical
> failure mode: PSO sees no network device at all.

---

## Step 4 — Verify Dolphin sees the BBA (optional but recommended)

Boot the game in EmulationStation: GameCube → PSO Episode I & II Plus.

At the PSO main menu, **just check that Dolphin didn't error**. If
something's wrong with the BBA configuration, Dolphin throws an error
overlay (visible in the OSD) or silently disables network — both will
manifest as failure in the next step.

You can also exit out of EmulationStation to Dolphin's standalone GUI:
**EmulationStation Main Menu → Quit → Launch Kodi/Other UI**. Then in
Dolphin: **Config → GameCube → SP1**. The dropdown should show
**"Broadband Adapter (HLE)"** selected.

---

## Step 5 — Configure PSO's in-game network settings

This is configured inside PSO itself, not in Dolphin. The settings are
saved to PSO's save file (memory card image) so you only do this once.

1. Boot the game (`ONLINE GAME` → `START`).
2. PSO will probably prompt you for a Hunter's License the first time.
   You can put anything in. The server accepts unregistered users by
   default; an account is created the first time you connect.
3. From the online menu, go to **NETWORK CONFIGURATION** → create or
   edit a config (give it a name like "Lightsail").
4. Fill in:

   | Setting | Value |
   |---|---|
   | **IP Address** | Automatic (DHCP) |
   | **Subnet Mask** | Automatic |
   | **Default Gateway** | Automatic |
   | **DNS Server** | **Manual** ← this is the important one |
   | **Primary DNS** | **the server's static IP** (e.g. `54.173.68.119`) |
   | **Secondary DNS** | leave blank |
   | DHCP Host Name | Not Set |
   | Proxy Server | Not Set |
   | User ID / Password | anything, or blank |

5. Save and select **CONNECT**.

What happens behind the scenes:

- PSO sends a DNS query for `pso20.sonic.isao.net` (or similar) to the
  Primary DNS address you set.
- That's the server, which responds with its own IP.
- PSO opens a TCP connection to the returned IP on port 9103.
- The server's `[GameServer]` accepts the connection and you land in the
  lobby.

If it works you'll see "Server name: PSO Josh" in the upper-right
corner. If it doesn't, see Troubleshooting below.

---

## Step 6 — Play

You're online. Lobbies, games, quests, BB chat all work normally. Cross-
version play is enabled — other GC disc revisions (and friends on
Dreamcast emulators, PSO PC, etc. if anyone has them) can play with you.

To use admin commands (only if your account has been granted `root` —
see [operations.md](operations.md#grant-yourself-admin)):

- `$ann <message>` — server-wide announcement
- `$debug` — enable debug mode for your client
- `$ban <player>` / `$kick <player>` / `$silence <player>`
- Full list: `$help` in-game, or
  https://github.com/fuzziqersoftware/newserv/blob/master/README.md#chat-commands

---

## Troubleshooting

When something fails, the order to diagnose is always:

1. **Did your DNS query reach the server?** Have Josh tail the server log:
   ```bash
   ssh -i ~/.ssh/pso-server-deploy ubuntu@<server-ip>
   docker logs -f newserv | grep -i dns
   ```
   If your queries don't show up, the firewall is blocking you — you're
   not in `allowed_dns_cidrs`. Your IP changed; have Josh re-add it.

2. **Did your TCP connection reach the server?** Same place:
   ```bash
   docker logs -f newserv
   ```
   You should see `[GameServer] Client connected` when PSO opens its TCP
   connection. If DNS works but TCP doesn't, it's an outbound block on
   your network — unusual but possible on corporate Wi-Fi.

3. **Did PSO accept the server's response?** Look at PSO's screen. The
   error message (if any) is usually informative.

Common failures:

| Symptom | Likely cause | Fix |
|---|---|---|
| "Cannot connect to server" right after pressing CONNECT, with no log entry server-side | DNS allowlist doesn't include you | Send your current public IP to Josh |
| DNS query reaches server, returns OK, but PSO never opens TCP | Outbound TCP block on your network (unusual) | Try a different Wi-Fi, or VPN |
| PSO sits at "Connecting to server..." forever | Cosmetic — PSO's connection timeout is long. Wait 60s, then it'll error out clearly | Wait for the error message, then look at the table above |
| Plus-specific "same network" error (rare) | The server appears on your local subnet (it shouldn't with cloud hosting) | Verify your local network's subnet doesn't include `54.173.68.0/24` |
| Lobby loads but you can't see other players | They're not connected, or they're playing a different episode | Confirm with `$li` in-game |
| Save data appears corrupt after disconnect | Don't pull the power on Dolphin mid-game | Restore from PSO's auto-save, or have Josh restore your character from the nightly S3 backup |

If something weird happens that's not in the table, run this on the
server and send Josh the output:

```bash
ssh -i ~/.ssh/pso-server-deploy ubuntu@<server-ip>
docker logs --since=5m newserv 2>&1 | tail -100
```

---

## Optional: making it work from outside your home

If you take your Batocera machine to a friend's house or to a cafe, your
public IP changes. Two options:

- **Easy:** text Josh your new IP from `https://ifconfig.io` and wait a
  minute. He runs `terraform apply` to add it.
- **Less easy:** open the DNS allowlist a bit wider — e.g.
  `73.242.0.0/16` for your ISP's whole block. Josh sets this in
  `infra/terraform.tfvars`. Slightly less secure but you stop bothering
  him every time you change networks.

---

## Reference

- **Server static IP:** `54.173.68.119`
- **Default game port** (PSO US Plus Rev 2 talks to TCP `9103`)
- **Dolphin's HLE BBA SerialPort1 value:** `12`
- **PSO Episode I & II Plus (USA) game ID:** `GPSE8P`
- **Server admin's contact:** josh@joshkautz.com
