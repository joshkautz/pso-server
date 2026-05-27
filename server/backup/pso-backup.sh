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
readonly TMP_DIR="/var/tmp/pso-backup"

log() { logger -t "$LOG_TAG" -s "$*" 2>&1; }
die() { log "FATAL: $*"; exit 1; }

[[ -r "$ENV_FILE" ]] || die "missing env file $ENV_FILE"
# `set -a` exports every variable set by the sourced file, so they're
# visible to the docker subprocess via `-e VARNAME`. Without this,
# variables sourced from the env file remain shell-local, docker passes
# nothing, and the aws CLI inside the container falls back to anonymous
# credentials — which produce a misleading "AccessDenied" rather than
# "credentials not found".
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${PSO_BACKUP_BUCKET:?env: PSO_BACKUP_BUCKET unset}"
: "${AWS_ACCESS_KEY_ID:?env: AWS_ACCESS_KEY_ID unset}"
: "${AWS_SECRET_ACCESS_KEY:?env: AWS_SECRET_ACCESS_KEY unset}"
: "${AWS_DEFAULT_REGION:?env: AWS_DEFAULT_REGION unset}"

[[ -d "$SOURCE_DIR" ]] || die "missing source dir $SOURCE_DIR"

# We use s3api put-object with a tempfile rather than `aws s3 cp -` from
# stdin because the latter forces multipart upload for unknown-size
# streams, and `aws s3 cp` invokes CreateMultipartUpload with parameters
# (server-side encryption headers from the bucket's default-encryption
# config, etc.) that intermittently 403 with AccessDenied even when the
# IAM principal explicitly has s3:PutObject on the bucket.
#
# Single-part put-object goes up to 5 GiB per object. Our backups are
# expected to be well under 1 GiB.

mkdir -p "$TMP_DIR"
TIMESTAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
ARCHIVE_KEY="newserv-system-${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="${TMP_DIR}/${ARCHIVE_KEY}"

# Ensure the tempfile is cleaned up even if upload fails.
trap 'rm -f "$ARCHIVE_PATH"' EXIT

log "creating archive ${ARCHIVE_PATH}"
tar -C "$(dirname "$SOURCE_DIR")" \
    --exclude='system/.metadata-cache.json' \
    -czf "$ARCHIVE_PATH" \
    "$(basename "$SOURCE_DIR")"

ARCHIVE_SIZE_BYTES=$(stat -c %s "$ARCHIVE_PATH")
log "archive size: ${ARCHIVE_SIZE_BYTES} bytes — uploading to s3://${PSO_BACKUP_BUCKET}/${ARCHIVE_KEY}"

# Mount the archive into the aws-cli container so --body can point at it.
docker run --rm \
  -v "${TMP_DIR}:/work:ro" \
  -e AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY \
  -e AWS_DEFAULT_REGION \
  public.ecr.aws/aws-cli/aws-cli:latest \
  s3api put-object \
    --bucket "$PSO_BACKUP_BUCKET" \
    --key "$ARCHIVE_KEY" \
    --body "/work/${ARCHIVE_KEY}"

log "backup complete: s3://${PSO_BACKUP_BUCKET}/${ARCHIVE_KEY} (${ARCHIVE_SIZE_BYTES} bytes)"
