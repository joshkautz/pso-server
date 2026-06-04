#!/usr/bin/env bash
# ============================================================
#  Remember my PSO Blue Burst login (macOS)
#
#  Pre-fills the UserID + password on the client's login screen
#  so you don't retype them every launch. Writes three values
#  under HKCU\Software\SonicTeam\PSOBB inside PSOBB.app's bundled
#  Wine registry (the same keys the client itself uses).
#
#  Run it by double-clicking, or: bash remember-login-macos.command
#  Re-run any time to change the saved login.
# ============================================================
set -euo pipefail

echo
echo "  PSO Blue Burst - remember my login"
echo "  -----------------------------------"

# 1. Locate PSOBB.app (common spots, then ask).
APP=""
for c in "$HOME/Applications/Sikarugir/PSOBB.app" "/Applications/PSOBB.app" \
         "$HOME/Applications/PSOBB.app" "$HOME/Desktop/PSOBB.app"; do
  [ -d "$c" ] && { APP="$c"; break; }
done
if [ -z "$APP" ]; then
  read -r -p "  Couldn't find PSOBB.app — drag it onto this window and press Enter: " APP
  APP="${APP%\"}"; APP="${APP#\"}"; APP="${APP%/}"; APP="${APP/#\~/$HOME}"
fi
REG="$APP/Contents/SharedSupport/prefix/user.reg"
[ -f "$REG" ] || { echo "  ERROR: not a PSOBB.app I recognize (no Wine registry at $REG)"; exit 1; }

# 2. The game must be closed — Wine rewrites the registry on exit.
if pgrep -ifq "Psobb.exe" 2>/dev/null || pgrep -if "Psobb.exe" >/dev/null 2>&1; then
  echo "  ERROR: PSOBB is running. Close the game window first, then re-run."; exit 1
fi

# 3. Prompt for credentials.
read -r -p "  UserID: " USERID
[ -n "$USERID" ] || { echo "  No UserID entered - aborting."; exit 1; }
read -r -s -p "  Password: " PASSWD; echo
[ -n "$PASSWD" ] || { echo "  No password entered - aborting."; exit 1; }

# 4. Back up, then set ACCOUNT / PASSWORD / ACCOUNT_CHECK in the registry,
#    replacing the values in place (or appending them if a prefix lacks them).
cp "$REG" "$REG.bak-$(date +%Y%m%d%H%M%S)"
awk -v U="$USERID" -v P="$PASSWD" '
  function flush(){ if(inblk){
      if(!a) print "\"ACCOUNT\"=\"" U "\""
      if(!p) print "\"PASSWORD\"=\"" P "\""
      if(!c) print "\"ACCOUNT_CHECK\"=dword:00000001" } }
  /^[ \t]*$/        { if(inblk){ flush(); inblk=0 } print; next }
  /^\[/             { inblk=($0 ~ /SonicTeam.*PSOBB/)?1:0; a=0;p=0;c=0; print; next }
  inblk && /^"ACCOUNT"=/       { print "\"ACCOUNT\"=\"" U "\"";        a=1; next }
  inblk && /^"PASSWORD"=/      { print "\"PASSWORD\"=\"" P "\"";       p=1; next }
  inblk && /^"ACCOUNT_CHECK"=/ { print "\"ACCOUNT_CHECK\"=dword:00000001"; c=1; next }
                    { print }
  END               { flush() }
' "$REG" > "$REG.new" && mv "$REG.new" "$REG"

echo "  Done. Launch PSOBB — your UserID and password will be pre-filled."
echo
