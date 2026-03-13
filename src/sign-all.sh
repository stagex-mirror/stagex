#!/usr/bin/env bash
set -ux

GPG=${STAGEX_GPG:-gpg}
GPG_SIGN=${STAGEX_GPG_SIGN:-${GPG}}
GPGV=${STAGEX_GPGV:-gpgv}

check_command() {
    if [ $? -ne 0 ]; then
        echo -e "Something went wrong: $1.$NC"
        exit "${2:-255}"
    fi
}

get_primary_fp() {
  FP="$1"
  if $GPG --list-keys --with-colons "$FP" > /dev/null 2> /dev/null; then
    $GPG --list-keys --with-colons "$FP" | grep fpr | cut -d: -f10 | head -n1
  fi
}

# Variables
RED='\033[0;31m' # for echo color
NC='\033[0m' # No color
SCRIPT_DIR=$(dirname "$0")

git diff --quiet
check_command "Dirty Git tree (uncommitted files?)"

if test "${2:-0}" = "0"; then
	RELEASE=$("$SCRIPT_DIR"/gen-version.sh)
fi

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

BRANCH_NAME="release/$RELEASE"

pushd "signatures/$REGISTRY"
check_command "Failed to enter signatures directory"

if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME"; then
  # The remote does have a branch named after this release
  if test "$(git rev-parse --abbrev-ref HEAD)" = "$BRANCH_NAME"; then
    # We're on the branch already, fast-forward if we differ
    if test ! "$(git rev-parse HEAD)" = "$(git rev-parse origin/$BRANCH_NAME)"; then
      # Fast forward is necessary
      git merge --ff-only "origin/$BRANCH_NAME"
      check_command "Failed to fast-forward remote (bonus local commits?)"
    else
      : # We are already at the latest commit on the branch
    fi
  else
    # We're not on the branch, let's set up a local based on the remote
    git checkout "$BRANCH_NAME"
    check_command "Failed to check out existing branch: $BRANCH_NAME"
  fi
elif git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  # The local does have a branch named after this release
  if test "$(git rev-parse --abbrev-ref HEAD)" = "$BRANCH_NAME"; then
    : # We're already on the branch
  else
    # We're not on the brach, check it out
    git checkout "$BRANCH_NAME"
    check_command "Failed to check out existing branch: $BRANCH_NAME"
  fi
else
  # The remote and local does not have a branch named after this release
  git checkout -b "$BRANCH_NAME"
  check_command "Failed to create a new branch: $BRANCH_NAME"
fi

SIGNER=$(git config user.name) || { echo "Failed to find user for signing"; exit 1; }
SIGNING_KEY="$(git config user.signingkey)"
if [[ -z "${SIGNING_KEY// }" ]]; then 
  echo -e "${RED}Please configure your signingkey in git"
  echo -e "${NC} you can run: 'git config --global user.signingkey <your fingerprint>'"
  exit 1
fi

FPR="$(get_primary_fp "${SIGNING_KEY}")"
test ! -z "$FPR"
check_command "Could not get fingerprint from signing key ${SIGNING_KEY}"

popd

cut -d' ' -f2 digests/*.txt | xargs -n1 bash "$SCRIPT_DIR"/sign.sh "$REGISTRY" "$FPR"
check_command "Could not sign all digests"
