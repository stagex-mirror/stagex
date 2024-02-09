export PLATFORM := linux/amd64
export BUILDER := $(shell which docker)
export REGISTRY_LOCAL := stagex-local
export REGISTRY_REMOTE := stagex
export NOCACHE ?= 0
export MIRRORS := \
	git.distrust.co \
	hub.docker.com
ifeq ($(NOCACHE), 1)
NOCACHE_FLAG=--no-cache
else
NOCACHE_FLAG=
endif
export NOCACHE_FLAG
clean_logs := $(shell rm *.log 2>&1 >/dev/null || :)
include src/macros.mk
include src/packages.mk
include src/packages_manual.mk

DEFAULT_GOAL := default
.PHONY: default
default: compat bootstrap core

.PHONY: compat
compat:
	./src/compat.sh

.PHONY: digests
digests:
	@for each in $$(find out -iname "index.json"| sort); do \
		printf \
			"%-20s | %-50s\n"  \
			"$$(basename $$(dirname $$each))"  \
			$$(cat $$each | jq -r '.manifests[].digest'); \
	done

out/graph.svg: Makefile
	$(MAKE) -Bnd | make2graph | dot -Tsvg -o graph.svg
