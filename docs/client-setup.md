# Connecting to the server (Batocera + Dolphin)

For players running PSO Episode I & II Plus (USA) under Dolphin on Batocera Linux.

## Prereqs on each player's machine

- Batocera Linux installed and booting
- `Phantasy Star Online Episode I & II Plus (USA) (Rev 2).rvz` in the
  GameCube ROMs directory
- The static IP address of the server (the value of
  `terraform output instance_public_ip`)

## 1. Configure Dolphin's GameCube BBA

The Plus version refuses to connect to a server on the same LAN, but
our server is on AWS, so that check is satisfied automatically.

We use Dolphin's HLE Broadband Adapter — it routes the emulated GameCube's
network through the host (Batocera) using Dolphin's built-in network stack.
No virtual TAP interface, no tapserver.

Easiest path: SSH into Batocera (`ssh root@<batocera-ip>`, password
`linux`) and edit `/userdata/system/configs/dolphin-emu/Dolphin.ini`:

```ini
[Core]
SerialPort1 = 10      ; "Broadband Adapter (HLE)" — verify in Dolphin GUI
```

The numeric `SerialPort1` value has shifted between Dolphin releases.
To verify, open Dolphin's own GUI once (locally or via Batocera's app
menu), go to **Config → GameCube → SP1**, set to **Broadband Adapter
(HLE)**, save, then read back the line.

## 2. Configure PSO's in-game network

Boot the ROM in Batocera and at the PSO main menu:

1. **ONLINE GAME**
2. (If prompted) Hunter's License: anything; newserv accepts unregistered
   users by default.
3. **NETWORK CONFIGURATION** → create or edit a config.
4. Settings:

   | Setting | Value |
   |---|---|
   | IP Address | Automatic (DHCP) |
   | Subnet Mask | Automatic |
   | Default Gateway | Automatic |
   | **DNS Server** | **Manual** |
   | **Primary DNS** | **`<server static IP>`** |
   | DHCP Host Name | Not Set |
   | Proxy Server | Not Set |

5. Save and select **CONNECT**.

PSO will DNS-resolve `pso-mp01.sonic.isao.net` (or similar) through
newserv's DNS, get the server IP back, then TCP-connect on port 9103
(for the US v1.2 Plus disc — newserv listens on the whole GC range so
it works for any disc).

## Troubleshooting

When something fails, the first diagnostic is always: SSH into the server
and tail the logs.

```bash
ssh -i ~/.ssh/pso-server-deploy ubuntu@<server-ip>
docker logs -f newserv
```

Then try to connect from PSO. If the log shows no incoming connection at
all, the problem is networking (firewall, DNS, IP misconfig). If it shows
the connection but a protocol error, it'll tell you what's wrong.

| Symptom | Likely cause |
|---|---|
| "Cannot connect to server" + no log entry server-side | Lightsail firewall missing UDP 53 or TCP 9103; or `Primary DNS` in PSO is wrong |
| DNS query reaches newserv but PSO never makes a TCP connection | `LocalAddress`/`ExternalAddress` in `config.json` is wrong (should be `0.0.0.0` for cloud) |
| "Server is full" or similar weirdness right after connecting | Cached account in `system/accounts/` is stale; SSH in and inspect |
| Plus-specific "same network" error | Should not happen with AWS hosting. If it does, double-check the GameCube's IP (under `Network Configuration`) isn't somehow in the same /24 as the server's IP (it won't be unless something is very wrong) |

## Multiplayer

Each friend follows the same steps with the same server IP as their DNS.
They'll see each other in lobbies automatically. Cross-version play
between GC disc revisions is enabled by default.
