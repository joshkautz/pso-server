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

    # Restricts which workflows can assume the role. By default we trust
    # only the main branch of the configured repo. Use sub claims like
    #   repo:OWNER/REPO:ref:refs/heads/main
    #   repo:OWNER/REPO:environment:production
    #   repo:OWNER/REPO:pull_request
    # See https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#configuring-the-oidc-trust-with-the-cloud
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = var.github_oidc_branch == "*" ? [
        "repo:${var.github_repo}:*",
        ] : [
        "repo:${var.github_repo}:ref:refs/heads/${var.github_oidc_branch}",
        "repo:${var.github_repo}:pull_request",
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

# Scope is intentionally broad-ish (lightsail:* + the TF state bucket) so
# the role can manage the full infra lifecycle. For a more locked-down
# setup, split into separate read-only and apply roles and gate apply
# behind GitHub Environments + required reviewers.
data "aws_iam_policy_document" "github_actions" {
  # Full Lightsail control for this account (Lightsail does not support
  # fine-grained resource ARNs for most actions, so * is conventional).
  statement {
    sid       = "LightsailFullAccess"
    actions   = ["lightsail:*"]
    resources = ["*"]
  }

  # Terraform state in S3. Bucket name is supplied at `terraform init` via
  # -backend-config, so we don't have it as a TF-managed resource. The
  # role needs to read/write the state object and the lockfile alongside it.
  statement {
    sid = "TerraformState"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    # Intentionally broad — the bootstrap bucket name is not known to TF.
    # Tighten this by replacing with the actual bucket ARN once stable.
    resources = ["*"]
  }

  # IAM read access so the role can refresh itself on apply.
  statement {
    sid = "IAMReadSelf"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:GetOpenIDConnectProvider",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "github-actions-${var.instance_name}"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions.json
}
