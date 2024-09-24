#!/bin/sh

yum install -y cargo
printf "DEPS (Fedora): %s\n" $(yum list installed | tail -n +2 | wc -l)
