#!/bin/sh
set -eu

date="$(date '+%F %T')"

fetch(){
	line=${1?}
	local package=$(echo ${line} | sed 's/^[a-z0-9]\+ \(.*\)/\1/g');
	local hash=$(echo ${line} | sed 's/^\([a-z0-9]\+\) .*/\1/g');
	local ref=$(printf "stagex/%s@sha256:%s" "$package" "$hash");
	docker pull ${ref}
	rm -rf "out/${package}"
	mkdir -p "out/${package}"
	docker save ${ref} | tar -xC out/${package}
}

while read line; do
	fetch "${line}"
done < digests/bootstrap.txt < digests/core.txt < digests/pallet.txt < digests/user.txt

find out -type f -exec touch -d "$date" {} +
