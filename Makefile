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

.PHONY: preseed
preseed:
	./src/preseed.sh

.PHONY: verify
verify:
	./src/verify.sh

.PHONY: all-tests
all-tests:
	./src/run-tests.sh

.PHONY: digests
digests:
	./src/digests.sh

digests.txt: $(shell find out -iname index.json | tr "\n" " ")
	./src/digests.sh > digests.txt

.PHONY: sign
sign:
	./src/digests.sh | diff digests.txt /dev/stdin
	cut -d' ' -f2 digests.txt | xargs -n1 ./src/sign.sh $(REGISTRY_REMOTE)

out/graph.svg: Makefile
	$(MAKE) -Bnd | make2graph | dot -Tsvg -o graph.svg

.PHONY: gen-make
gen-make: out/sxctl/index.json $(shell find packages/*/Containerfile | tr '\n' ' ')
	env -C out/sxctl tar -cf - . | docker load
	docker run \
		--rm \
		--volume .:/src \
		--user $(shell id -u):$(shell id -g) \
		stagex/sxctl -baseDir=/src gen make
