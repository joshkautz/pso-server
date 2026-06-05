# Documentation index

Guides for running this server and onboarding players. Jump to the one that matches
what you're doing.

## Running the server (operators)

- **[operations.md](operations.md)** — the runbook: add a player, edit config, view
  logs, grant in-game admin, backups & restore, upgrade newserv, emergency recovery.
- **[../infra/README.md](../infra/README.md)** — the Terraform / AWS Lightsail
  infrastructure.
- **[../CLAUDE.md](../CLAUDE.md)** — architecture, the access-control model, the
  account file format, and the "interactive shell isn't reachable in Docker" gotcha.

## Onboarding players (clients)

- **[client-setup-blueburst.md](client-setup-blueburst.md)** — PC (Blue Burst):
  download, install, controls.
- **[save-your-login.md](save-your-login.md)** — the one-file `setup` helper that
  pre-fills your UserID **and** password.
- **[client-setup-dolphin.md](client-setup-dolphin.md)** — GameCube on Dolphin (desktop).
- **[client-setup.md](client-setup.md)** — GameCube on Batocera + Dolphin (handhelds / HTPCs).
- **[client-setup-gamecube.md](client-setup-gamecube.md)** — GameCube on real hardware (Broadband Adapter).
- **[character-transfer.md](character-transfer.md)** — move a character between
  platforms (`$savechar` / `$loadchar` / `$bbchar`).

## Content

- **[community-quests.md](community-quests.md)** — installing custom quests.
- **[community-quest-sources.md](community-quest-sources.md)** — where to find them.

## The access model in one paragraph

Anyone with an **account** can play; accounts are pre-created by the admin
(`AllowUnregisteredUsers=false`). One account can hold a Blue Burst login
(UserID/password) **and** a GameCube login (serial / access key / password) — same
player, either platform. The DNS allowlist is open (`0.0.0.0/0`) and is no longer
the gate; it only ever affected console clients. See *Accounts & access control* in
[`../CLAUDE.md`](../CLAUDE.md) and the *Add a player* sections of
[operations.md](operations.md).
