#!/usr/bin/env bash
set -u

# Generate container image signatures in PGP sigstore format
usage() {
    printf "%s <registry|repo_url> <package name> <branch_name> [commit_message]
    To test it run: \n %s stagex bootstrap-stage0" "$0" "$0"
    exit 2
}

check_command() {
    if [ $? -ne 0 ]; then
        echo -e "Something went wrong: $1.$NC" >/dev/stderr
        exit "${2:-255}"
    fi
}

# Check for required arguments
if [ "$#" -lt 3 ]; then
    usage
fi

# Variables
RED='\033[0;31m' # for echo color
NC='\033[0m' # No color
GPG=${STAGEX_GPG:-gpg}
GPG_SIGN=${STAGEX_GPG_SIGN:-${GPG}}
GPGV=${STAGEX_GPGV:-gpgv}
SCRIPT_DIR=$(dirname "$0")

TEMPFILE="$(mktemp)"
REGISTRY=${1:-stagex}
FPR="$2"
PACKAGE_NAME=$3

INDEX_ID=$(jq -r '.manifests[].digest | sub ("sha256:";"")' out/"${PACKAGE_NAME}"/index.json)
MANIFEST_ID=$(jq -r '.manifests[].digest | sub ("sha256:";"")' out/"${PACKAGE_NAME}"/blobs/sha256/"${INDEX_ID}")
DIR="signatures/${REGISTRY}/${PACKAGE_NAME}@sha256=${MANIFEST_ID}"
TAG=$(jq -r '.manifests[].annotations."org.opencontainers.image.ref.name"' out/"${PACKAGE_NAME}"/index.json)

if [ ! -d "signatures/$REGISTRY" ]; then
  git clone "$SIGNATURES" "signatures" # Clone repo to make signatures
  check_command "Failed to clone the repository"
  git -C signatures remote set-url --push origin "${SIGNATURES_SSH}"
else
  if test $(($(stat -c %Y signatures/.git/FETCH_HEAD) + 60*10)) -lt $(date +%s); then
    git -C signatures fetch
    check_command "Failed fetch latest repo content"
  fi
fi

get_primary_fp() {
  FP="$1"
  if $GPG --list-keys --with-colons "$FP" > /dev/null 2> /dev/null; then
    $GPG --list-keys --with-colons "$FP" | grep fpr | cut -d: -f10 | head -n1
  fi
}

get_filename() {
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

get_signing_fp() {
  file="$1"
  ($GPGV "$file" >/dev/null || :) 2>&1 | awk '$4 == "key" { print $5 }'
}

dir_has_no_sig() {
  dir="$1"
  fpr="$2"
  for file in "${dir}"/*; do
    # We want to check if a fingerprint matches, we don't need to check if
    # the signature is valid.
    signing_fp="$(get_signing_fp "$file")"
    cert_fp="$(get_primary_fp "$signing_fp")"
    if test "$fpr" = "$cert_fp"; then
      echo "Found matching signature: ${file}" >/dev/stderr
      return 1
    fi
  done
  return 0
}

mkdir -p "${DIR}"
check_command "Failed to create signatures folder"

if dir_has_no_sig "$DIR" "$FPR"; then
  echo "Signing: $DIR" >/dev/stderr
  FILENAME="$(get_filename "$DIR")"
  printf \
      '{"critical":{"identity":{"docker-reference":"%s/%s:%s"},"image":{"docker-manifest-digest":"%s"},"type":"atomic container signature"},"optional":{}}' \
      "$REGISTRY" "$PACKAGE_NAME" "$TAG" "sha256:$MANIFEST_ID" | $GPG_SIGN --sign > "$TEMPFILE"
  check_command "${RED}Failed to sign digest: $PACKAGE_NAME@sha256:$MANIFEST_ID"
  mv "$TEMPFILE" "$FILENAME"
else
  exit 0
fi
