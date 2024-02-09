#!/bin/bash

# Warning: This is slow/brittle garbage and will probably kill your dog
# Please replace it with a script in a near universally pre-installed
# language like python

manual_targets="rust llvm"

gen_deps() {
    local container_file=${1?}
    local dependencies=$( \
        cat ${container_file} \
        | egrep -- "(--from=|FROM)" \
        | sed \
            -e "s/^FROM \([^ ]\+\) .*/\1/" \
            -e "s/^COPY --from=\([^ ]\+\).*/\1/g" \
        | grep -v scratch \
        | grep -v base \
        | grep -v fetch \
        | grep -v build \
        | grep -v install \
        | uniq \
        | tr '\n' ' '
    )
    printf "$dependencies"
}

printf "src/packages.mk: src/packages.sh\n"
printf "\tsrc/packages.sh > src/packages.mk\n\n"
bs='\'
for container_file in $(find src/*/*/Containerfile); do
    package=$(basename $(dirname ${container_file}))
    [[ "$manual_targets" =~ "$package" ]] && continue
    group=$(basename $(dirname $(dirname ${container_file})))
    deps=$(gen_deps "${container_file}")
    printf "PHONY: ${package}\n${package}: out/${package}.digest\n"
    printf "out/${package}.digest: %s" "$bs"
    printf "\n\t${container_file}"
    for each in $(find src/*/*/Containerfile); do
        dep_package=$(basename $(dirname ${each}))
        if [[ "$deps" =~ "$dep_package" ]]; then
            printf " %s\n\t${dep_package}" "$bs"
        fi
    done
    printf '\n\t$(call build,%s,%s)' "$group" "$package"
    printf "\n\n"
done
