# Connecting from a real GameCube (Broadband Adapter)

Step-by-step guide for getting **PSO Episode I & II Plus** (or vanilla
Episode I & II) connected to the server from real GameCube hardware via
the official Broadband Adapter. newserv treats every retail GC disc as
the same `Version::GC_V3` client revision, so v1.0, v1.1, and Plus
follow the same path on the wire — the only difference is the disc
revision sitting in the drive.

Plan for ~20 minutes per player, ~one minute of that on the server side
(Josh adds your IP to the allowlist). After the first setup the console
remembers your ISP profile, so future sessions are just "power on →
Online".

If you're on **Dolphin** instead of a real console, see
[`client-setup-dolphin.md`](client-setup-dolphin.md). On a Batocera
Linux machine running Dolphin, see [`client-setup.md`](client-setup.md).

---

## Before you start

You need:

- **A GameCube console** (any region — US, JP, EU, all work; the BBA
  fits all of them).
- **The official Broadband Adapter** — Sega/Nintendo part number
  **DOL-015**. This is the chunky black brick with an Ethernet jack
  that slots into Serial Port 1. The Modem Adapter (DOL-012) **will
  not work** — PSO's online code on Plus only speaks Ethernet.
- **A standard Ethernet cable** (Cat 5 / 5e / 6 all fine).
- **A router with DHCP enabled.** Almost every consumer router does
  this by default. The GameCube only supports IPv4.
- **A PSO Episode I & II Plus disc** (USA, JP, or EU — all speak
  the V3 protocol). Vanilla Episode I & II (v1.0 / v1.1) also work
  with identical steps; the in-game menus look slightly older but the
  Network Configuration screen is the same.
- **A GameCube memory card** with at least a few free blocks. PSO
  stores its network settings file ("PSO Network Info") on the card,
  separate from save data — without it the console forgets your ISP
  profile every reboot.
- **Your network's public IPv4** — visit https://ifconfig.io from any
  device on the same network. You'll send this to Josh so he can add
  it to the server's DNS allowlist.
- **A GameCube controller.**

> The BBA was the rarest official Nintendo accessory at retail and
> stays surprisingly expensive on the secondhand market (~$80–$150 in
> 2026). There's no homebrew substitute — the GameCube's serial port is
> a proprietary pinout and PSO doesn't accept other network paths.

---

## Step 1 — Send your public IP to Josh

Until your home/network's public IP is in the server's allowlist, the
GameCube's DNS lookup of PSO's hardcoded Sega hostnames (e.g.
`game04.st-pso.games.sega.net`) will silently get NXDOMAIN. Josh runs
`terraform apply` and you'll be in within a minute. **Don't skip this
step.**

---

## Step 2 — Install the Broadband Adapter

1. **Power the console off** and unplug it from the wall. The BBA
   pulls power from Serial Port 1; don't hot-swap.
2. Flip the console upside down. You'll see two covered slots on the
   bottom labeled **SERIAL PORT 1** (closer to the front) and **SERIAL
   PORT 2** (closer to the back). The BBA goes in **Serial Port 1**.
3. Pop the Serial Port 1 cover off (it slides out with a fingernail).
4. Align the BBA's connector with the port and press firmly until it
   clicks. There's only one orientation.
5. Plug the Ethernet cable into the back of the BBA. The other end
   into a free port on your router or switch.
6. Power the console back on.

> If the BBA doesn't sit flush, double-check you're on Serial Port 1
> (not 2). Serial Port 2 is the same physical connector but PSO
> ignores it.

---

## Step 3 — Configure PSO's network settings

The Plus menu wording is described here; vanilla Ep I & II uses the
same screens with minor text differences.

1. Boot PSO with a memory card in **Slot A**.
2. At the title screen, press **START**.
3. Select **ONLINE GAME**.
4. PSO will tell you it's creating a fresh **PSO Network Info** file
   on your memory card on first run. Let it.
5. The "Hunter's License" notice appears — select **Agree** to
   continue.
6. The first time, you'll be taken straight to **Network
   Configuration**. (On later boots, choose **Edit ISP Settings** from
   the Online Game submenu to come back here.)
7. Create a new ISP profile — name it anything you like
   (e.g. "PSO Josh"):

   | Field | Value |
   |---|---|
   | **Use DHCP** | **Yes** |
   | **Primary DNS** | **54.173.68.119** |
   | **Secondary DNS** | leave blank (or set to 54.173.68.119 too) |
   | **Use proxy** | No |
   | **PPPoE** | No |

8. Save the profile back to the memory card.

