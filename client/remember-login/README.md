# Remember my login

Pre-fill your **PSO Blue Burst** UserID **and password** on the login screen, so
you never retype either one.

Yes — the password too. The Tethealla client stores it the way the game expects:
a 48-byte encrypted blob at `HKCU\Software\SonicTeam\PSOBB\PASSWORD`, equal to your
password run through PSOBB's own 4-round Blowfish cipher **keyed by your UserID**
(reverse-engineered from `Psobb.exe`). `remember-login.py` reproduces that exactly,
so the game decrypts it and fills both fields in. It also sets `ACCOUNT` (your
UserID) and `ACCOUNT_CHECK` (the remember flag).

## Easiest — your personal login file (no setup)

Ask the admin for your personal login file and run it:

- **Windows:** double-click **`yourname.reg`** → *Yes* to import.
- **macOS:** double-click **`yourname-macos.command`**.

Launch the game and both fields are filled. These files contain your (encrypted)
password, so the admin sends them privately. An admin makes one with:

```
python3 remember-login.py --emit YourName YourPassword
```

which writes `YourName.reg` (Windows) and `YourName-macos.command` (macOS).

## Do it yourself — `remember-login.py` (needs Python 3)

Double-click **`remember-login-macos.command`** / **`remember-login-windows.bat`**
(they just launch `remember-login.py`), or run `python3 remember-login.py`. It asks
for your UserID + password and writes them into your install — the PSOBB.app Wine
registry on macOS, or the Windows registry. Needs
[Python 3](https://www.python.org/); works on both platforms.

> Close the game first — it rewrites the registry on exit. On macOS a timestamped
> backup of the Wine registry is saved next to it (`user.reg.bak-…`).

## Notes

- Re-run any time to change the saved login.
- `remember-login.py` is fully self-contained: the cipher and its constant tables
  are embedded, so it needs no game files and no third-party packages.
- Known client quirk (only relevant if you ever use the in-game launcher's own
  save-password instead): passwords starting with `a`/`A` don't save cleanly there.
  This tool writes the binary blob directly and isn't affected.
