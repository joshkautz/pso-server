terraform {
  # State lives in S3 in the same AWS account. Bucket is created once by
  # scripts/bootstrap.sh before the first `terraform init`.
  #
  # We pass `bucket` and `region` via -backend-config at init time so the
  # backend isn't hardcoded to one engineer's bucket name. See infra/README.md.
  backend "s3" {
    key          = "pso-server.tfstate"
    encrypt      = true
    use_lockfile = true # native S3 locking; requires Terraform 1.10+
  }
}