> **Why this works.** newserv runs its own DNS server on UDP 53 on the
> public address. PSO's online code only ever resolves a handful of
> hardcoded Sega hostnames (`game04.st-pso.games.sega.net` and friends).
> Pointing the console's Primary DNS at the server makes those lookups
> return the server's IP instead of NXDOMAIN, and from there PSO
> opens a normal TCP connection on port 9103 just like it would have
> in 2003. No HTTPS, no certificates, no patches — PSO V3 was a
> plain-TCP protocol.

---

## Step 4 — Register your account

Back at the Online Game submenu, choose **Game Start** (or **Connect**
on vanilla). PSO will:

- Query DNS for `game04.st-pso.games.sega.net` (gets routed to the
  server).
- Open TCP to that IP on port 9103.
- Receive the welcome packet from newserv.

The first time you connect from a brand-new memory card, PSO walks
you through entering your **Serial Number / Access Key / Password**
trio:

1. PSO will show the **"In order to play PSO Episode 1 and 2 online,
   you must purchase a Hunter's License."** notice — select **Agree**.
2. **Enter the Serial Number** Josh gave you — a 10-digit number from
   your HUNTER's License paper (or the one Josh assigned for this
   server).
3. **Enter the Access Key** — 12 characters, same source.
4. **Enter the Password** — up to 8 characters. **Save it to the
   memory card** when prompted so you don't have to retype it every
   session.
5. **Game Certificate Confirmation** — verify and press **Yes**.

If you see **"Welcome to PSO Josh!"** in a yellow text box in the
lobby, you're in.

---

## Step 5 — Subsequent sessions

After the first run the console remembers everything. The fast path is:

1. Power on with the PSO disc and your memory card.
2. Press **START** → **ONLINE GAME** → **Game Start**.
3. PSO reads your ISP profile and saved login from the memory card,
   connects, and drops you in the lobby.

No re-entering passwords, no DNS reconfiguration. If you ever change
networks (e.g. you take the console to a friend's house), you'll need
the new public IP allowlisted **and** the new local network needs to
be DHCP-capable — but the saved ISP profile keeps the DNS setting, so
nothing else changes.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| **The Broadband Adapter could not be detected** at the Network Configuration screen | BBA not seated, or in Serial Port 2 instead of 1 | Power off, reseat the BBA in Serial Port 1, power back on |
| `(No.100) You are banned from this server.` | newserv's DNS returned a blackhole address (your public IP isn't allowlisted) | Re-send Josh your current public IP from https://ifconfig.io |
| `(No.102) You could not be connected to the server.` | DNS resolved correctly but TCP didn't complete — usually a router-level filter on port 9103 outbound, or the server is briefly down | Test outbound from another machine on the same network; ping Josh if the dashboard at https://pso.joshkautz.com shows offline |
| "Could not connect to the network" / DHCP fails | Router DHCP pool exhausted, or BBA not getting a link | Check the green LED on the BBA — it should be lit when the cable is plugged in. Try a different port on the router |
| The console finds the server but the lobby shows "Welcome to PSO Josh!" with no name color | First-time account, no character data yet — this is the expected state | Create a character in the Character Selection menu; the server auto-creates the account on first connect |
| Disconnects mid-quest with `(No.103) The connection has timed out.` | Wi-Fi bridge / powerline adapter introducing latency spikes the BBA can't tolerate | PSO's online code is fragile to >500ms hiccups. Use wired Ethernet end-to-end between the BBA and the router |
| `(No.101) Cannot establish a connection.` immediately after the Sega Online splash | DNS query landed somewhere that's not our newserv (Primary DNS typo, or your ISP intercepting port 53 queries) | Re-check Primary DNS is exactly `54.173.68.119`. If your ISP intercepts port-53 traffic (some do), try Secondary DNS pointing at the same address |

---

## Notes for the curious

- **The BBA only does Ethernet.** The Modem Adapter (DOL-012) speaks
  PPP and was used for dial-up; PSO's online code on Plus only
  supports the BBA path. The Modem Adapter would have to dial a real
  PPP endpoint — which Sega's servers used to provide and ours
  doesn't.
- **No patches required on the disc.** newserv speaks PSO's wire
  protocol natively. The disc you bought in 2003 talks to it
  unmodified — no Action Replay codes, no Swiss patches, no Nintendont.
- **You can cross-play with Dolphin, Xbox, PC, and Dreamcast players**
  in Episode 1 thanks to the wide CompatibilityGroups setting on the
  server. See the matrix on https://pso.joshkautz.com for which
  episodes are sharable.
- **Episode III: C.A.R.D. Revolution** uses the same BBA hardware but
  a different disc. It's mechanically a card game and stays in its
  own pool — Ep 3 players can only play with other Ep 3 players.
