#!/bin/bash
set -eu

# This script basically always needs root:
[[ "$(id -u)" -ne 0 ]] && exec sudo "$0" "$@"

# Add Docker's official GPG key:
apt-get update
apt-get install ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update

# Install required packages:
apt install -y build-essential jq gpg docker-ce docker-ce-cli containerd.io docker-buildx-plugin

cat << ENDHERE >/etc/docker/daemon.json
{
  "features": {
    "containerd-snapshotter": true
  }
}
ENDHERE

systemctl restart docker

docker buildx create --driver docker-container --bootstrap --name build --use

# If this script was not executed by root, add the calling user to the docker group:
if [[ -n "$SUDO_USER" && "$SUDO_USER" != root ]]; then
  usermod -aG docker "$SUDO_USER"
  echo "Added user $SUDO_USER to docker group, you may need to restart your session to invoke make / docker without sudo."
fi
