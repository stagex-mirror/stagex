#!/bin/sh

set -eux

# Setup a rootless Docker, as sufficient to build/run StageX images. This
# includes install BuildKit and doing a minimal amount of configuration to the
# user's profile (`~/.profile`). As this script does not verify the integrity
# of the download dependencies, users SHOULD read and execute the commands
# within the script itself instead of executing this directly. This script
# assumes there is not a system-wide Docker daemon (which would conflict) nor a
# pre-existing Docker installation.
#
# The existing host _MUST_ have a Linux kernel of at least 5.11 in order to
# support the `containerd` storage backend (as required). The `newuidmap` and
# `newgidmap` commands are also required, frequently provided by the `uidmap`
# package, along with Python >= 3.11 (which isn't provided by this script).
#
# This will not configure the automatic start/stopping of Docker, which it will
# automatically do if it detects `systemd` as available. The user MAY have to
# manually add `~/bin` to their path and start the Docker daemon. In that case,
# the script to set up Docker _SHOULD_ print the necessary steps to do so. The
# general requirement is to erase the contents of `$XDG_RUNTIME_DIR` before
# running the installed `dockerd-rootless.sh` script.
#
# In order for networking within containers to work, the `slrip4netns` package
# (or equivalent) MAY be required. This is not generally required to build
# packages within the StageX repository however as dependencies are frequently
# downloaded (and verified) outside of the container runtime, then provided as
# context to the container runtime.

KERNEL_MAJOR_VERSION=$(uname -r | cut -d'.' -f1)
KERNEL_MINOR_VERSION=$(uname -r | cut -d'.' -f2)
if [ \( "$KERNEL_MAJOR_VERSION" -lt 5 \) -o \( \( "$KERNEL_MAJOR_VERSION" -eq 5 \) -a \( "$KERNEL_MINOR_VERSION" -lt 11 \) \) ]; then
  echo "Linux kernel is less than 5.11 and cannot provide the necessary filesystem for \`containerd\`"
  exit 1
fi

if [ "$(command -v docker; echo $?)" -eq 0 ]; then
  echo "\`docker\` was already installed on this system"
  exit 1
fi

if [ \( ! XDG_RUNTIME_DIR = "" \) -o \( ! DOCKER_HOST = "" \) ]; then
  echo "Existing \`docker\` configuration (\`XDG_RUNTIME_DIR\`, \`DOCKER_HOST\`) found"
  exit 1
fi

PYTHON3_MINOR_VERSION=$(python3 --version | cut -d'.' -f2)
if [ "$PYTHON3_MINOR_VERSION" -lt 11 ]; then
  echo "The installed \`python3\` is not at least 3.11, as required"
  exit 1
fi

# if [ ! -f "./digests/user.txt" ]; then
#  echo "Could not find \`./digests/user.txt\`. Please run this from the root of the Stageˣ repository."
#  exit 1
# fi
# BUILDKIT_DIGEST=$(grep " user-buildkit$" "./digests/user.txt" | cut -d' ' -f1)

# Install rootless Docker
GET_ROOTLESS_DOCKER=$(curl -fsSL https://get.docker.com/rootless)
echo "$GET_ROOTLESS_DOCKER" | sh

# Configure the user's profile
CONFIG='
export XDG_RUNTIME_DIR=~/.docker/run
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
# Define where the `containerd` socket lives as necessary to run `ctr`
export CONTAINERD_ADDRESS=${CONTAINERD_ADDRESS:-$XDG_RUNTIME_DIR/docker/containerd/containerd.sock}
# Have `ctr` use Docker's `moby` namespace by default
export CONTAINERD_NAMESPACE=${CONTAINERD_NAMESPACE:-moby}
'

if [ ! -f "~/.profile" ]; then
  echo "\`~/.profile\` not found. Please add the following lines to your profile:"
  echo "\`\`\`"
  echo $CONFIG
  echo "\`\`\`"
  exit 2
fi
echo "$CONFIG" >> ~/.profile

# TODO: Uncomment when `stagex/user-buildkit` is packaged as necessary for this.
# echo "Please install BuildKit via running the following command, when your Docker daemon is up:"
# echo "\`docker plugin install stagex/user-buildkit@sha256:$BUILDKIT_DIGEST\`"

echo "Please manually install BuildKit to complete the requirements for Stageˣ."
