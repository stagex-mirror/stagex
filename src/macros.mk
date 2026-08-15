# Verify a set of OCI Digests for a given category against local build
define verify
	$(eval CATEGORY := $(1))
	cat digests/$(CATEGORY).txt \
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
# docker load of an OCI layout does not reliably apply the
# io.containerd.image.name annotation as a tag (produces a dangling image),
# so capture the loaded image ID and tag it explicitly.
define import
	$(eval STAGE := $(1))
	$(eval NAME := $(2))
	$(eval VERSION := $(3))
	IMG_ID=$$(tar -C out/oci/$(STAGE)-$(NAME) -cf - . | docker load 2>&1 | sed -n 's/.*Loaded image ID: sha256:\([0-9a-f]*\).*/\1/p') && \
	if [ -z "$$IMG_ID" ]; then echo "ERROR: docker load produced no image ID for $(STAGE)-$(NAME)" >&2; exit 1; fi && \
	docker tag $$IMG_ID stagex/$(STAGE)-$(NAME):$(VERSION) && \
	docker tag stagex/$(STAGE)-$(NAME):$(VERSION) stagex/$(STAGE)-$(NAME):local
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
