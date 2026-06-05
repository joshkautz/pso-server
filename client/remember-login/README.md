# Remember my login

One-file helpers that pre-fill your **PSO Blue Burst** UserID **and password** at
the login screen. These are what ship inside the download zips:

- **`remember-login.command`** (macOS) — bash + Perl, both built into macOS.
- **`remember-login.bat`** (Windows) — a batch/PowerShell polyglot; PowerShell is
  built into Windows.

Each is fully self-contained (the cipher and its constant tables are embedded) and
needs **no installs**. Run it, type your UserID + password, done. It writes three
values under `HKCU\Software\SonicTeam\PSOBB`: `ACCOUNT` (UserID), `ACCOUNT_CHECK`
(remember flag), and `PASSWORD` — the 48-byte encrypted blob the game expects (the
password run through PSOBB's custom 4-round Blowfish, keyed by the UserID;
reverse-engineered from `Psobb.exe`).

Player-facing instructions: [`docs/save-your-login.md`](../../docs/save-your-login.md).

## `remember-login.py` — reference + admin tool

The Python reference implementation of the cipher (verified byte-for-byte against
the game binary; also used to verify the `.command`/`.bat`). Not shipped in the
downloads. Two uses:

- `python3 remember-login.py` — interactive; bakes into the local install.
- `python3 remember-login.py --emit USER PASS` — writes a ready-made `USER.reg`
  (Windows) / `USER-macos.command` (macOS) login file an admin can hand to a player.

## Verification

- `remember-login.py` is checked against the game binary's own crypto functions.
- `remember-login.command` (Perl) and `remember-login.bat` (PowerShell) are each
  verified to produce identical output to `remember-login.py`.
- The Windows `.bat` is exercised end-to-end on a real Windows runner by
  [`.github/workflows/test-windows-login.yml`](../../.github/workflows/test-windows-login.yml):
  it runs the `.bat`, reads the registry back, and compares to the Python reference.
