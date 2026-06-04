#!/usr/bin/env bash
# ============================================================
#  Remember my PSO Blue Burst UserID (macOS)
#
#  Saves your UserID into PSOBB.app's bundled Wine registry so the
#  login screen pre-fills it every launch.
#
#  Note on the password: PSO stores it separately and *encrypted*
#  (it's set by the game's own launcher, not a plain registry value),
#  so a script can't bake it in. Type it once each session, or enable
#  save-password in the launcher. See README.md.
#
#  Run by double-clicking, or: bash remember-login-macos.command
# ============================================================
set -euo pipefail

echo
echo "  PSO Blue Burst - remember my UserID"
echo "  ------------------------------------"

# 1. Locate PSOBB.app (common spots, then ask).
APP=""
for c in "$HOME/Applications/Sikarugir/PSOBB.app" "/Applications/PSOBB.app" \
         "$HOME/Applications/PSOBB.app" "$HOME/Desktop/PSOBB.app"; do
  [ -d "$c" ] && { APP="$c"; break; }
done
if [ -z "$APP" ]; then
  read -r -p "  Couldn't find PSOBB.app - drag it onto this window and press Enter: " APP
  APP="${APP%\"}"; APP="${APP#\"}"; APP="${APP%/}"; APP="${APP/#\~/$HOME}"
fi
REG="$APP/Contents/SharedSupport/prefix/user.reg"
[ -f "$REG" ] || { echo "  ERROR: not a PSOBB.app I recognize (no Wine registry at $REG)"; exit 1; }

# 2. The game must be closed - Wine rewrites the registry on exit.
if pgrep -if "Psobb.exe" >/dev/null 2>&1; then
  echo "  ERROR: PSOBB is running. Close the game window first, then re-run."; exit 1
fi

# 3. Prompt for the UserID.
read -r -p "  UserID: " USERID
[ -n "$USERID" ] || { echo "  No UserID entered - aborting."; exit 1; }

# 4. Back up, then set ACCOUNT (UserID) + ACCOUNT_CHECK (remember flag) in the
#    registry, replacing them in place or appending if a prefix lacks them.
#    PASSWORD is intentionally left untouched (the client encrypts it itself).
cp "$REG" "$REG.bak-$(date +%Y%m%d%H%M%S)"
awk -v U="$USERID" '
  function flush(){ if(inblk){
      if(!a) print "\"ACCOUNT\"=\"" U "\""
      if(!c) print "\"ACCOUNT_CHECK\"=dword:00000001" } }
  /^[ \t]*$/        { if(inblk){ flush(); inblk=0 } print; next }
  /^\[/             { inblk=($0 ~ /SonicTeam.*PSOBB/)?1:0; a=0;c=0; print; next }
  inblk && /^"ACCOUNT"=/       { print "\"ACCOUNT\"=\"" U "\"";            a=1; next }
  inblk && /^"ACCOUNT_CHECK"=/ { print "\"ACCOUNT_CHECK\"=dword:00000001"; c=1; next }
                    { print }
  END               { flush() }
' "$REG" > "$REG.new" && mv "$REG.new" "$REG"

echo "  Done. Your UserID (\"$USERID\") will be pre-filled at the login screen."
echo "  Type your password once each session (or enable save-password in the launcher)."
echo
