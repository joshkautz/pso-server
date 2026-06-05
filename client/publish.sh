#!/usr/bin/env bash
#
# publish.sh — build the Blue Burst client zips and upload them to the public
# downloads bucket the dashboard links to.
#
# Run locally with AWS access (the binaries live on your machine, not in git):
#
#   AWS_PROFILE=pso-server \
#     MAC_APP="$HOME/Applications/Sikarugir/PSOBB.app" \
#     WIN_CLIENT="/path/to/TethVer12513_English" \
#     ./publish.sh
#
# Either source may be omitted — only the one(s) present get (re)published.
# The bucket is managed here, not in Terraform, on purpose (see README.md).
set -euo pipefail

BUCKET="${BUCKET:-pso-server-downloads-315902154426}"
PREFIX="downloads"
MAC_APP="${MAC_APP:-$HOME/Applications/Sikarugir/PSOBB.app}"
WIN_CLIENT="${WIN_CLIENT:-}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
RL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/remember-login"  # login helpers bundled into each zip

command -v aws >/dev/null || { echo "error: aws CLI not found" >&2; exit 1; }

echo "==> ensuring bucket $BUCKET (public-read on $PREFIX/*)"
aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null || aws s3api create-bucket --bucket "$BUCKET" >/dev/null
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=false,RestrictPublicBuckets=false" >/dev/null
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' >/dev/null
aws s3api put-bucket-policy --bucket "$BUCKET" --policy \
  "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"PublicReadDownloads\",\"Effect\":\"Allow\",\"Principal\":\"*\",\"Action\":\"s3:GetObject\",\"Resource\":\"arn:aws:s3:::$BUCKET/$PREFIX/*\"}]}" >/dev/null

published=0

if [ -d "$MAC_APP" ]; then
  echo "==> zipping macOS app: $MAC_APP"
  # Drop stale Wine device maps (the dosdevices/X:: symlinks point at THIS machine's
  # /dev/rdiskN; Wine regenerates them per-machine). Otherwise they ship the builder's
  # disk layout and make `xattr` choke on them for players.
  find "$MAC_APP/Contents/SharedSupport/prefix/dosdevices" -maxdepth 1 -name '*::' -delete 2>/dev/null || true
  ditto -c -k --keepParent "$MAC_APP" "$WORK/PSOBB-macOS.zip"

  # Everything below edits the ARCHIVE only — the source .app is never mutated.
  _appbase="$(basename "$MAC_APP")"
  _client="$_appbase/Contents/SharedSupport/prefix/drive_c/PSOBB"

  # (a) Drop retail-launcher cruft + build leftovers players never use: online.exe is
  #     the old launcher we bypass (the Wine crash point), option.exe its graphics
  #     config tool, Readme.txt points players at online.exe + a dead server, and
  #     d3d8.dll.orig/d3d8.log are leftovers from installing our shim. ditto also
  #     emits AppleDouble (._*) metadata sidecars, so drop those alongside each file.
  for _f in online.exe option.exe Readme.txt d3d8.dll.orig d3d8.log; do
    zip -dq "$WORK/PSOBB-macOS.zip" "$_client/$_f" "$_client/._$_f" >/dev/null 2>&1 || true
  done

  # (b) Ship a clean login. The build machine's saved UserID/password live in the
  #     bundled prefix registry; scrub them so a friend never receives our creds.
  #     Extract user.reg, blank ACCOUNT/ACCOUNT_CHECK + empty PASSWORD (dropping any
  #     wrapped or orphaned hex tail), then swap it back into the archive.
  _ureg="$_appbase/Contents/SharedSupport/prefix/user.reg"
  _st="$WORK/regscrub"; rm -rf "$_st"; mkdir -p "$_st"
  ( cd "$_st" && unzip -oq "$WORK/PSOBB-macOS.zip" "$_ureg" )
  python3 - "$_st/$_ureg" <<'PYSCRUB'
import sys
path = sys.argv[1]
with open(path, 'r', encoding='utf-8', errors='surrogateescape', newline='') as f:
    text = f.read()
nl = '\r\n' if '\r\n' in text else '\n'
lines = text.split(nl)
def is_cont(s):  # wrapped REG_BINARY continuation/orphan line: indented hex, not a key/section
    return s[:1] in (' ', '\t') and s.strip() != '' and not s.lstrip().startswith('"') and not s.lstrip().startswith('[')
