# d3d8to9-windowed — run PSOBB in a real macOS window

A small patch on top of [crosire/d3d8to9](https://github.com/crosire/d3d8to9)
(the Direct3D 8 → Direct3D 9 wrapper) that forces **Phantasy Star Online: Blue
Burst** to run **windowed** instead of in its hardcoded fullscreen mode.

## Why this exists

PSOBB (the 2004 Tethealla client) hardcodes a fullscreen Direct3D 8 device — no
registry key or config switches it to windowed. On Apple Silicon the 32-bit
client runs through Wine's experimental WoW64, where that fullscreen device is
fragile: it grabs the display, freezes on focus loss, and leaves stuck processes
behind. Forcing a windowed device makes the game behave like a normal macOS
window — movable, resizable, Cmd-Tab-able, no display takeover.

The wrapper sits between the game and `d3d9`, so we can rewrite the presentation
parameters without touching Sega's copyrighted binary.

## What the patch changes

Three changes (see `windowed.patch`), all in the wrapper:

1. **`d3d8types.cpp` — `ConvertPresentParameters`.** After translating the
   game's D3D8 present params to D3D9, force `Windowed = TRUE`, clear
   `FullScreen_RefreshRateInHz`, and use the immediate presentation interval.
   This is the actual "make it a window" change, and it covers device creation,
   `Reset`, and additional swap chains in one place.

2. **`d3d8to9_base.cpp` — `Direct3D8` constructor.** Replace the host's real
   adapter-mode list with a clean, fixed set of standard resolutions
   (640×480, 800×600, 1024×768, 1280×960). PSOBB enumerates display modes before
   creating its device; on a Retina Mac it otherwise sees 130+ scaled modes it
   can't digest and exits *before* the device is ever created. A small, sane list
   lets its mode-selection succeed.

3. **`d3d8to9_base.cpp` — `GetAdapterDisplayMode`.** Report a standard
   1024×768 "current" mode (keeping the host pixel format) so the game's
   resolution logic gets a value it understands.

Without #2 and #3 the game never reaches device creation, so #1 alone is not
enough on Apple Silicon.

## Build

```sh
brew install mingw-w64     # one-time: 32-bit Windows cross compiler
./build.sh                 # writes ./d3d8.dll  (self-contained, ~11 MB static)
```

## Install

Copy the built `d3d8.dll` next to `Psobb.exe` in your Wine prefix and tell Wine
to use it as a native override:

```sh
cp d3d8.dll "$WINEPREFIX/drive_c/PSOBB/"
wine reg add 'HKCU\Software\Wine\DllOverrides' /v d3d8 /d native /f
# or per-launch:  WINEDLLOVERRIDES="d3d8=n" wine Psobb.exe
```

The game still renders through Wine's own `wined3d` → MoltenVK, so no DXVK or
other translation layer is required.

## Credit / license

The base wrapper is © Patrick Mours and contributors under the BSD-style license
in the upstream repo; this directory only adds `windowed.patch` and `build.sh`.
The PSOBB client itself is Sega's copyrighted binary and is **not** included here.
