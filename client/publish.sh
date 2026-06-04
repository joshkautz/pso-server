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
  ditto -c -k --keepParent "$MAC_APP" "$WORK/PSOBB-macOS.zip"
  echo "    uploading PSOBB-macOS.zip ($(du -h "$WORK/PSOBB-macOS.zip" | cut -f1))"
  aws s3 cp "$WORK/PSOBB-macOS.zip" "s3://$BUCKET/$PREFIX/PSOBB-macOS.zip" --content-type application/zip --only-show-errors
  published=$((published + 1))
else
  echo "==> skip macOS (set MAC_APP to a PSOBB.app to publish it)"
fi

if [ -n "$WIN_CLIENT" ] && [ -d "$WIN_CLIENT" ]; then
  echo "==> zipping Windows client: $WIN_CLIENT"
  ( cd "$(dirname "$WIN_CLIENT")" && zip -r -q "$WORK/PSOBB-Windows.zip" "$(basename "$WIN_CLIENT")" )
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
