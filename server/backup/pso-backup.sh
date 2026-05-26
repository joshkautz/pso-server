#!/usr/bin/env bash
#
# Nightly backup of newserv state to S3. Installed and scheduled by the
# deploy workflow; do not run by hand on the instance unless debugging.
#
# Environment (sourced from /etc/pso-backup.env):
#   PSO_BACKUP_BUCKET            target S3 bucket
#   AWS_ACCESS_KEY_ID            IAM user with s3:PutObject on the bucket
#   AWS_SECRET_ACCESS_KEY        ^
#   AWS_DEFAULT_REGION           bucket region

set -euo pipefail

readonly SOURCE_DIR="/home/ubuntu/pso-server/system"
readonly ENV_FILE="/etc/pso-backup.env"
readonly LOG_TAG="pso-backup"

log() { logger -t "$LOG_TAG" -s "$*" 2>&1; }
die() { log "FATAL: $*"; exit 1; }

[[ -r "$ENV_FILE" ]] || die "missing env file $ENV_FILE"
# shellcheck disable=SC1090
source "$ENV_FILE"

: "${PSO_BACKUP_BUCKET:?env: PSO_BACKUP_BUCKET unset}"
: "${AWS_ACCESS_KEY_ID:?env: AWS_ACCESS_KEY_ID unset}"
: "${AWS_SECRET_ACCESS_KEY:?env: AWS_SECRET_ACCESS_KEY unset}"
: "${AWS_DEFAULT_REGION:?env: AWS_DEFAULT_REGION unset}"

[[ -d "$SOURCE_DIR" ]] || die "missing source dir $SOURCE_DIR"

# tar everything mutable in system/. We don't try to be clever about
# excluding image-provided dirs (quests/, tables/, etc.); they're small,
# and not excluding them means we can restore to a clean instance with
# one s3 cp + tar xf instead of needing to also re-seed from the image.
TIMESTAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
ARCHIVE_KEY="newserv-system-${TIMESTAMP}.tar.gz"

log "starting backup → s3://${PSO_BACKUP_BUCKET}/${ARCHIVE_KEY}"

tar -C "$(dirname "$SOURCE_DIR")" \
    --exclude='system/.metadata-cache.json' \
    -czf - "$(basename "$SOURCE_DIR")" \
  | docker run --rm -i \
      -e AWS_ACCESS_KEY_ID \
      -e AWS_SECRET_ACCESS_KEY \
      -e AWS_DEFAULT_REGION \
      public.ecr.aws/aws-cli/aws-cli:latest \
      s3 cp - "s3://${PSO_BACKUP_BUCKET}/${ARCHIVE_KEY}" \
        --expected-size 524288000

log "backup complete: s3://${PSO_BACKUP_BUCKET}/${ARCHIVE_KEY}"
