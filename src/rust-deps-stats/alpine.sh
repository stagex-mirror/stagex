#!/bin/sh

apk add cargo
printf "DEPS (Alpine): %s\n" $(apk list --installed | tail -n +2 | wc -l)
