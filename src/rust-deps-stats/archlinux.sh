#!/bin/sh

pacman -Syu --noconfirm rust
printf "DEPS (Arch Linux): %s\n" $(pacman -Q | wc -l)
