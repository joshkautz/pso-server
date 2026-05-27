# Nightly backup of newserv state (accounts, characters, BB system files)
# to S3.
#
# Lightsail instances don't support EC2 IAM instance profiles, so we
# provision a dedicated IAM user with write-only access to the backup
# bucket. The user's access keys are output (sensitive) by Terraform; the
# deploy workflow reads them via terraform output and writes them to
# /etc/pso-backup.env on the instance for the backup script to source.

# --- Bucket --------------------------------------------------------------

resource "aws_s3_bucket" "backups" {
  bucket = "${var.instance_name}-backups-${data.aws_caller_identity.current.account_id}"

  # Tags inherited from provider default_tags.
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Auto-expire backups after N days. Keeps storage cost negligible and
# acts as a basic retention policy.
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# --- IAM user with write-only access to the bucket -----------------------

resource "aws_iam_user" "backup" {
  name = "${var.instance_name}-backup"
}

data "aws_iam_policy_document" "backup_user" {
  # Write-only — the backup script never reads existing backups (humans
  # do that via the console or local AWS CLI with their own credentials).
  # The IAM action s3:PutObject is supposed to cover all multipart
  # operations per AWS docs, but in practice CreateMultipartUpload is
  # checked independently when --expected-size is supplied to the CLI.
  # Grant the multipart trio explicitly.
  statement {
    sid = "WriteObjects"
    actions = [
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = ["${aws_s3_bucket.backups.arn}/*"]
  }
  statement {
    sid       = "ListInProgressMultipartUploads"
    actions   = ["s3:ListBucketMultipartUploads"]
    resources = [aws_s3_bucket.backups.arn]
  }
}

resource "aws_iam_user_policy" "backup" {
  name   = "${var.instance_name}-backup"
  user   = aws_iam_user.backup.name
  policy = data.aws_iam_policy_document.backup_user.json
}

resource "aws_iam_access_key" "backup" {
  user = aws_iam_user.backup.name
}
