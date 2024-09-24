#!/bin/sh

SCRIPTDIR="$(cd "$(dirname $0)"; pwd)"

# for distro in debian:bookworm debian:bookworm-slim archlinux:base fedora:40 alpine:3.20.3 nixos/nix:2.24.7; do
for distro in nixos/nix:2.24.7; do
  script="$(echo "${distro}" | tr "/" "_")"
  docker run --rm -v "$SCRIPTDIR:/scripts:ro" $distro /bin/sh /scripts/$script.sh | grep --color "^DEPS"
done
