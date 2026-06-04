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

Grab your platform from the **PSO Blue Burst (PC)** card on
[pso.joshkautz.com](https://pso.joshkautz.com):

| Platform | File | Notes |
|---|---|---|
| **macOS** | `PSOBB-macOS.zip` (~1 GB) | Apple Silicon (M1–M4) only |
| **Windows** | `PSOBB-Windows.zip` (~510 MB) | Windows 10/11 |

## 3. Install & first launch

### macOS (Apple Silicon)

1. Double-click the zip → you get **PSOBB.app**. Drag it to your **Applications**
   folder.
2. The app is unsigned, so macOS quarantines it. Clear that once — open
   **Terminal** and paste:
   ```sh
   xattr -cr /Applications/PSOBB.app && open /Applications/PSOBB.app
   ```
   (Equivalent: right-click the app → **Open** → **Open** in the dialog.)
3. The game opens in a normal, resizable window. To keep it one click away, drag
   **PSOBB.app** from Applications onto your Dock.

> Apple Silicon only — this build won't run on Intel Macs.

### Windows

1. Unzip the folder anywhere (e.g. your Desktop).
2. Run **`Psobb.exe`** — it connects straight to the server and handles the patch
   check itself. (Don't use `online.exe`; it's the standalone patcher and isn't
   pointed at this server.)

## 4. Log in & play

1. At the title screen, **click the window** so it has focus, then type your
   **UserID** and **password** and press **Enter**.
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
| macOS: *"PSOBB is damaged / can't be opened"* | You skipped step 2 — run `xattr -cr /Applications/PSOBB.app`. |
| Mac laptop: can't open the menu | The menu key is **Home = Fn + Left Arrow**, or use **F12**. |
| Keystrokes do nothing at login | Click the window first so it has focus, then type. |
| Won't connect / login fails | Confirm your UserID & password with the admin; check your internet. |
| macOS: Dock icon shows a wine glass | You pinned the running game tile — instead pin **PSOBB.app** from Finder/Applications. |

The macOS app bundles its own Wine engine, so there's nothing else to install.
