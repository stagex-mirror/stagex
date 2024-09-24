#!/bin/sh

apt-get update
apt-get install -y cargo rustc
printf "DEPS (Debian): %s\n" $(dpkg --get-selections | wc -l)
