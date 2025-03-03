#!/usr/bin/bash
set -eu

# Generate container image signatures in PGP sigstore format

# Usage
usage() {
    echo "Usage:"
    echo "$0 <registry|repo_url> <package name> <branch_name> <file_name> [commit_message]"
    echo "One does not simply run this script without the proper arguments!"
    exit 1
}

# Successful?
check_command() {
    if [ $? -ne 0 ]; then
        echo "Oh no! Something went wrong: $1. Do or do not. There is no try!"
        exit 1
    fi
}

# Check for required arguments
if [ "$#" -lt 3 ]; then
    usage
fi

get-primary-fp() {
  FP="$1"
  if $GPG --list-keys --with-colons "$FP" > /dev/null 2> /dev/null; then
    $GPG --list-keys --with-colons "$FP" | grep fpr | cut -d: -f10 | head -n1
  fi
}

# Variables
GPG=${STAGEX_GPG:-gpg}
GPG_SIGN=${STAGEX_GPG_SIGN:-${GPG}}
GPGV=${STAGEX_GPGV:-gpgv}
RELEASE=$(date '+%Y-%m-'0)
FPR="$(get-primary-fp "$SIGNING_KEY")"
SIGNING_KEY="$(git config user.signingkey)"
SIGNER=$(git config user.name) || { echo "Failed to find signer, are you sure you are not a hobbit?"; exit 1; }
test ! -z "$FPR"

TEMPFILE="$(mktemp)"
# SIGNATURES := https://codeberg.org/stagex/sigs.stagex.tools.git from MAKEFILE
REGISTRY=${1?}
PACKAGE_NAME=${2?}
BRANCH_NAME="${3:-$SIGNER/$RELEASE}"
COMMIT_MESSAGE="${5:-Add signatures for release $RELEASE by: $SIGNER}"  
ID=$(cat out/${PACKAGE_NAME}/index.json | jq -r '.manifests[].digest | sub ("sha256:";"")')
DIR="signatures/${REGISTRY}/${NAME}@sha256=${ID}

get-signing-fp() {
  FILE="$1"
  ($GPGV "$FILE" >/dev/null || :) 2>&1 | awk '$4 == "key" { print $5 }'
}

echo "
GPG=$GPG
GPGV=$GPGV
RELEASE=$RELEASE
USER=$SIGNER
SIGNING_KEY=$SIGNING
FPR=$FPR
TEMPFILE=$TEMPFILE
REGISTRY=$REGISTRY
PACKAGE_NAME=$PACKAGE_NAME
BRANCH_NAME=$BRANCH_NAME
COMMIT_MESSAGE=$COMMIT_MESSAGE  
ID=$ID
DIR=$DIR
"

# Clone the repository into the temporary directory
git clone "$SIGNATURES" "signatures/$REGISTRY"
check_command "Failed to clone the repository. Did you forget the URL, or is it just a trap set by the Sith?"

mkdir -p "${DIR}"
check_command "Failed to create signatures, how is this possible?"

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
    SIGNING_FP="$(get-signing-fp $file)"
    CERT_FP="$(get-primary-fp "$SIGNING_FP")"
    if test "$FP" = "$CERT_FP"; then
      echo "found matching signature: $file" >/dev/stderr
      return 1
    fi
  done
  return 0
}

cd "signatures/$REGISTRY" || { echo "Failed to enter the secret lair."; exit 1; }
# Check if the branch already exists
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    echo "Whoa there! The branch '$BRANCH_NAME' already exists!"
    cd ..
    rm -rf "${DIR}"
    exit 1
fi

# Create a new branch
git checkout -b "$BRANCH_NAME"
check_command "Failed to create a new branch. 'You shall not pass\!'"

if dir-has-no-sig "$DIR" "$FPR"; then
  echo "Signing: $NAME"
  FILENAME="$(get-filename "$DIR")"
  printf \
      '[{"critical":{"identity":{"docker-reference":"%s/%s"},"image":{"docker-manifest-digest":"%s"},"type":"pgp container image signature"},"optional":null}]' \
      "$REGISTRY" "$NAME" "$ID" \
      | $GPG_SIGN --sign > "$TEMPFILE"
  mv "$TEMPFILE" "$FILENAME"
fi

# Add the file to staging
git add "$FILENAME"
check_command "Failed to add the file to staging. Are you trying to convince a Cylon to join the Resistance?"

# Commit the changes
git commit -m "$COMMIT_MESSAGE"
check_command "Failed to commit changes. Did the Dark Side tempt you?"

# Push the new branch to the remote repository
git push origin "$BRANCH_NAME"
check_command "Failed to push changes. Is the internet down, or did the Death Star just blow up your Wi-Fi?"

# Clean up: remove the temporary directory
cd ..
rm -rf "signatures/${REGISTRY}"

echo "🎉 Huzzah! Successfully created branch '$BRANCH_NAME', signed and pushed changes. You are the chosen one, destined to bring balance to a reproducible future!"
