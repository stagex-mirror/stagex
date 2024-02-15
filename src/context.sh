#!/bin/bash
self=${1}
for each in $(find out/*/index.json); do
    package=$(basename $(dirname ${each}))
    [ "$package" == "$self" ] && continue
    printf -- ' --build-context %s=oci-layout://./out/%s' "stagex/${package}" "${package}"
done
