variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for the Lightsail instance."
}

variable "availability_zone" {
  type        = string
  default     = "us-east-1a"
  description = "AWS AZ for the Lightsail instance. Must be within aws_region."
}

variable "instance_name" {
  type        = string
  default     = "pso-server"
  description = "Lightsail instance name. Also used as a name prefix for related resources."
}

variable "instance_bundle_id" {
  type        = string
  default     = "small_3_0"
  description = <<-EOT
    Lightsail bundle (instance size). Common Linux options:
      nano_3_0  = $5/mo,  512MB RAM, 2 vCPU, 20GB SSD
      micro_3_0 = $7/mo,  1GB   RAM, 2 vCPU, 40GB SSD
      small_3_0 = $12/mo, 2GB   RAM, 2 vCPU, 60GB SSD  <-- recommended
      medium_3_0= $24/mo, 4GB   RAM, 2 vCPU, 80GB SSD
    Run `aws lightsail get-bundles` for the full list.
  EOT
}

variable "blueprint_id" {
  type        = string
  default     = "ubuntu_24_04"
  description = "Lightsail OS blueprint. Run `aws lightsail get-blueprints` to list options."
}

variable "ssh_public_key" {
  type        = string
  description = <<-EOT
    OpenSSH-formatted public key authorized for SSH on the instance.
    Generate locally with:
      ssh-keygen -t ed25519 -f ~/.ssh/pso-server-deploy -C 'pso-server deploy' -N ''
    Then set this variable to the contents of ~/.ssh/pso-server-deploy.pub
    (typically via terraform.tfvars; see terraform.tfvars.example).
    The matching private key goes into the SSH_PRIVATE_KEY GitHub Secret.
  EOT
}

variable "allowed_admin_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR allowed to SSH (TCP 22). Lock to your home IP for safety, e.g. 203.0.113.42/32."
}

variable "allowed_dns_cidrs" {
  type        = list(string)
  description = <<-EOT
    List of CIDR ranges allowed to query the DNS server (UDP 53). newserv's
    DNS server resolves any query to the server's public IP, which makes it
    a candidate for DNS reflection attacks if left open to the internet.
    Set this to the public IPv4 of each PSO player's home network (in /32
    form, e.g. ["73.242.54.43/32", "204.27.40.0/24"]).
    Update when a friend joins, when an ISP rotates someone's IP, or when
    someone takes their Switch to a new house. To open to the world (not
    recommended), set this to ["0.0.0.0/0"].
  EOT
}

variable "allowed_game_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR allowed to reach PSO game ports (TCP 9000-9204)."
}

variable "github_repo" {
  type        = string
  default     = "joshkautz/pso-server"
  description = "GitHub repo (owner/name) trusted by the OIDC role."
}

variable "github_oidc_branch" {
  type        = string
  default     = "main"
  description = "Branch the OIDC role trusts. Use '*' to trust any ref (less safe)."
}

variable "enable_auto_snapshots" {
  type        = bool
  default     = true
  description = "Whether to enable Lightsail automatic daily snapshots (~$2/mo extra). Strongly recommended."
}

variable "auto_snapshot_time_utc" {
  type        = string
  default     = "08:00"
  description = "UTC time for daily auto-snapshot. Format HH:00. Pick an off-peak hour for your players."
}

variable "backup_retention_days" {
  type        = number
  default     = 30
  description = "Number of days to keep nightly S3 backups before lifecycle expiration."
}
