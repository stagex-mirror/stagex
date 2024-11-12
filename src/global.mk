export PLATFORM BUILDER REGISTRY CHECK NOCACHE
export TZ=UTC
export LANG=C.UTF-8
export LC_ALL=C

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

.PHONY: all check compat digests preseed verify sign help

include src/macros.mk

out:
	mkdir out

## TODO: Figure out how to foreach these to be more DRY

bootstrap_targets := $(shell $(call target-list,bootstrap))
bootstrap: $(bootstrap_targets)
$(bootstrap_targets): %: out/%/index.json
$(foreach target,$(bootstrap_targets),$(eval $(call target-gen,$(target))))

core_targets := $(shell $(call target-list,core))
core: $(toolchain_targets)
$(core_targets): %: out/%/index.json
$(foreach target,$(core_targets),$(eval $(call target-gen,$(target))))

pallet_targets := $(shell $(call target-list,pallet))
pallet: $(pallet_targets)
$(pallet_targets): %: out/%/index.json
$(foreach target,$(pallet_targets),$(eval $(call target-gen,$(target))))

user_targets := $(shell $(call target-list,user))
user: $(user_targets)
$(user_targets): %: out/%/index.json
$(foreach target,$(user_targets),$(eval $(call target-gen,$(target))))

digests/%.txt: %
	$(call gen-digests,$(word 1,$(subst ., ,$(word 2,$(subst /, ,$@))))) > $@

digests_all: digests/pallet.txt digests/bootstrap.txt digests/core.txt digests/user.txt
