export PLATFORM := linux/amd64
export BUILDER := $(shell which docker)
export REGISTRY_LOCAL := stagex-local
export REGISTRY_REMOTE := stagex
export CHECK ?= 0
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
ifeq ($(CHECK), 1)
CHECK_FLAG=--check
else
CHECK_FLAG=
endif
export CHECK_FLAG

clean_logs := $(shell rm *.log 2>&1 >/dev/null || :)

DEFAULT_GOAL := default
.PHONY: default
default: compat all

.PHONY: all check compat preseed verify sign

include src/macros.mk

out:
	mkdir out

all_packages := $(shell $(call folder-list,packages))

$(all_packages): %: out/%/index.json

$(foreach package,$(all_packages),$(eval $(call gen-target,$(package))))
