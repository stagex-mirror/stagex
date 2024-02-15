#!/bin/bash
release=sx${1}
for each in $(find out/*/index.json); do
    package=$(basename $(dirname ${each}))
    container_file=packages/${package}/Containerfile
    version=$(cat ${container_file} | grep "^ENV VERSION=" | sed 's/.*=//g')
    echo "env -C out/${package} tar -cf - . | docker load"
    if [ -n "${version}" ]; then
        echo docker tag stagex/${package}:latest stagex/${package}:${version}
        echo docker push stagex/${package}:${version}
    fi
    echo docker tag stagex/${package}:latest stagex/${package}:${release}
    echo docker push stagex/${package}:${release}
    echo docker push stagex/${package}:latest
done
