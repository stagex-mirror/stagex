# Verify a set of OCI Digests for a given category against local build
define verify
	$(eval CATEGORY := $(1))
	cat packages/$(CATEGORY)/digests.txt \
	| sed 's/\([a-z0-9]\+\) \(.*\)/signatures\/stagex\/\2@sha256=\1/g' \
	| while IFS= read -r sigdir; do \
	    echo $$sigdir; \
    	find $$sigdir -type f \
		| while IFS= read -r sig; do \
			cat $$sig | gpg -v 2>&1 > /dev/null | grep "Good signature" || :; \
		done; \
	done;
endef

# Import an OCI image locally, tagged at :local
define import
	$(eval STAGE := $(1))
	$(eval NAME := $(2))
	$(eval VERSION := $(3))
	tar -C out/$(STAGE)-$(NAME) -cf - . | docker load
	docker tag \
		stagex/$(STAGE)-$(NAME):$(VERSION) \
		stagex/$(STAGE)-$(NAME):local
endef

# Push an image
define push-image
	$(eval IMAGE := $(1))
	while true; do \
		docker push $(IMAGE) && break; \
		echo "Push failed, retrying in 5 seconds..."; \
		sleep 5; \
	done
endef
