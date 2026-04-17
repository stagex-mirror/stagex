#!/usr/bin/env bash
set -u

check_command() {
    if [ $? -ne 0 ]; then
        echo -e "Something went wrong: $1.$NC"
        exit "${2:-255}"
    fi
}

SCRIPT_DIR=$(dirname "$0")

SIGNATURES="https://codeberg.org/stagex/signatures.git"
SIGNATURES_SSH="git@codeberg.org:stagex/signatures.git"
REGISTRY=${1:-stagex}

if [ ! -d "signatures/$REGISTRY" ]; then
  git clone "$SIGNATURES" "signatures" # Clone repo to make signatures
  check_command "Failed to clone the repository"

  git -C signatures remote set-url --push origin "${SIGNATURES_SSH}"
  check_command "Failed to set SSH upstream"
else
  git -C signatures fetch
  check_command "Failed fetch latest repo content"
fi
