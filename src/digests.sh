#!/bin/sh

for each in $(find out -iname "index.json"| sort); do
  printf \
    "%s %s\n" \
    $(cat $each | jq -r '.manifests[].digest | sub ("sha256:";"")') \
    "$(basename $(dirname $each))"
done
