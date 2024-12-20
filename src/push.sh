#!/bin/bash
release=sx${1}
for each in $(find out/*/index.json); do
    package=$(basename $(dirname ${each}))
    toml_file=packages/${package/-/\/}/package.toml
    version=$(cat ${toml_file} | grep "^version =" | head -n1 | sed 's/version =//g' | jq -r .)
    echo "env -C out/${package} tar -cf - . | docker load"
    if [ -n "${version}" ]; then
        echo docker tag stagex/${package}:${version} stagex/${package}:latest
        echo docker push stagex/${package}:${version}
    fi
    echo docker tag stagex/${package}:latest stagex/${package}:${release}
    echo docker push stagex/${package}:${release}
    echo docker push stagex/${package}:latest
done
