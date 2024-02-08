#!/bin/bash

for each in $(find src/*/*/Containerfile); do
    package=$(basename $(dirname ${each}))
    digest_file=out/${package}/index.json
    digest_line=""
    if [ -e ${digest_file} ]; then
        printf -- ' --build-context %s=oci-layout://./out/%s' "${package}" "${package}"
    fi
done
