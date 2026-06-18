# ----------------------------------------------------------------------------
# Cost-reader IAM user — read-only access to AWS Cost Explorer.
#
# Why this exists:
#   The dashboard surfaces hosting cost in the Live section. The container
#   makes two API calls on a 6h cache (ce:GetCostAndUsage, ce:GetCostForecast)
#   and renders them as a small time-series chart + MTD/forecast figures.
#
# Why dedicated user instead of reusing an existing identity:
#   - The github-actions OIDC role is for CI, not runtime workloads.
#   - The backup user is write-only to one S3 bucket; very different scope.
#   - Cost Explorer queries are billable ($0.01/request), so we want a
#     single, replaceable credential we can audit and rotate.
#
# Permissions are deliberately narrow: just the two CE read calls. No
# DescribeReportDefinitions, no UpdateBudget, no service-level usage data.
# ----------------------------------------------------------------------------

resource "aws_iam_user" "cost_reader" {
  name = "${var.instance_name}-cost-reader"

  tags = {
    Purpose = "dashboard-cost-card"
  }
}

data "aws_iam_policy_document" "cost_reader" {
  statement {
    sid = "ReadCostExplorer"
    actions = [
      "ce:GetCostAndUsage",
      "ce:GetCostForecast",
    ]
    # Cost Explorer doesn't support resource-level permissions; "*" is
    # the only valid Resource value for ce:* actions (see AWS docs).
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "cost_reader" {
  name   = "${var.instance_name}-cost-reader"
  user   = aws_iam_user.cost_reader.name
  policy = data.aws_iam_policy_document.cost_reader.json
}

resource "aws_iam_access_key" "cost_reader" {
  user = aws_iam_user.cost_reader.name
}
