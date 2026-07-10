STAGES := pallet bootstrap core user distro service ## Namespaces to build
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

IMAGE ?= server-dev
SSH_KEY ?=
VNC_PORT ?= 5900
CONSOLE_PORT ?= 4000
SSH_PORT ?= 2222
QEMU_MEMORY ?= 8G
QEMU_DISK ?= /disk.img
QEMU_BIOS ?= /usr/share/edk2/OvmfPkg/OVMF.fd

.PHONY: vm
vm: distro-$(IMAGE) import-distro-$(IMAGE)
	@if docker inspect --format='{{.State.Running}}' qemu-$(IMAGE) >/dev/null 2>&1 && \
		docker inspect --format='{{.State.Running}}' qemu-$(IMAGE) | grep -q true; then \
		echo "Container qemu-$(IMAGE) is already running."; \
	else \
		docker rm -f qemu-$(IMAGE) >/dev/null 2>&1 || true; \
		mkdir -p $(CURDIR)/.qemu-run/$(IMAGE); \
		echo "Starting distro $(IMAGE) ..."; \
		docker run -d --name qemu-$(IMAGE) --privileged --network host \
			-v $(CURDIR)/.qemu-run/$(IMAGE):/run/qemu-vm \
			-e CONSOLE_SOCKET=/run/qemu-vm/console.sock \
			-e QMP_SOCKET=/run/qemu-vm/qmp.sock \
			-e QEMU_MEMORY=$(QEMU_MEMORY) \
			-e QEMU_DISK=$(QEMU_DISK) \
			-e QEMU_BIOS=$(QEMU_BIOS) \
			stagex/distro-$(IMAGE):local; \
		sleep 1; \
		sudo chmod 777 $(CURDIR)/.qemu-run/$(IMAGE)/console.sock 2>/dev/null || true; \
		sudo chmod 777 $(CURDIR)/.qemu-run/$(IMAGE)/qmp.sock 2>/dev/null || true; \
	fi
	@echo "" && \
	echo "=== VM qemu-$(IMAGE) ===" && \
	echo "  container:  $$(docker inspect --format='{{.Id}}' qemu-$(IMAGE) | cut -c1-12)" && \
	echo "  created:    $$(docker inspect --format='{{.Created}}' qemu-$(IMAGE) | cut -d. -f1)" && \
	echo "  memory:     $(QEMU_MEMORY)" && \
	echo "  disk:       $(QEMU_DISK)" && \
	echo "  bios:       $(QEMU_BIOS)" && \
	echo "  kvm:        $$(docker exec qemu-$(IMAGE) test -e /dev/kvm && echo yes || echo no)" && \
	echo "" && \
	echo "  Connect:" && \
	echo "    logs:     docker logs -f qemu-$(IMAGE)" && \
	echo "    ssh:      docker exec -it qemu-$(IMAGE) run ssh" && \
	echo "    vnc:      localhost:$(VNC_PORT)" && \
	echo "    serial:   socat - UNIX-CONNECT:$(CURDIR)/.qemu-run/$(IMAGE)/console.sock" && \
	echo "    qmp:      socat - UNIX-CONNECT:$(CURDIR)/.qemu-run/$(IMAGE)/qmp.sock" && \
	echo "    vsock:    guest cid 3 (from host: guestctl --vsock)" && \
	echo ""
