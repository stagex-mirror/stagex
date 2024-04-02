#!/bin/bash
set -eu

pkgs=$(grep -rnw ./packages/*/Containerfile -e "^FROM.*test$" | awk -F":" '{print $1}' | tr '\n' ' ')

for containerfile in $pkgs; do
  docker build --target test - <$containerfile
done
