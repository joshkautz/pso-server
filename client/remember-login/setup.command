#!/usr/bin/env bash
# ============================================================
#  Remember my PSO Blue Burst login (macOS) - single file, no installs.
#
#  Asks for your BB UserID + password and saves BOTH into the client so the
#  login screen pre-fills them every launch. The password is written exactly
#  the way the game stores it: a 48-byte encrypted blob (PSOBB's Blowfish,
#  keyed by your UserID). Uses only what macOS already ships (bash + Perl).
#
#  Run by double-clicking, or: bash remember-login.command
# ============================================================
set -euo pipefail

echo
echo "  PSO Blue Burst - remember my login"
echo "  -----------------------------------"

# 1. Locate PSOBB.app. Prefer the copy sitting right next to this script (i.e. the
#    folder you unzipped — wherever that is), then /Applications (where the guide
#    has you move it), then a few common spots. Falls back to asking you to drag
#    it in.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
APP=""
for c in "$SCRIPT_DIR/PSOBB.app" \
         "/Applications/PSOBB.app" \
         "$HOME/Downloads/PSOBB-macOS/PSOBB.app" \
         "$HOME/Applications/Sikarugir/PSOBB.app" \
         "$HOME/Applications/PSOBB.app" \
         "$HOME/Desktop/PSOBB.app"; do
  [ -d "$c" ] && { APP="$c"; break; }
done
if [ -z "$APP" ]; then
  read -r -p "  Drag PSOBB.app onto this window and press Enter: " APP
  APP="${APP%\"}"; APP="${APP#\"}"; APP="${APP%/}"; APP="${APP/#\~/$HOME}"
fi
REG="$APP/Contents/SharedSupport/prefix/user.reg"
[ -f "$REG" ] || { echo "  Not a PSOBB.app I recognize (no Wine registry at $REG)"; exit 1; }
if pgrep -if "Psobb.exe" >/dev/null 2>&1; then
  echo "  PSOBB is running. Close the game window first, then re-run."; exit 1
fi

# 2. Prompt.
read -r -p "  UserID: " RL_UID
read -r -s -p "  Password: " RL_PW; echo
[ -n "$RL_UID" ] && [ -n "$RL_PW" ] || { echo "  UserID and password are both required."; exit 1; }

# 3. Compute the encrypted PASSWORD blob (PSOBB Blowfish, keyed by the UserID).
HEX=$(RL_UID="$RL_UID" RL_PW="$RL_PW" perl <<'PERL'
use strict; use warnings; use MIME::Base64;
my $b64 = "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";
my $raw = decode_base64($b64);
my $uid = $ENV{RL_UID}; my $pw = $ENV{RL_PW};
our @P = unpack('V18', substr($raw, 0, 72));
our @S; for my $i (0..3) { $S[$i] = [ unpack('V256', substr($raw, 72 + $i*1024, 1024)) ]; }
for my $i (0..17) {
  my $T = $P[$i];
  my $plo = (($T & 0xFF) << 8) | (($T >> 8) & 0xFF);
  my $phi = ((($T >> 16) & 0xFFFF) ^ $plo) & 0xFFFF;
  $P[$i] = (($phi << 16) | $plo) & 0xFFFFFFFF;
}
my $keystr = $uid; $keystr .= "\0" x (48 - length($keystr)); $keystr = substr($keystr, 0, 48);
my @key = unpack('C48', $keystr); my $L = 48;
for my $i (0..17) {
  my $k = ($key[($i*4+3)%$L]) | ($key[($i*4+2)%$L] << 8) | ($key[($i*4+1)%$L] << 16) | ($key[($i*4+0)%$L] << 24);
  $P[$i] = ($P[$i] ^ ($k & 0xFFFFFFFF)) & 0xFFFFFFFF;
}
sub F {
  my $x = $_[0] & 0xFFFFFFFF;
  my $e = $S[0][($x >> 24) & 0xFF];
  $e = ($e + $S[1][($x >> 16) & 0xFF]) & 0xFFFFFFFF;
  $e ^= $S[2][($x >> 8) & 0xFF];
  $e = ($e + $S[3][$x & 0xFF]) & 0xFFFFFFFF;
  return $e;
}
sub ib {
  my ($l, $r) = @_;
  for (my $i = 0; $i < 16; $i += 2) {
    $l ^= $P[$i];   $r = ($r ^ F($l)) & 0xFFFFFFFF;
    $r ^= $P[$i+1]; $l = ($l ^ F($r)) & 0xFFFFFFFF;
  }
  $l ^= $P[16]; $r ^= $P[17];
  return ($r & 0xFFFFFFFF, $l & 0xFFFFFFFF);
}
my ($v1, $v2) = (0, 0);
for (my $i = 0; $i < 18; $i += 2) { ($v1, $v2) = ib($v1, $v2); $P[$i] = $v1; $P[$i+1] = $v2; }
for my $b (0..3) { for (my $j = 0; $j < 256; $j += 2) { ($v1, $v2) = ib($v1, $v2); $S[$b][$j] = $v1; $S[$b][$j+1] = $v2; } }
sub eb {
  my ($l, $r) = @_;
  for my $i (0..3) { $l ^= $P[$i]; $r = ($r ^ F($l)) & 0xFFFFFFFF; ($l, $r) = ($r, $l); }
  ($l, $r) = ($r, $l);
  $r ^= $P[4]; $l ^= $P[5];
  return ($l & 0xFFFFFFFF, $r & 0xFFFFFFFF);
}
my $ptstr = $pw; $ptstr .= "\0" x (48 - length($ptstr)); $ptstr = substr($ptstr, 0, 48);
my @pt = unpack('V12', $ptstr); my @out;
for (my $i = 0; $i < 12; $i += 2) { my ($l, $r) = eb($pt[$i], $pt[$i+1]); push @out, $l, $r; }
print join(",", map { sprintf("%02x", $_) } unpack('C*', pack('V12', @out)));
PERL
)
[ -n "$HEX" ] || { echo "  Internal error computing the password value."; exit 1; }

# 4. Back up + write ACCOUNT / ACCOUNT_CHECK / PASSWORD into the Wine registry.
cp "$REG" "$REG.bak-$(date +%Y%m%d%H%M%S)"
awk -v U="$RL_UID" -v H="$HEX" '
  function flush(){ if(inblk){
      if(!a) print "\"ACCOUNT\"=\"" U "\""
      if(!c) print "\"ACCOUNT_CHECK\"=dword:00000001"
      if(!p) print "\"PASSWORD\"=hex:" H } }
  # After rewriting PASSWORD, swallow any wrapped or orphaned hex continuation
  # lines (indented hex, no key) so no dangling tail survives.
  inpw && /^[ \t]+[0-9a-fA-F]/ { next }
  inpw                         { inpw=0 }
  /^[ \t]*$/        { if(inblk){ flush(); inblk=0 } print; next }
  /^\[/             { inblk=($0 ~ /SonicTeam.*PSOBB/)?1:0; a=0;c=0;p=0; print; next }
  inblk && /^"ACCOUNT"=/       { print "\"ACCOUNT\"=\"" U "\"";            a=1; next }
  inblk && /^"ACCOUNT_CHECK"=/ { print "\"ACCOUNT_CHECK\"=dword:00000001"; c=1; next }
  inblk && /^"PASSWORD"=/      { print "\"PASSWORD\"=hex:" H;       p=1; inpw=1; next }
                    { print }
  END               { flush() }
' "$REG" > "$REG.new" && mv "$REG.new" "$REG"

echo "  Done - launch PSOBB; your UserID and password are pre-filled."
echo
