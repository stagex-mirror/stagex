#!/bin/sh

get_deps='nix-store -q --requisites $(dirname $(dirname $(which cargo)))'
printf "DEPS (Nix): %s\n" $(nix-shell -p cargo --run "$get_deps" | wc -l)
