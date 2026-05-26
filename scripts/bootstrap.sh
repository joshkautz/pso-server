#!/usr/bin/env bash
#
# One-time bootstrap for the pso-server AWS infrastructure.
#
# What this does:
#   1. Verifies you are authenticated against your *personal* AWS account
#      (not a Northbuilt account)
#   2. Creates the S3 bucket Terraform will use for remote state
#      (idempotent — safe to re-run)
#   3. Prints the -backend-config flags to pass to `terraform init`
#
# Pre-reqs:
#   - aws CLI configured for your personal AWS account
#   - jq installed
#
# Run from anywhere; bucket name is deterministic from your AWS account ID.

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
PROJECT="pso-server"

err()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; }
note() { printf '\033[36m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[32mok:\033[0m %s\n' "$*"; }

# --- Verify AWS context ----------------------------------------------------

if ! command -v aws >/dev/null; then
  err "aws CLI not found"
  exit 1
fi

if ! command -v jq >/dev/null; then
  err "jq not found (brew install jq)"
  exit 1
fi

ident_json=$(aws sts get-caller-identity --output json) || {
  err "aws sts get-caller-identity failed; check your credentials"
  exit 1
}

ACCOUNT_ID=$(jq -r '.Account' <<<"$ident_json")
ARN=$(jq -r '.Arn' <<<"$ident_json")

note "AWS account: $ACCOUNT_ID"
note "Identity:    $ARN"

# Sanity check: warn if this looks like a work account. Adjust as needed.
if [[ "$ARN" == *"northbuilt"* ]] || [[ "$ARN" == *"@northbuilt"* ]]; then
  err "this identity looks like a Northbuilt work account — aborting"
  err "switch credentials (e.g. aws sso login --profile personal) and retry"
  exit 1
fi

read -r -p "Use this account for the personal pso-server infra? [y/N] " ans
case "$ans" in
  [yY]|[yY][eE][sS]) ;;
  *) err "aborted by user"; exit 1 ;;
esac

# --- Create state bucket ---------------------------------------------------

BUCKET="${PROJECT}-tfstate-${ACCOUNT_ID}"

note "Ensuring S3 bucket s3://${BUCKET} exists in ${REGION}"

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  ok "bucket already exists"
else
  if [[ "$REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
  else
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
      --create-bucket-configuration "LocationConstraint=$REGION"
  fi
  ok "created bucket"
fi

# Enable versioning so we can recover from accidental state corruption.
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
ok "versioning enabled"

# Block all public access.
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
ok "public access blocked"

# Server-side encryption (SSE-S3 is fine for our scope; SSE-KMS overkill).
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'
ok "encryption enabled (SSE-S3)"

# --- Next steps ------------------------------------------------------------

cat <<EOF

$(note "Bootstrap complete.")

Next:
  cd infra
  cp terraform.tfvars.example terraform.tfvars   # then edit it
  terraform init \\
    -backend-config="bucket=${BUCKET}" \\
    -backend-config="region=${REGION}"
  terraform plan
  terraform apply

After apply succeeds:
  terraform output github_actions_role_arn   # set this as gh variable AWS_ROLE_ARN
  gh secret set SSH_PRIVATE_KEY < ~/.ssh/pso-server-deploy
  gh secret set SSH_PUBLIC_KEY < ~/.ssh/pso-server-deploy.pub
  gh variable set AWS_ROLE_ARN --body "\$(terraform output -raw github_actions_role_arn)"
  gh variable set AWS_REGION --body "${REGION}"
  gh variable set TF_STATE_BUCKET --body "${BUCKET}"
  gh variable set LIGHTSAIL_INSTANCE_NAME --body "\$(terraform output -raw instance_name)"

EOF
