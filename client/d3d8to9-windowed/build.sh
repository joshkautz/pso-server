#!/bin/bash
#
# build.sh - Build the windowed d3d8.dll for PSOBB.
#
# Produces a 32-bit Direct3D8 -> Direct3D9 shim (crosire/d3d8to9) patched to
# force PSOBB into a real, resizable window instead of its hardcoded fullscreen
# mode. See README.md for what the patch does and why.
#
# Requires the MinGW-w64 cross compiler:  brew install mingw-w64
#
# Usage:  ./build.sh            # writes ./d3d8.dll
#         ./build.sh /tmp/work  # use a custom checkout dir
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${1:-/tmp/d3d8to9-build}"
BASE_COMMIT="6cdb8a8"   # commit windowed.patch was generated against

command -v i686-w64-mingw32-g++ >/dev/null 2>&1 || {
  echo "error: i686-w64-mingw32-g++ not found. Install it with: brew install mingw-w64" >&2
  exit 1
}

echo "Fetching crosire/d3d8to9 @ $BASE_COMMIT into $WORK ..."
rm -rf "$WORK"
git clone https://github.com/crosire/d3d8to9 "$WORK"
git -C "$WORK" checkout --quiet "$BASE_COMMIT"

echo "Applying windowed.patch ..."
git -C "$WORK" apply "$HERE/windowed.patch"

# d3d8to9 runtime-loads the D3DX9 helpers, so the build only needs d3d9 (which
# MinGW ships). -static bundles libstdc++/libgcc so the dll is self-contained.
SRCS=( d3d8to9 d3d8to9_base d3d8to9_device d3d8to9_index_buffer d3d8to9_surface
       d3d8to9_swap_chain d3d8to9_texture d3d8to9_vertex_buffer d3d8to9_volume
       d3d8types interface_query )
FILES=(); for x in "${SRCS[@]}"; do FILES+=("$WORK/source/$x.cpp"); done

echo "Compiling d3d8.dll ..."
i686-w64-mingw32-g++ -shared -static -O2 -DD3D8TO9NOLOG -std=c++17 \
  -Wno-unknown-pragmas -Wno-delete-non-virtual-dtor \
  -o "$HERE/d3d8.dll" "${FILES[@]}" "$WORK/res/d3d8.def" \
  -ld3d9 -luser32 -lgdi32 -Wl,--enable-stdcall-fixup

echo "Done: $HERE/d3d8.dll"
echo "Install: copy it next to Psobb.exe and set the Wine override d3d8=native"
echo "  (WINEDLLOVERRIDES=\"d3d8=n\"  or  reg add HKCU\\Software\\Wine\\DllOverrides /v d3d8 /d native /f)"
