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

dir-has-no-sig() {
  echo "$DIR" >/dev/stderr
  DIR="$1"
  FP="$2"
  for file in "${DIR}"/*; do
    # We want to check if a fingerprint matches, we don't need to check if
    # the signature is valid.
    if (gpgv "$file" >/dev/null || :) 2>&1 | grep "$FP"; then
      echo "found matching signature: $file" >/dev/stderr
      return 1
    fi
  done
  return 0
}

SIGNING_KEY="$(git config user.signingkey)"
FPR="$(gpg --list-keys --with-colons "$SIGNING_KEY" | grep fpr | cut -d: -f10 | head -n1)"
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
