#!/usr/bin/env bash
#
# First-boot bootstrap for the Lightsail instance. Installs Docker and
# prepares the directory layout that the deploy workflow expects.
#
# Lightsail's user_data field interprets its contents as a shell script
# regardless of any #cloud-config magic header (unlike EC2), so this has
# to be bash rather than cloud-init YAML.
#
# IMPORTANT: cloud-init / user_data is one-shot per instance. Changes to
# this file do NOT re-run on existing instances. To re-bootstrap, either
# taint and recreate the Lightsail instance via terraform, or SSH in and
# run this script manually.

set -euo pipefail

log() { printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"; }

log "starting pso-server bootstrap"

# --- Idempotency guard ---------------------------------------------------
# If a previous incomplete run left the Docker repo entry pointing to a
# missing key, the very first apt-get update will fail. Clean that up so
# the script is safe to re-run.
if [ -f /etc/apt/sources.list.d/docker.list ] && [ ! -f /etc/apt/keyrings/docker.asc ]; then
  log "cleaning up orphan Docker repo entry from previous incomplete run"
  rm -f /etc/apt/sources.list.d/docker.list
fi

# --- Update and install prereqs ------------------------------------------
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get upgrade -y
apt-get install -y ca-certificates curl gnupg rsync

# --- Install Docker from the official Docker apt repo --------------------

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker ubuntu
systemctl enable --now docker

# --- Prepare directory layout for the deploy workflow --------------------

install -d -o ubuntu -g ubuntu /home/ubuntu/pso-server
install -d -o ubuntu -g ubuntu /home/ubuntu/pso-server/system
install -d -o ubuntu -g ubuntu /home/ubuntu/pso-server/system/accounts

# --- Mark bootstrap complete --------------------------------------------

echo "1" > /etc/pso-server-bootstrap.version
touch /home/ubuntu/pso-server/.cloud-init-done
chown ubuntu:ubuntu /home/ubuntu/pso-server/.cloud-init-done

log "pso-server bootstrap complete"
