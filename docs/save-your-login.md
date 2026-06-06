# Save your login

Stop retyping your UserID and password every time you launch PSO Blue Burst. The
download includes a **one-file helper** that writes both into the client — the
password is stored exactly the way the game stores it (encrypted). No installs; it
uses only what your OS already ships.

## macOS

1. Unzip the download — a **PSOBB-macOS** folder with **`PSOBB.app`** and
   **`setup.command`**.
2. **Clear the download warning once** (macOS blocks unsigned downloads): open
   **Terminal**, type `xattr -drs com.apple.quarantine ` (with a space), drag the **PSOBB-macOS** folder
   onto the window, and press **Enter**. *(No Terminal? See "Get past the security
   warning" below.)*
3. **Close the game** if it's open, then double-click **`setup.command`** and type
   your **UserID** and **password**. It finds **`PSOBB.app`** sitting right next to
   it in the folder (or in **Applications**, if you already moved it there); if it
   can't, it asks you to drag the app onto the window.

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

## Get past the security warning

macOS (“Apple could not verify … malware”) and Windows (SmartScreen) warn because
this client and helper are **not code-signed** — signing needs a paid Apple/Windows
certificate a small private server doesn't bother with. It's about *who made it, not
whether it's malware*. To allow it (once per machine):

- **macOS:** clear the download quarantine for the whole folder — type `xattr -drs com.apple.quarantine `
  in **Terminal**, drag the **PSOBB-macOS** folder in, press **Enter**. No Terminal?
  Double-click an item → **Done**, then **System Settings → Privacy & Security →
  Open Anyway** (once per item). The old right-click→Open shortcut no longer works on
  recent macOS.
- **Windows:** on the SmartScreen prompt, click **More info → Run anyway**.
