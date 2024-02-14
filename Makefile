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

DEFAULT_GOAL := default
.PHONY: default
default: all

include src/macros.mk
include src/packages.mk
include src/groups.mk

.PHONY: all
all: \
	compat \
	$(shell find packages/* -type d -exec sh -c 'basename {} | tr "\n" " "' \; ) \
	digests.txt

.PHONY: compat
compat:
	./src/compat.sh

.PHONY: digests
digests:
	@for each in $$(find out -iname "index.json"| sort); do \
		printf \
			"%s %s\n"  \
			$$(cat $$each | jq -r '.manifests[].digest | sub ("sha256:";"")') \
			"$$(basename $$(dirname $$each))";  \
	done

digests.txt: all
	mv $@ .$@.old
	$(MAKE) digests > $@
	diff $@.old $@

out/graph.svg: Makefile
	$(MAKE) -Bnd | make2graph | dot -Tsvg -o graph.svg

src/packages.mk: out/sxctl/index.json $(shell find packages/*/Containerfile | tr '\n' ' ')
	env -C out/sxctl tar -cf - . | docker load
	docker run \
		--rm \
		--volume .:/src \
		--user $(shell id -u):$(shell id -g) \
		stagex/sxctl -baseDir=/src gen make
	touch $@

