provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "pso-server"
      ManagedBy = "terraform"
      Repo      = var.github_repo
    }
  }
}

# --- SSH key pair ----------------------------------------------------------

# The public half of the deploy key is stored in Lightsail so the instance
# trusts it for SSH. The private half is held in GitHub Secrets as
# SSH_PRIVATE_KEY and used by the deploy workflow. See infra/README.md.
resource "aws_lightsail_key_pair" "deploy" {
  name       = "${var.instance_name}-deploy"
  public_key = var.ssh_public_key
}

# --- Instance + static IP --------------------------------------------------

resource "aws_lightsail_instance" "pso" {
  name              = var.instance_name
  availability_zone = var.availability_zone
  blueprint_id      = var.blueprint_id
  bundle_id         = var.instance_bundle_id
  key_pair_name     = aws_lightsail_key_pair.deploy.name
  user_data         = file("${path.module}/../server/cloud-init.sh")

  dynamic "add_on" {
    for_each = var.enable_auto_snapshots ? [1] : []
    content {
      type          = "AutoSnapshot"
      snapshot_time = var.auto_snapshot_time_utc
      status        = "Enabled"
    }
  }

  # cloud-init runs on first boot only. Changing user_data after the fact
  # has no effect on the running instance, so we don't recreate the instance
  # just because the file changed.
  lifecycle {
    ignore_changes = [user_data]
  }
}

resource "aws_lightsail_static_ip" "pso" {
  name = "${var.instance_name}-ip"
}

resource "aws_lightsail_static_ip_attachment" "pso" {
  static_ip_name = aws_lightsail_static_ip.pso.name
  instance_name  = aws_lightsail_instance.pso.name
}

# --- Public ports (Lightsail firewall) ------------------------------------

resource "aws_lightsail_instance_public_ports" "pso" {
  instance_name = aws_lightsail_instance.pso.name

  # SSH
  port_info {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidrs     = [var.allowed_admin_cidr]
  }

  # DNS (newserv's built-in DNS server)
  port_info {
    from_port = 53
    to_port   = 53
    protocol  = "udp"
    cidrs     = var.allowed_dns_cidrs
  }

  # PSO GC game/login ports. The exact port used depends on the disc
  # revision; the README lists 9000-9204 as the GC range.
  port_info {
    from_port = 9000
    to_port   = 9204
    protocol  = "tcp"
    cidrs     = [var.allowed_game_cidr]
  }

  # Public HTTP for the dashboard. Caddy uses port 80 for the Let's
  # Encrypt ACME HTTP-01 challenge and for redirecting HTTP -> HTTPS.
  port_info {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidrs     = ["0.0.0.0/0"]
  }

  # Public HTTPS for the dashboard. Caddy terminates TLS here and
  # reverse-proxies to the dashboard container on the internal docker
  # network.
  port_info {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidrs     = ["0.0.0.0/0"]
  }

  # PSO PC clients (Sega's PC v2 release).
  port_info {
    from_port = 9300
    to_port   = 9300
    protocol  = "tcp"
    cidrs     = [var.allowed_game_cidr]
  }

  # PSO Xbox.
  port_info {
    from_port = 9500
    to_port   = 9500
    protocol  = "tcp"
    cidrs     = [var.allowed_game_cidr]
  }

  # PSO Blue Burst — patch + game + data servers. Range covers:
  #   10000      PC-style patch port (legacy PC clients)
  #   11000      BB patch
  #   11100      BB JP patch
  #   11101      BB JP game
  #   11200      BB patch (HG)
  #   12000-12001 BB game/data
  # See server/config.json's PortConfiguration block for the per-port
  # role definitions newserv listens with.
  port_info {
    from_port = 10000
    to_port   = 12001
    protocol  = "tcp"
    cidrs     = [var.allowed_game_cidr]
  }
}
