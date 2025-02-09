#!/bin/sh

set -eux

if ! git status --porcelain; then
  echo 'Unclean tree! Aborting!'
  exit 1
fi

date=$(date +%Y.%m)

branch_r() {
  r="${1:-0}"
  if git show-ref --tags "${date}.${r}" --quiet; then
    branch_r $(( $r + 1 ))
  else
    echo $r
  fi
}

release="$(branch_r)"

branch="release/${date}.${release}"

git fetch origin staging
git checkout origin/staging
git switch -c "${branch}"
