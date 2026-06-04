# Remember my UserID

Tiny helper scripts that save your **PSO Blue Burst** UserID so the login screen
pre-fills it every launch — no more retyping your account name.

They set two values under `HKEY_CURRENT_USER\Software\SonicTeam\PSOBB` (the same
keys the client uses):

| Value | Type | Meaning |
|---|---|---|
| `ACCOUNT` | string | your UserID (pre-fills the **User ID** field) |
| `ACCOUNT_CHECK` | dword `1` | the client's "remember" flag |

## macOS

Double-click **`remember-login-macos.command`** (or run
`bash remember-login-macos.command`). It finds `PSOBB.app`, asks for your UserID,
and writes it into the app's bundled Wine registry. A timestamped backup of the
registry is saved next to it (`user.reg.bak-…`).

> Close the game first if it's running — Wine rewrites the registry on exit.
> If macOS blocks the script, right-click it → **Open**, or run it from Terminal.

## Windows

Double-click **`remember-login-windows.bat`**. It asks for your UserID and writes
it to your registry. (Close `Psobb.exe` first if it's running.)

## What about the password?

PSO stores the password **separately and encrypted** — it's written by the game's
own launcher, not as a plain registry value — so a script can't bake it in. The
client's `PASSWORD` registry key holds ciphertext, so writing your password there
in plain text does nothing (it just shows blank). Two options:

- **Type it each session.** Your UserID is already filled in, so it's one field.
- **Windows only:** enable save-password in the launcher (`online.exe` → Options →
  More). The macOS build launches the game directly and skips the launcher, so
  there you just type it. (Known client quirk: passwords starting with `a`/`A`
  don't save cleanly — avoid those if you use the launcher's save.)

## Notes

- Re-run any time to change the saved UserID.
