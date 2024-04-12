#!/bin/sh

# This script basically always needs root
[[ $EUID -ne 0 ]] && exec sudo /bin/sh "$0" "$@"

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update

# Install required packages
sudo apt install build-essential jq gpg docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

cat << ENDHERE >/etc/docker/daemon.json
{
  "features": {
    "containerd-snapshotter": true
  }
}
ENDHERE

systemctl restart docker

docker buildx create --driver docker-container --bootstrap --name build --use
