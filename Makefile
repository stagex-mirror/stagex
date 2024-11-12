NAMESPACES := pallet bootstrap core user## Namespaces to build
PROGRESS := auto## Buildkit progress output style
PLATFORM := linux/amd64## Platform we are building for
BUILDER := $(shell which docker) ## Build backend to use
REGISTRY := stagex## Registry url/namespace to build/publish for
CHECK ?= 0## Run build with syntax checking enabled
NOCACHE ?= 0## Run build ignoring all existing cache

include src/global.mk

all: $(NAMESPACES) ## Build entire tree (default)

check: ## Run syntax checking and linting across tree
	@$(MAKE) CHECK=1 all

verify: ## Verify local build against committed digests
	@$(call verify)

digests: all digests_all ## Generate new digests for release

sign: digests ## Sign all digests that match locally built targets
	@$(call sign)

compat: ## Check system compatibility for reproducible builds
	@./src/compat.sh

preseed: ## Seed build cache from last published release
	@./src/preseed.sh

help:
	@./src/help.sh
