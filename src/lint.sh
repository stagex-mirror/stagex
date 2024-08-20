#!/bin/bash
set -eu

has-stage () {
  grep -rnw ./packages/*/Containerfile -e "^FROM.*${1}$" | awk -F"/" '{ print $3 }' | sort
}

check-stages () {
  all_packages=$(ls -1 ./packages | sort)
  stages="base fetch build install package"
  incomplete=""

  for stage in $stages; do
    missing=$(comm -13 <(has-stage "${stage}") <(ls -1 ./packages | sort))
    if [ $(printf "${missing}" | wc -l) -gt "0" ]; then
      incomplete="${incomplete}$(echo "${missing}" | xargs printf "{ \"package\": \"%s\", \"stage\": \"${stage}\" },")"
    fi
  done

  incomplete=$(echo "[${incomplete}]" | sed 's/,]$/]/')

  [ "${incomplete}" == "[]" ] && exit 0
  echo "${incomplete}"
  exit 1

}

check-stages
