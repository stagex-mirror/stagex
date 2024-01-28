export PLATFORM := linux/amd64
export BUILDER := $(shell which docker)
export REGISTRY := local
export MIRRORS := \
	https://git.distrust.co/stagex \
	stagex

clean_logs := $(shell rm *.log 2>&1 >/dev/null || :)

include src/macros.mk
include src/bootstrap/build.mk
include src/core/build.mk
include src/libs/build.mk
include src/tools/build.mk

compat:
	./src/compat.sh

DEFAULT_GOAL := default
.PHONY: default
default: compat bootstrap core

out/graph.svg: Makefile
	$(MAKE) -Bnd | make2graph | dot -Tsvg -o graph.svg
