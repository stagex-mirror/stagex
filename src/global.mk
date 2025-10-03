export PLATFORM BUILDER RELEASE REGISTRY CHECK NOCACHE
export TZ=UTC
export LANG=C.UTF-8
export LC_ALL=C
export SOURCE_DATE_EPOCH=1
export BUILDKIT_MULTI_PLATFORM=1
export DOCKER_BUILDKIT=1

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
default: targets all

.PHONY: all check compat digests preseed fetch verify sign targets help

targets: out/targets.mk
out/targets.mk: out $(shell find packages/)
	python3 src/targets.py > $@
-include out/targets.mk

out:
	mkdir out

.PHONY: content-%
content-%: %
	ls -R out/$<
	tar -tvf $$(find out/$< -type f -printf '%s %p\n' | sort -nr | head -n1 | awk '{ print $$2 }') | less

.PHONY: digests-%
digests-%: %
	@./src/package-digests.py $<
