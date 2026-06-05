# Blue Burst client distribution

Tooling for building and distributing the **PSO Blue Burst** client that's
pre-pointed at this server. The dashboard's "PC (Blue Burst)" card links to
the two downloads produced here:

- **macOS** (`PSOBB-macOS.zip`) — a self-contained app. The 32-bit game runs in
  a native, resizable window on Apple Silicon via Wine (CrossOver engine, through
  [Sikarugir](https://github.com/Sikarugir-App/Sikarugir)) plus a custom windowed
  Direct3D shim. Unzip → `xattr -cr PSOBB.app` → double-click.
- **Windows** (`PSOBB-Windows.zip`) — the classic Tethealla client, repointed.
  Unzips to a `PSOBB` folder; run `Psobb.exe` inside it (not `online.exe`, which is
  the standalone patcher and isn't pointed at this server).

Each zip also bundles the `remember-login` helper (saves your UserID **and
password** so the login screen pre-fills both) — see
[`remember-login/`](remember-login/).

Both are hosted on a public S3 bucket (`pso-server-downloads-<account>`) and are
**never committed** — they embed Sega's copyrighted client. This directory holds
only the tooling, which is freely shareable. Player-facing setup lives in
[`docs/client-setup-blueburst.md`](../docs/client-setup-blueburst.md).

## Layout

```
client/
  repoint/             Binary repoint tool (pure Python, no deps) + tests
    psobb_repoint.py
    test_psobb_repoint.py
  d3d8to9-windowed/    Windowed-mode Direct3D 8->9 shim patch (macOS app)
    windowed.patch     git-apply onto crosire/d3d8to9
    build.sh           cross-compile d3d8.dll with mingw-w64
    README.md          what the patch does and why
  remember-login/      Save your UserID+password into the client (mac + win)
    remember-login-macos.command
    remember-login-windows.bat
  publish.sh           zip the built clients + upload to S3
```

## Build from scratch (bring your own client)

You supply the Sega client; nothing copyrighted lives in this repo.

1. **Get the client** — the unpacked Tethealla `TethVer12513` English client
   (e.g. the mirror at <https://archive.org/details/psobb-tethealla-client>).

2. **Repoint it** at this server. The client stores the address in six slots,
   all default `127.0.0.1`:
   ```sh
   python3 repoint/psobb_repoint.py /path/to/Psobb.exe scan                       # preview
   python3 repoint/psobb_repoint.py /path/to/Psobb.exe teth --replace pso.joshkautz.com
   ```
   The address is a DNS hostname, so a distributed client keeps working even if
   the server's IP changes — you'd only update DNS. Tests:
   `python3 repoint/test_psobb_repoint.py` (14 cases, no Sega client needed).

   That repointed folder **is** the Windows download — `publish.sh` stages it under
   a clean folder name (`PSOBB`) and zips it.

3. **macOS only — build the windowed app:**
   ```sh
   brew install mingw-w64
   d3d8to9-windowed/build.sh        # -> d3d8.dll (self-contained, ~11 MB)
   ```
   Then wrap the repointed client with Sikarugir using the **CX24** engine
   (CrossOver 24 / new WoW64 — the only engine that runs the 32-bit client on
   macOS 26 Apple Silicon), drop `d3d8.dll` next to `Psobb.exe` in the prefix,
   and set the Wine override `d3d8=native`. The full recipe — prefix settings,
   the Retina display-mode gotcha, close-to-quit wiring, the Dock icon — is in
   [`d3d8to9-windowed/README.md`](d3d8to9-windowed/README.md) and the player guide.

## Publish updates

When the client changes, re-publish both zips (the dashboard links are stable —
no dashboard change needed):

```sh
AWS_PROFILE=pso-server \
  MAC_APP="$HOME/Applications/Sikarugir/PSOBB.app" \
  WIN_CLIENT="/path/to/TethVer12513_English" \
  ./publish.sh
```

`publish.sh` ensures the public bucket + policy exist (idempotent), zips both
sources, and uploads them to `downloads/`. Either source can be omitted to
publish just one platform.

## Why the bucket isn't in Terraform

The server infra (`infra/`) is Terraform-managed and gated behind the production
deploy environment, where `aws_lightsail_instance_public_ports` does a
destroy/recreate on change — applies you stage carefully. The downloads bucket
belongs to the client-distribution workflow, not the server, so it's kept out of
that pipeline. `publish.sh` is its single source of truth and is idempotent, so
re-running reconciles the bucket config.
