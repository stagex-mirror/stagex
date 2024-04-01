#!/bin/sh
set -eu

for each in $( \
    cat digests.txt \
    | sed 's/\([a-z0-9]\+\) \(.*\)/signatures\/stagex\/\2@sha256=\1/g' \
); do
    echo $each;
    for sig in $(find $each -type f); do
        cat $sig | /usr/bin/gpg -v 2>&1 > /dev/null \
            | grep "Good signature" || :
    done;
done
