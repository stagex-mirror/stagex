STAGES := pallet bootstrap core user distro service box ## Namespaces to build
PROGRESS := auto ## Buildkit progress output style
PLATFORM := linux/amd64 ## Platform we are building for
BUILDER := $(shell command -v docker) ## Build backend to use
REGISTRY_USERNAME := 127.0.0.1:5000/stagex ## Example for registry-* targets
REGISTRY := stagex ## Registry url/namespace to build/publish for
SIGNATURES := git@codeberg.org:stagex/sigs.stagex.tools.git
CHECK ?= 0 ## Run build with syntax checking enabled
NOCACHE ?= 0 ## Run build ignoring all existing cache
IMPORT ?= 0 ## Import and tag packages after build as ":local"
RELEASE := 0 ## Set release version for release targets

include src/global.mk
include src/macros.mk

all: $(STAGES) ## Build entire tree (default)

check: ## Run syntax checking and linting across tree
	@$(MAKE) CHECK=1 all

.PHONY: signatures
signatures:
	./src/ensure-signatures-folder.sh
	git -C $@ checkout main

verify: signatures ## Verify local build against committed digests
	@$(call verify, bootstrap)
	@$(call verify, core)
	@$(call verify, pallet)
	@$(call verify, user)
	@$(call verify, distro)

.PHONY: lint-containerfiles
lint-containerfiles: ## Validate Containerfile stage-naming conventions
	@python3 src/lint-containerfiles.py $(PKG)

digests: all ## Generate new digests from full tree
	@./src/digests.py

new-digests: digests ## Provides only the newly changed digests
	@git diff --minimal digests/* | grep -E '^(\+)[a-z0-9]' | sed 's/^\+//'

sign: digests ## Sign all digests that match locally built targets
	@./src/sign-all.sh $(REGISTRY) $(RELEASE)

compat: ## Check system compatibility for reproducible builds
	@./src/compat.sh

preseed: ## Seed build cache from last published release
	@./src/preseed.sh

fetch: ## Fetch and hash verify all external source files
	@./src/fetch.py

prep-release-branch: ## Prepare a branch for a new release
	@./src/prep-release-branch.sh $(RELEASE)

help:
	@./src/help.sh Makefile

DISTRO ?= busybox
SSH_KEY ?=
VNC_PORT ?= 5900
CONSOLE_PORT ?= 4000
SSH_PORT ?= 2222
QEMU_MEMORY ?= 8G
QEMU_DISK ?= /disk.img
QEMU_BIOS ?= /usr/share/edk2/OvmfPkg/OVMF.fd

# AWS EC2 deploy shortcuts (full pipeline)
.PHONY: deploy-ec2
deploy-ec2:
	@$(MAKE) IMPORT=1 distro-$(EC2_DISTRO) >/dev/null 2>&1
	@$(MAKE) aws-ami-deploy
	@$(MAKE) aws-ec2-deploy

.PHONY: ec2-ssh
ec2-ssh:
	@$(MAKE) aws-ec2-status

# Strip -dev suffix to find the base distro directory
DISTRO_BASE = $(subst -dev,,${DISTRO})

# Determine the Containerfile stage to export
DISTRO_STAGE = package-$(DISTRO)

# Home disk image path
HOME_IMG = $(CURDIR)/out/$(DISTRO)-home.img

# Local home folder (mutable state, .gitignored)
HOME_LOCAL = $(CURDIR)/local/$(DISTRO)/home

# Cloud-init image (squashfs)
CLOUD_IMG = $(CURDIR)/out/cloud-config.img
CLOUD_TMP = $(CURDIR)/.qemu-run/cloud-init

# qemu-start, qemu-status, qemu-stop defined in service/qemu/targets.mk
