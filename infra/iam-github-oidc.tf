# GitHub Actions to AWS authentication via OpenID Connect.
#
# The first `terraform apply` is run locally with your personal AWS
# credentials. That creates the OIDC provider + role below; from then on,
# GitHub Actions can assume the role and run terraform itself.

# --- OIDC provider ---------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # As of mid-2023, AWS validates the GitHub OIDC token against its trust
  # store and ignores thumbprints, but the field is still required. The
  # value below is the historical GitHub Actions certificate thumbprint.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# --- Assume-role policy for the GitHub Actions role ------------------------

data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Restricts which workflows can assume the role. GitHub's sub claim
    # varies by trigger:
    #   - branch push: repo:OWNER/REPO:ref:refs/heads/BRANCH
    #   - pull_request: repo:OWNER/REPO:pull_request
    #   - job with environment: repo:OWNER/REPO:environment:ENV_NAME
    # When a job uses `environment: foo`, the env claim REPLACES the
    # branch claim — so any workflow that targets an environment needs
    # the environment claim listed here even if it also runs on main.
    # See https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#configuring-the-oidc-trust-with-the-cloud
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = var.github_oidc_branch == "*" ? [
        "repo:${var.github_repo}:*",
        ] : [
        "repo:${var.github_repo}:ref:refs/heads/${var.github_oidc_branch}",
        "repo:${var.github_repo}:pull_request",
        "repo:${var.github_repo}:environment:production",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-${var.instance_name}"
  description        = "Assumed by GitHub Actions in ${var.github_repo}"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json
}

# --- Permissions granted to the role ---------------------------------------
#
# Scoped to the specific actions Terraform actually invokes when planning
# or applying changes to the resources defined in this module, plus the
# AWS CLI calls the deploy workflow makes (lightsail:GetInstance).
#
# Lightsail has very limited ARN-level scoping (most actions accept only
# `*` as a resource), so the lightsail block uses *. IAM and S3 calls
# are scoped to the resources this role actually owns.

locals {
  # Resources this role is allowed to touch.
  tf_state_bucket_arn  = "arn:aws:s3:::pso-server-tfstate-${data.aws_caller_identity.current.account_id}"
  backup_bucket_arn    = "arn:aws:s3:::${var.instance_name}-backups-${data.aws_caller_identity.current.account_id}"
  role_arn             = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/github-actions-${var.instance_name}"
  oidc_provider_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
  backup_user_arn      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.instance_name}-backup"
  cost_reader_user_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${var.instance_name}-cost-reader"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "github_actions" {
  # Lightsail: only the actions we observed Terraform + deploy.yml call.
  # Lightsail doesn't honor resource-level ARNs for most actions, so
  # the resource has to stay as *.
  statement {
    sid = "Lightsail"
    actions = [
      "lightsail:GetRegions",
      "lightsail:GetBundles",
      "lightsail:GetBlueprints",
      "lightsail:GetInstance",
      "lightsail:GetInstances",
      "lightsail:CreateInstances",
      "lightsail:DeleteInstance",
      "lightsail:GetInstanceState",
      "lightsail:GetInstancePortStates",
      "lightsail:PutInstancePublicPorts",
      "lightsail:OpenInstancePublicPorts",
      "lightsail:CloseInstancePublicPorts",
      "lightsail:EnableAddOn",
      "lightsail:DisableAddOn",
      "lightsail:GetStaticIp",
      "lightsail:GetStaticIps",
      "lightsail:AllocateStaticIp",
      "lightsail:ReleaseStaticIp",
      "lightsail:AttachStaticIp",
      "lightsail:DetachStaticIp",
      "lightsail:GetKeyPair",
      "lightsail:GetKeyPairs",
      "lightsail:CreateKeyPair",
      "lightsail:ImportKeyPair",
      "lightsail:DeleteKeyPair",
      "lightsail:TagResource",
      "lightsail:UntagResource",
    ]
    resources = ["*"]
  }

  # Terraform remote state in S3.
  statement {
    sid = "TerraformStateBucket"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
    ]
    resources = [local.tf_state_bucket_arn]
  }
  statement {
    sid = "TerraformStateObject"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${local.tf_state_bucket_arn}/*"]
  }

  # Backup bucket: TF manages it; this role plans/applies changes to it.
  # Read access is needed during refresh; write to apply lifecycle, tags,
  # encryption, etc. Object-level access is NOT granted — the dedicated
  # backup IAM user has s3:PutObject for writes, and humans use the
  # console / their own credentials to read.
  statement {
    sid = "BackupBucketManage"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:PutBucketVersioning",
      "s3:GetBucketAcl",
      "s3:GetBucketPolicy",
      "s3:GetBucketTagging",
      "s3:PutBucketTagging",
      "s3:GetBucketPublicAccessBlock",
      "s3:PutBucketPublicAccessBlock",
      "s3:GetEncryptionConfiguration",
      "s3:PutEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:GetBucketCORS",
      "s3:GetBucketLogging",
      "s3:GetBucketWebsite",
      "s3:GetBucketRequestPayment",
      "s3:GetBucketObjectLockConfiguration",
      "s3:GetBucketOwnershipControls",
      "s3:GetReplicationConfiguration",
      "s3:GetAccelerateConfiguration",
      "s3:GetBucketNotification",
    ]
    resources = [local.backup_bucket_arn]
  }

  # IAM: scope to the role/user/OIDC-provider this module owns. Read
  # access for `terraform refresh`; write access for `terraform apply`
  # to update policies and tags on the role itself.
  statement {
    sid = "IAMOwnedRole"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListRoleTags",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRoleDescription",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
    ]
    resources = [local.role_arn]
  }
  statement {
    sid = "IAMOIDCProviderRead"
    actions = [
      "iam:GetOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviderTags",
    ]
    resources = [local.oidc_provider_arn]
  }
  statement {
    # CI maintains the per-IAM-user state for both the S3-backup user
    # and the Cost Explorer reader. Same set of read+update actions for
    # both, scoped to exactly these two user ARNs (no IAM-wide wildcard).
    # Initial CreateUser still has to happen via a local `terraform
    # apply` from josh's machine — we deliberately don't grant CI
    # iam:CreateUser to keep new-account provisioning manual.
    sid = "IAMManagedUsers"
    actions = [
      "iam:GetUser",
      "iam:ListUserTags",
      "iam:ListAccessKeys",
      "iam:CreateAccessKey",
      "iam:DeleteAccessKey",
      "iam:GetUserPolicy",
      "iam:ListUserPolicies",
      "iam:PutUserPolicy",
      "iam:DeleteUserPolicy",
      "iam:ListAttachedUserPolicies",
      "iam:TagUser",
      "iam:UntagUser",
    ]
    resources = [
      local.backup_user_arn,
      local.cost_reader_user_arn,
    ]
  }

  # sts: GetCallerIdentity is implicitly called by every aws CLI invocation.
  statement {
    sid       = "STSReadSelf"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "github-actions-${var.instance_name}"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions.json
}
