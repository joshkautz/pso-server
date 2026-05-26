# Infrastructure

Terraform for a single Lightsail instance running newserv, plus the GitHub
OIDC plumbing that lets CI assume an IAM role without long-lived credentials.

## What this creates

| Resource | Purpose |
|---|---|
| `aws_lightsail_instance` | Ubuntu 24.04 box; runs Docker; cloud-init installs deps on first boot |
| `aws_lightsail_static_ip` (+ attachment) | Stable public IP — players configure this as PSO's DNS server |
| `aws_lightsail_instance_public_ports` | UDP 53, TCP 9000-9204, TCP 22 (SSH) |
| `aws_lightsail_key_pair` | SSH key pair the deploy workflow uses |
| `aws_iam_openid_connect_provider` | GitHub OIDC, one per AWS account |
| `aws_iam_role` (+ inline policy) | Role assumed by Actions workflows |
| `add_on { type = "AutoSnapshot" }` | Daily Lightsail snapshots |

## One-time bootstrap

The S3 backend bucket has to exist before `terraform init` can use it, and
the IAM role used by Actions doesn't exist until the first apply runs.
So the first apply is local. After that, Actions takes over.

1. **Install Terraform 1.10+** (matches `.terraform-version`).
2. **Authenticate to your personal AWS account** (e.g. `aws sso login` or
   `aws configure --profile personal`). Don't use your Northbuilt account.
3. **Generate the deploy SSH key**:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/pso-server-deploy -C 'pso-server deploy' -N ''
   ```
4. **Run the bootstrap script** (creates the TF state bucket if missing):
   ```bash
   ../scripts/bootstrap.sh
   ```
5. **Create `terraform.tfvars`** from the example and paste in your public key:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # then edit terraform.tfvars
   ```
6. **Initialize Terraform** with the backend config the bootstrap script
   printed:
   ```bash
   terraform init \
     -backend-config="bucket=<YOUR-STATE-BUCKET>" \
     -backend-config="region=us-east-1"
   ```
7. **Apply**:
   ```bash
   terraform plan
   terraform apply
   ```
8. **Push the role ARN and private key into GitHub**:
   ```bash
   gh secret set SSH_PRIVATE_KEY < ~/.ssh/pso-server-deploy
   gh variable set AWS_ROLE_ARN --body "$(terraform output -raw github_actions_role_arn)"
   gh variable set AWS_REGION --body us-east-1
   gh variable set LIGHTSAIL_INSTANCE_NAME --body "$(terraform output -raw instance_name)"
   gh variable set TF_STATE_BUCKET --body "<YOUR-STATE-BUCKET>"
   ```

From this point onward, `terraform apply` runs in GitHub Actions on every
push to `main` that touches `infra/`. PRs get a `terraform plan` comment.

## Why partial backend config?

`backend.tf` deliberately omits the bucket name. Different engineers (or
forks) can use different bucket names without editing committed files —
they just pass `-backend-config="bucket=..."` at init time. The bucket
name also doesn't end up in the repo, which is a mild defense against
typosquatting / state poisoning.

## Tightening the IAM policy

The role currently has `lightsail:*` and broad S3 access. To narrow it:

- Scope S3 actions to `arn:aws:s3:::<your-state-bucket>` and
  `arn:aws:s3:::<your-state-bucket>/*`
- Replace `lightsail:*` with the specific actions Terraform makes during
  `apply` (`lightsail:GetInstance`, `lightsail:CreateInstances`,
  `lightsail:PutInstancePublicPorts`, etc.). Run `terraform apply` with
  CloudTrail on and copy the action list.

Not worth it for a hobby setup; documented here for future you.
