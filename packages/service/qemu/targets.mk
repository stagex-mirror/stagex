# QEMU local qemu target — launches qemu from disk.img with user-data

.PHONY: qemu-start qemu-status qemu-stop qemu-logs

QEMU_MEMORY ?= 4G
QEMU_SSH_KEY ?= $(HOME)/.ssh/tpm-exploration.pem
QEMU_CONTAINER_NAME ?= qemu-dev
QEMU_USER_DATA_FILE ?=

# Disk image path — produced by distro build
QEMU_DISK_IMG := $(CURDIR)/out/disk.img

# qemu state file — written by vm, read by qemu-status and qemu-stop
QEMU_STATE := $(CURDIR)/out/vm.state

# Launch QEMU qemu from disk image
qemu-start:
	@if [ ! -f "$(QEMU_DISK_IMG)" ]; then \
		echo "ERROR: No disk.img found — run 'make distro-$(EC2_DISTRO)' first" >&2; exit 1; \
	fi
	@USER_DATA="" && \
	if [ -n "$(QEMU_USER_DATA_FILE)" ] && [ -f "$(QEMU_USER_DATA_FILE)" ]; then \
		USER_DATA=$$(cat "$(QEMU_USER_DATA_FILE)"); \
	elif [ -f "$(QEMU_SSH_KEY)" ]; then \
		USER_DATA=$$(ssh-keygen -y -f "$(QEMU_SSH_KEY)"); \
	elif [ -f ~/.ssh/id_rsa.pub ]; then \
		USER_DATA=$$(cat ~/.ssh/id_rsa.pub); \
	fi && \
	echo "Generating cloud-config ..." && \
	rm -f $(CURDIR)/out/cloud.img && \
	docker run --rm --privileged \
		-e "USER_DATA=$$USER_DATA" \
		-e "SSH_KEY=$(QEMU_SSH_KEY)" \
		-v $(CURDIR)/out:/out \
		-v $(CURDIR)/packages/service/qemu/src/box:/usr/bin/box \
		--entrypoint /bin/sh \
		stagex/service-qemu:local -c 'chmod +x /usr/bin/box && /usr/bin/box' && \
	docker rm -f $(QEMU_CONTAINER_NAME) >/dev/null 2>&1 || true && \
	echo "Launching QEMU ..." && \
	docker run -d --name $(QEMU_CONTAINER_NAME) --privileged --network host \
		-v $(QEMU_DISK_IMG):/input/disk.img \
		-v $(CURDIR)/out/cloud.img:/input/cloud.img \
		-v $(CURDIR)/out/cloud-iso.img:/input/cloud-iso.img \
		-v $(CURDIR)/packages/service/qemu/src/qemu-startup.sh:/usr/bin/qemu-startup.sh \
		-e QEMU_MEMORY="$(QEMU_MEMORY)" \
		-e QEMU_DISK=/input/disk.img \
		-e QEMU_CLOUD=/input/cloud.img \
		-e QEMU_CLOUD_ISO=/input/cloud-iso.img \
		--entrypoint /bin/sh \
		stagex/service-qemu:local -c 'chmod +x /usr/bin/qemu-startup.sh && exec /usr/bin/qemu-startup.sh' && \
	echo "Waiting for SSH ..." && \
	SSH_READY=0 && \
	for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40; do \
		if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -i $(QEMU_SSH_KEY) root@localhost -p 2222 'echo ready' >/dev/null 2>&1; then \
			SSH_READY=1; break; \
		fi; \
		sleep 3; \
	done && \
	if [ "$$SSH_READY" = "0" ]; then \
		echo "ERROR: SSH not ready after 120s" >&2; \
		docker logs $(QEMU_CONTAINER_NAME) --tail 20 >&2; \
		exit 1; \
	fi && \
	printf 'container=%s\nmemory=%s\nssh_key=%s\nssh_port=2222\nssh_host=localhost\n' \
		"$(QEMU_CONTAINER_NAME)" "$(QEMU_MEMORY)" "$(QEMU_SSH_KEY)" > $(QEMU_STATE) && \
	echo "" && \
	echo "=== QEMU qemu ===" && \
	echo "  container:  $(QEMU_CONTAINER_NAME)" && \
	echo "  memory:     $(QEMU_MEMORY)" && \
	echo "  ssh:        ssh -i $(QEMU_SSH_KEY) -p 2222 root@localhost" && \
	echo "  logs:       docker logs -f $(QEMU_CONTAINER_NAME)"

# Show current QEMU qemu status
qemu-status:
	@if [ ! -f "$(QEMU_STATE)" ]; then \
		echo "No qemu state file — run 'make vm' first"; exit 1; \
	fi
	@CONTAINER=$$(grep '^container=' $(QEMU_STATE) | cut -d= -f2) && \
	docker inspect --format='{{.State.Running}}' "$$CONTAINER" >/dev/null 2>&1 && \
	{ SSH_KEY=$$(grep '^ssh_key=' $(QEMU_STATE) | cut -d= -f2); \
	 SSH_PORT=$$(grep '^ssh_port=' $(QEMU_STATE) | cut -d= -f2); \
	 SSH_HOST=$$(grep '^ssh_host=' $(QEMU_STATE) | cut -d= -f2); \
	 echo "=== QEMU qemu ==="; \
	 echo "  container:  $$CONTAINER"; \
	 echo "  running:    yes"; \
	 echo "  ssh:        ssh -i $$SSH_KEY -p $$SSH_PORT root@$$SSH_HOST"; \
	 echo "  logs:       docker logs -f $$CONTAINER"; } || \
	{ echo "=== QEMU qemu ==="; \
	 echo "  container:  $$CONTAINER"; \
	 echo "  running:    no"; }

# Stop QEMU qemu
qemu-stop:
	@if [ ! -f "$(QEMU_STATE)" ]; then \
		echo "No qemu state file — run 'make vm' first"; exit 1; \
	fi
	@CONTAINER=$$(grep '^container=' $(QEMU_STATE) | cut -d= -f2) && \
	docker rm -f "$$CONTAINER" >/dev/null 2>&1 && \
	echo "QEMU $$CONTAINER stopped" || \
	echo "QEMU $$CONTAINER was not running"

# Show QEMU VM logs
qemu-logs:
	@if [ ! -f "$(QEMU_STATE)" ]; then \
		echo "No QEMU state file — run 'make qemu-start' first"; exit 1; \
	fi
	@CONTAINER=$$(grep '^container=' $(QEMU_STATE) | cut -d= -f2) && \
	docker logs --tail 50 -f "$$CONTAINER" 2>&1
