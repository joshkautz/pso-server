# Save your login

Stop retyping your UserID and password every time you launch PSO Blue Burst. The
download includes a **one-file helper** that writes both into the client — the
password is stored exactly the way the game stores it (encrypted). No installs; it
uses only what your OS already ships.

## macOS

1. Unzip the download — you get **`PSOBB.app`** and **`setup.command`**.
2. **Close the game** if it's open.
3. Double-click **`setup.command`**.
   - If macOS blocks it: right-click it → **Open** → **Open**.
4. Type your **UserID** and **password** when asked.

Launch `PSOBB.app` — both fields are pre-filled; just press Start. Run the helper
again any time to change them.

## Windows

1. Unzip the download.
2. **Close** `Psobb.exe` if it's open.
3. Double-click **`setup.bat`**.
   - If SmartScreen warns (“Windows protected your PC”): **More info → Run anyway**.
4. Type your **UserID** and **password** when asked.

Launch `Psobb.exe` — both fields are pre-filled. Run the helper again any time to
change them.

## What does it actually do?

It sets three values under `HKEY_CURRENT_USER\Software\SonicTeam\PSOBB` — the same
keys the game itself uses:

- `ACCOUNT` — your UserID,
- `ACCOUNT_CHECK` — the “remember” flag,
- `PASSWORD` — your password, encrypted with the game's own cipher (a 48-byte blob).

It only touches your own user settings (the macOS app's bundled registry, or your
Windows user registry). Nothing else is changed, and nothing is sent anywhere.