out, inb, i, n = [], False, 0, len(lines)
while i < n:
    ln = lines[i]
    if ln.startswith('['):
        inb = ('SonicTeam' in ln and 'PSOBB' in ln); out.append(ln); i += 1; continue
    if inb and ln.startswith('"ACCOUNT"='):      out.append('"ACCOUNT"=""'); i += 1; continue
    if inb and ln.startswith('"ACCOUNT_CHECK"='): out.append('"ACCOUNT_CHECK"=dword:00000000'); i += 1; continue
    if inb and ln.startswith('"PASSWORD"='):
        out.append('"PASSWORD"=""'); i += 1
        while i < n and is_cont(lines[i]): i += 1   # drop the wrapped tail + any stale orphans
        continue
    out.append(ln); i += 1
with open(path, 'w', encoding='utf-8', errors='surrogateescape', newline='') as f:
    f.write(nl.join(out))
PYSCRUB
  zip -dq "$WORK/PSOBB-macOS.zip" "$_ureg" "$_appbase/Contents/SharedSupport/prefix/._user.reg" >/dev/null 2>&1 || true
  ( cd "$_st" && zip -Xq "$WORK/PSOBB-macOS.zip" "$_ureg" )

  # Bundle the login helper at the zip root, next to PSOBB.app.
  zip -gjq "$WORK/PSOBB-macOS.zip" "$RL/setup.command"
  echo "    uploading PSOBB-macOS.zip ($(du -h "$WORK/PSOBB-macOS.zip" | cut -f1))"
  aws s3 cp "$WORK/PSOBB-macOS.zip" "s3://$BUCKET/$PREFIX/PSOBB-macOS.zip" --content-type application/zip --only-show-errors
  published=$((published + 1))
else
  echo "==> skip macOS (set MAC_APP to a PSOBB.app to publish it)"
fi

if [ -n "$WIN_CLIENT" ] && [ -d "$WIN_CLIENT" ]; then
  echo "==> staging + zipping Windows client as PSOBB/: $WIN_CLIENT"
  # Stage under a clean folder name "PSOBB" (the raw Tethealla folder name is ugly),
  # then zip it, dropping what Windows players don't need:
  #   *.bak                  the pristine pre-repoint Psobb.exe (still 127.0.0.1)
  #   online.exe/option.exe  the retail launcher + its config tool (we run Psobb.exe)
  #   Readme.txt             points players at online.exe + a dead server
  #   d3d8.dll               a D3D8->D3D9 shim only needed under Wine on macOS; native
  #                          Windows has its own d3d8, and the shim drags in a VC++
  #                          runtime dependency a player may not have installed.
  #   d3d8.dll.orig/d3d8.log build leftovers
  rm -rf "$WORK/PSOBB"; ditto "$WIN_CLIENT" "$WORK/PSOBB"
  ( cd "$WORK" && zip -r -q "$WORK/PSOBB-Windows.zip" "PSOBB" \
      -x "*.bak" "PSOBB/online.exe" "PSOBB/option.exe" "PSOBB/Readme.txt" \
         "PSOBB/d3d8.dll" "PSOBB/d3d8.dll.orig" "PSOBB/d3d8.log" )
  # Bundle the login helper + instructions at the zip root, next to the client folder.
  zip -gjq "$WORK/PSOBB-Windows.zip" "$RL/setup.bat"
  echo "    uploading PSOBB-Windows.zip ($(du -h "$WORK/PSOBB-Windows.zip" | cut -f1))"
  aws s3 cp "$WORK/PSOBB-Windows.zip" "s3://$BUCKET/$PREFIX/PSOBB-Windows.zip" --content-type application/zip --only-show-errors
  published=$((published + 1))
else
  echo "==> skip Windows (set WIN_CLIENT to a repointed TethVer12513 folder to publish it)"
fi

[ "$published" -gt 0 ] || { echo "nothing published — set MAC_APP and/or WIN_CLIENT" >&2; exit 1; }

echo
echo "done. Public downloads:"
echo "  https://$BUCKET.s3.amazonaws.com/$PREFIX/PSOBB-macOS.zip"
echo "  https://$BUCKET.s3.amazonaws.com/$PREFIX/PSOBB-Windows.zip"
