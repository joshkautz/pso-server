# Remember my login

Tiny helper scripts that pre-fill your **PSO Blue Burst** UserID + password on the
client's login screen, so you don't retype them every launch.

They set three values under `HKEY_CURRENT_USER\Software\SonicTeam\PSOBB` — the same
keys the client itself reads:

| Value | Type | Meaning |
|---|---|---|
| `ACCOUNT` | string | your UserID (pre-fills the **User ID** field) |
| `PASSWORD` | string | your password (pre-fills the **Password** field) |
| `ACCOUNT_CHECK` | dword `1` | remember the password |

## macOS

Double-click **`remember-login-macos.command`** (or run
`bash remember-login-macos.command`). It finds `PSOBB.app`, asks for your UserID +
password, and writes them into the app's bundled Wine registry. A timestamped
backup of the registry is saved next to it (`user.reg.bak-…`).

> Close the game first if it's running — Wine rewrites the registry on exit.
> If macOS blocks the script, right-click it → **Open**, or run it from Terminal.

## Windows

Double-click **`remember-login-windows.bat`**. It asks for your UserID + password
and writes them into your registry.

> Close `Psobb.exe` first if it's running.

## Notes

- Re-run any time to change the saved login.
- The password is stored in the registry in **plain text** — that's just how the
  2004 client works (it's the same value you'd type at the screen, only saved).
  Don't run this on a shared or public computer.
