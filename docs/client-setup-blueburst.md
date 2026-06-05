# PSO Blue Burst — setup & controls

How to download, install, and play the **Blue Burst** PC client for this server.
The client is already pointed at the server — you just download, unzip, and log in.

> Unlike the GameCube setup, **Blue Burst needs no IP allowlisting**. The client
> connects straight to the server's public address — there's no "send the admin
> your IP" step here.

---

## 1. Get a UserID

Blue Burst requires a login. **Ask the admin for a UserID and password** before
you start — you'll enter them at the title screen.

## 2. Download

Grab your platform from the **PC (Blue Burst)** card on
[pso.joshkautz.com](https://pso.joshkautz.com):

| Platform | File | Notes |
|---|---|---|
| **macOS** | `PSOBB-macOS.zip` (~1 GB) | Apple Silicon (M1–M4) only |
| **Windows** | `PSOBB-Windows.zip` (~510 MB) | Windows 10/11 |

## 3. Install & first launch

### macOS (Apple Silicon)

1. Double-click the zip → a **PSOBB-macOS** folder with **PSOBB.app** and
   **setup.command** inside.
2. macOS quarantines unsigned downloads. Clear it once for the whole folder — open
   **Terminal**, type `xattr -drs com.apple.quarantine ` (with a trailing space), drag the **PSOBB-macOS**
   folder onto the window, and press **Enter**:
   ```sh
   xattr -drs com.apple.quarantine <drag the PSOBB-macOS folder here>
   ```
   **Drag the folder in — don't type the path.** Dragging fills in the exact
   location and escaping; the folder is often on the **Desktop** (not Downloads),
   and a re-download may have a `(1)` in its name, so a typed path usually misses
   (and a quoted `~` won't expand to your home folder). Clear quarantine **before
   moving `PSOBB.app` to Applications** — if you already moved it, drag
   `/Applications/PSOBB.app` into the same command too, or it stays quarantined and
   opens as *"damaged."*
   (No Terminal? Double-click an item, click **Done** on the warning, then open
   **System Settings → Privacy & Security** and click **Open Anyway** — once per item.
   The old right-click→Open trick no longer works on recent macOS.)
3. Run **setup.command** to save your login — it finds **PSOBB.app** right next to
   it in the folder; see [Save your login](save-your-login.md). Then drag
   **PSOBB.app** to **Applications** (and onto your Dock if you like) and open it —
   a normal, resizable window.

> Apple Silicon only — this build won't run on Intel Macs.

### Windows

1. Unzip the folder anywhere (e.g. your Desktop).
2. Run **`Psobb.exe`** — it's the only program you launch; it connects straight to
   the server and handles the patch check itself.

## 4. Log in & play

1. At the title screen, **click the window** so it has focus, then type your
   **UserID** and **password** and press **Enter**.
   - *Tired of retyping it?* The download includes a one-file **setup** helper
     (`setup.command` on macOS, `setup.bat` on Windows) that pre-fills your UserID
     **and password** — run it once and type them. See [Save your login](save-your-login.md).
2. First time in: create a character — pick a **profession** (Hunter / Ranger /
   Force), a type, and a look.

---

## 5. Controls

PSO is a 2004 console game, so the controls surprise everyone. Two things to know
up front:

- **There is no single "attack" button.** Combat uses an **Action Palette** — a
  row of three slots you trigger with the **← ↓ →** arrow keys. **Ctrl** cycles
  to the next palette. A Hunter's first palette is usually Normal / Heavy /
  Special attack.
- **Movement is tank-style.** `W`/`S` go forward/back; `A`/`D` **turn** you.

### Keyboard cheat-sheet

| Action | Key |
|---|---|
| Move forward / back | **W** / **S** |
| Turn left / right | **A** / **D** |
| Attack / actions (palette L/M/R) | **← ↓ →** |
| Cycle action palette | **Ctrl** |
| Action shortcuts (items, etc.) | **1 – 0** |
| Open Main Menu | **Home** *(on a Mac laptop: **Fn + Left Arrow**)*, or **F12** |
| Confirm / Cancel | **Enter** / **Esc** |
| Chat | **Enter** / **Space**; **F11** toggles keyboard typing mode |
| Center / move camera | **↑** / right-click |
| Quit | macOS: close the window. Windows: **Alt + F4** |

### Remapping

**Main Menu → Options → Key Config.** Pick a preset (Default 1–4) or **Custom**,
then highlight a function and press the key you want.

A few keys — Decide, Cancel, **Menu Open/Close**, Select Up/Down/Left/Right — are
**locked** (the menus depend on them); the config screen labels that page
"Setting improper item" and beeps if you try. They can't be changed. On a Mac
that just means the menu is **Fn + Left Arrow** (= Home) or **F12**.

A controller plays much better — PSO was built for one. Plug in any
DirectInput/standard gamepad and map it under **Options → Pad Button Config**.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| macOS: *"PSOBB is damaged / can't be opened"* | You skipped step 2 — in Terminal type `xattr -drs com.apple.quarantine ` and drag **PSOBB.app** onto the window, then press Enter. |
| Mac laptop: can't open the menu | The menu key is **Home = Fn + Left Arrow**, or use **F12**. |
| Keystrokes do nothing at login | Click the window first so it has focus, then type. |
| Won't connect / login fails | Confirm your UserID & password with the admin; check your internet. |
| macOS: Dock icon shows a wine glass | You pinned the running game tile — instead pin **PSOBB.app** from Finder/Applications. |

The macOS app bundles its own Wine engine, so there's nothing else to install.
