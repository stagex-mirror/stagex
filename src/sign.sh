#!/bin/bash
set -eu

# Generate container image signatures in PGP sigstore format

REGISTRY=${1?}
NAME=${2?}

ID=$(cat out/${NAME}/index.json | jq -r '.manifests[].digest | sub ("sha256:";"")')
DIR=signatures/${REGISTRY}/${NAME}@sha256=${ID}
SIGNUM=1

mkdir -p ${DIR}

get-filename() {
  DIR="$1"
  SIGNUM=1
  [ -f "${DIR}/signature-1" ] \
      && LASTSIGNUM=$( \
          find ${DIR} -type f -printf "%f\n" \
          | sort -t- -k2 -n \
          | tail -n1 \
          | sed 's/signature-//' \
      ) \
      && let "SIGNUM=LASTSIGNUM+1"
  echo "${DIR}/signature-${SIGNUM}"
}

get-signing-fp() {
  FILE="$1"
  (gpgv "$FILE" >/dev/null || :) 2>&1 | awk '$4 == "key" { print $5 }'
}

get-primary-fp() {
  FP="$1"
  gpg --list-keys --with-colons "$FP" | grep fpr | cut -d: -f10 | head -n1
}

dir-has-no-sig() {
  echo "$DIR" >/dev/stderr
  DIR="$1"
  FP="$2"
  for file in "${DIR}"/*; do
    # We want to check if a fingerprint matches, we don't need to check if
    # the signature is valid.
    SIGNING_FP="$(get-signing-fp $file)"
    CERT_FP="$(get-primary-fp "$SIGNING_FP")"
    if test "$FP" = "$CERT_FP"; then
      echo "found matching signature: $file" >/dev/stderr
      return 1
    fi
  done
  return 0
}

SIGNING_KEY="$(git config user.signingkey)"
FPR="$(get-primary-fp "$SIGNING_KEY")"
test ! -z "$FPR"

TEMPFILE="$(mktemp)"

if dir-has-no-sig "$DIR" "$FPR"; then
  echo "Signing: $NAME"
  FILENAME="$(get-filename "$DIR")"
  printf \
      '[{"critical":{"identity":{"docker-reference":"%s/%s"},"image":{"docker-manifest-digest":"%s"},"type":"pgp container image signature"},"optional":null}]' \
      "$REGISTRY" "$NAME" "$ID" \
      | gpg --sign > "$TEMPFILE"
  mv "$TEMPFILE" "$FILENAME"
fi
