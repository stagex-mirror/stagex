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

.PHONY: vm
vm:
	@# Ensure local home folder exists
	@mkdir -p $(HOME_LOCAL)/root/.ssh
	@# Build home disk image from local folder
	@echo "Building home.img from local/$(DISTRO)/home/ ..."
	@/bin/docker run --rm --privileged \
		-v $(HOME_LOCAL):/local:ro \
		-v $(CURDIR)/out:/out \
		-e HOME_SRC=/local \
		-e HOME_OUT=/out/$(DISTRO)-home.img \
		stagex/box-img:local
	@# Generate cloud-config image with hostname + SSH key
	@# Generate cloud-config image with no-cloud user-data
	@sudo rm -rf $(CLOUD_TMP) && mkdir -p $(CLOUD_TMP)
	@printf 'instance-id: qemu-$(DISTRO)\n' > $(CLOUD_TMP)/meta-data
	@printf 'hostname: qemu-$(DISTRO)\nssh_authorized_keys:\n' > $(CLOUD_TMP)/user-data
	@test -s $(SSH_KEY) && printf '  - %s\n' "$(cat $(SSH_KEY))" >> $(CLOUD_TMP)/user-data || \
		test -s ~/.ssh/id_rsa.pub && printf '  - %s\n' "$(cat ~/.ssh/id_rsa.pub)" >> $(CLOUD_TMP)/user-data || \
		printf '  - ssh-rsa PLACEHOLDER\n' >> $(CLOUD_TMP)/user-data
	@echo "Building cloud-config.img ..."
	@/bin/docker run --rm \
		-u $(id -u):$(id -g) \
		-v $(CLOUD_TMP):/rootfs \
		-v $(CURDIR)/out:/out \
		stagex/box-squashfs:local \
		-o /out/cloud-config.img
	@# Build distro (auto-generated target handles build contexts + import)
	@echo "Building distro $(DISTRO) ..."
	@$(MAKE) IMPORT=1 distro-$(DISTRO) >/dev/null 2>&1
	@# Load QEMU runtime
	@tar -C out/service-qemu -cf - . | docker load 2>/dev/null
	@# Launch VM
	@mkdir -p $(CURDIR)/.qemu-run/$(DISTRO)
	@# Determine SSH private key path
	@SSH_PRIV_KEY="" ; \
	if [ -n "$(SSH_KEY)" ] && [ -f "$(SSH_KEY)" ]; then \
		SSH_PRIV_KEY="$(SSH_KEY%.pub)" ; \
		[ -f "$$SSH_PRIV_KEY" ] || SSH_PRIV_KEY="$(SSH_KEY)" ; \
	elif [ -f ~/.ssh/id_rsa ]; then \
		SSH_PRIV_KEY=~/.ssh/id_rsa ; \
	else \
		SSH_PRIV_KEY="" ; \
	fi ; \
	if docker inspect --format='{{.State.Running}}' qemu-$(DISTRO) >/dev/null 2>&1 && \
		docker inspect --format='{{.State.Running}}' qemu-$(DISTRO) | grep -q true; then \
		echo "Container qemu-$(DISTRO) is already running." ; \
	else \
		docker rm -f qemu-$(DISTRO) >/dev/null 2>&1 || true ; \
		echo "Starting distro $(DISTRO) ..." ; \
		if [ -n "$$SSH_PRIV_KEY" ] && [ -f "$$SSH_PRIV_KEY" ]; then \
			docker run -d --name qemu-$(DISTRO) --privileged --network host \
				-v $(CURDIR)/.qemu-run/$(DISTRO):/run/qemu-vm \
				-v $(HOME_IMG):/home.img \
				-v $(CLOUD_IMG):/cloud.img:ro \
				-v $$SSH_PRIV_KEY:/ssh_host_key:ro \
				-e CONSOLE_SOCKET=/run/qemu-vm/console.sock \
				-e QMP_SOCKET=/run/qemu-vm/qmp.sock \
				-e QEMU_MEMORY=$(QEMU_MEMORY) \
				-e QEMU_DISK=$(QEMU_DISK) \
				-e QEMU_BIOS=$(QEMU_BIOS) \
				-e QEMU_HOME=/home.img \
				-e QEMU_CLOUD=/cloud.img \
				stagex/distro-$(DISTRO):local ; \
		else \
			docker run -d --name qemu-$(DISTRO) --privileged --network host \
				-v $(CURDIR)/.qemu-run/$(DISTRO):/run/qemu-vm \
				-v $(HOME_IMG):/home.img \
				-v $(CLOUD_IMG):/cloud.img:ro \
				-e CONSOLE_SOCKET=/run/qemu-vm/console.sock \
				-e QMP_SOCKET=/run/qemu-vm/qmp.sock \
				-e QEMU_MEMORY=$(QEMU_MEMORY) \
				-e QEMU_DISK=$(QEMU_DISK) \
				-e QEMU_BIOS=$(QEMU_BIOS) \
				-e QEMU_HOME=/home.img \
				-e QEMU_CLOUD=/cloud.img \
				stagex/distro-$(DISTRO):local ; \
		fi ; \
		sleep 1 ; \
		sudo chmod 777 $(CURDIR)/.qemu-run/$(DISTRO)/console.sock 2>/dev/null || true ; \
		sudo chmod 777 $(CURDIR)/.qemu-run/$(DISTRO)/qmp.sock 2>/dev/null || true ; \
	fi
	@echo "" && \
	echo "=== VM qemu-$(DISTRO) ===" && \
	echo "  container:  $$(docker inspect --format='{{.Id}}' qemu-$(DISTRO) | cut -c1-12)" && \
	echo "  created:    $$(docker inspect --format='{{.Created}}' qemu-$(DISTRO) | cut -d. -f1)" && \
	echo "  memory:     $(QEMU_MEMORY)" && \
	echo "  disk:       $(QEMU_DISK)" && \
	echo "  bios:       $(QEMU_BIOS)" && \
	echo "  kvm:        $$(docker exec qemu-$(DISTRO) test -e /dev/kvm && echo yes || echo no)" && \
	echo "" && \
	echo "  Connect:" && \
	echo "    logs:     docker logs -f qemu-$(DISTRO)" && \
	echo "    ssh:      docker exec -it qemu-$(DISTRO) run ssh" && \
	echo "    ssh-host: ssh -p 2222 root@localhost" && \
	echo "    vnc:      localhost:$(VNC_PORT)" && \
	echo "    serial:   socat - UNIX-CONNECT:$(CURDIR)/.qemu-run/$(DISTRO)/console.sock" && \
	echo "    qmp:      socat - UNIX-CONNECT:$(CURDIR)/.qemu-run/$(DISTRO)/qmp.sock" && \
	echo "    vsock:    guest cid 3 (from host: guestctl --vsock)" && \
	echo ""
