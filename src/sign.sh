#!/usr/bin/env bash
set -eu
# Generate container image signatures in PGP sigstore format
usage() {
    printf "%s <registry|repo_url> <package name> <branch_name> [commit_message]
    To test it run: \n %s sigs.stagex.tools.git bootstrap-stage0" "$0" "$0"
    exit 1
}
check_command() {
    if [ $? -ne 0 ]; then
        echo -e "Do or do not. Something went wrong: $1."
        exit 1
    fi
}
# Check for required arguments
if [ "$#" -lt 2 ]; then
    usage
fi

get-primary-fp() {
  FP="$1"
  if $GPG --list-keys --with-colons "$FP" > /dev/null 2> /dev/null; then
    $GPG --list-keys --with-colons "$FP" | grep fpr | cut -d: -f10 | head -n1
  fi
}
# Variables
RED='\033[0;31m' # for echo color
NC='\033[0m' # No color
GPG=${STAGEX_GPG:-gpg}
GPG_SIGN=${STAGEX_GPG_SIGN:-${GPG}}
GPGV=${STAGEX_GPGV:-gpgv}
SCRIPT_DIR=$(dirname "$0")
RELEASE=$("$SCRIPT_DIR"/gen-version.sh)
SIGNER=$(git config user.name) || { echo "Failed to find user for signing"; exit 1; }
SIGNING_KEY="$(git config user.signingkey)"
FPR="$(get-primary-fp "${SIGNING_KEY}")"
test ! -z "$FPR"
TEMPFILE="$(mktemp)"
#From SIGNATURES := https://codeberg.org/stagex/sigs.stagex.tools.git from MAKEFILE
SIGNATURES="https://codeberg.org/stagex/signatures.git"
SIGNATURES_SSH="git@codeberg.org:stagex/signatures.git"
REGISTRY=${1:-stagex}
PACKAGE_NAME=${2?}
BRANCH_NAME="${3:-release/$RELEASE}"

COMMIT_MESSAGE="${4:-Add signatures for release $RELEASE by: $SIGNER}"  
INDEX_ID=$(cat out/"${PACKAGE_NAME}"/index.json | jq -r '.manifests[].digest | sub ("sha256:";"")')
MANIFEST_ID=$(cat out/"${PACKAGE_NAME}"/blobs/sha256/"${INDEX_ID}" | jq -r '.manifests[].digest | sub ("sha256:";"")')
DIR="signatures/${REGISTRY}/${PACKAGE_NAME}@sha256=${MANIFEST_ID}"

if [ ! -d "signatures/$REGISTRY" ]; then
  git clone "$SIGNATURES" "signatures" # Clone repo to make signatures
  check_command "Failed to clone the repository"
  cd signatures
  git remote set-url --push origin "${SIGNATURES_SSH}"
  cd ..
fi

mkdir -p "${DIR}"
check_command "Failed to create signatures folder"

get-filename() {
  DIR="$1"
  SIGNUM=1
  if [ -f "${DIR}/signature-1" ] 
  then 
    LASTSIGNUM=$( \
      find "${DIR}" -type f -printf "%f\n" \
      | sort -t- -k2 -n \
      | tail -n1 \
      | sed 's/signature-//' \
    ) \
      && (("SIGNUM=LASTSIGNUM+1")) 
  else 
    true
  fi
  echo "${DIR}/signature-${SIGNUM}"
}

get-signing-fp() {
  FILE="$1"
  ($GPGV "$FILE" >/dev/null || :) 2>&1 | awk '$4 == "key" { print $5 }'
}

dir-has-no-sig() {
  echo "$DIR" >/dev/stderr
  DIR="$1"
  FP="$2"
  for file in "${DIR}"/*; do
    # We want to check if a fingerprint matches, we don't need to check if
    # the signature is valid.
    signing_FP="$(get-signing-fp "$file")"
    CERT_FP="$(get-primary-fp "$signing_FP")"
    if test "$FP" = "$CERT_FP"; then
      echo "found matching signature: $file" >/dev/stderr
      return 1
    fi
  done
  return 0
}

cd "signatures/$REGISTRY" || { echo "Failed to enter signatures dir"; exit 1; }
DIR="${PACKAGE_NAME}@sha256=${MANIFEST_ID}"
# Check if the branch already exists on the remote
if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME"; then
  git checkout "$BRANCH_NAME"
  check_command "${RED}Failed to check out existing branch: $BRANCH_NAME"
else
  git checkout -b "$BRANCH_NAME"
  check_command "${RED}Failed to create a new branch: $BRANCH_NAME"
fi

if dir-has-no-sig "$DIR" "$FPR"; then
  FILENAME="$(get-filename "$DIR")"
  printf \
      '{"critical":{"identity":{"docker-reference":"%s/%s"},"image":{"docker-manifest-digest":"%s"},"type":"atomic container signature"},"optional":{}}' \
      "$REGISTRY" "$PACKAGE_NAME" "sha256:$MANIFEST_ID" | $GPG --sign > "$TEMPFILE"
  mv "$TEMPFILE" "$FILENAME"
else
  echo "Nothing to do"
  exit 0
fi
