# Build package with chosen $(BUILDER)
# Supported BUILDERs: docker
# Usage: $(call build,core/$(NAME),$(VERSION),$(TARGET),$(EXTRA_ARGS))
# Notes:
# - Packages are expected to use the following layer names in order:
#   - "fetch": [optional] obtain any artifacts from the internet.
#   - "build": [optional] do any required build work
#   - "package": [required] scratch layer exporting artifacts for distribution
#   - "test": [optional] define any tests
# - Packages may prefix layer names with "text-" if more than one is desired
# - VERSION will be set as a build-arg if defined, otherwise it is "latest"
# - TARGET defaults to "package"
# - EXTRA_ARGS will be blindly injected
# - packages may also define a "test" layer
# - the ulimit line is to workaround a bug in patch when the nofile limit is too large:
#      https://savannah.gnu.org/bugs/index.php?62958
#  TODO:
# - try to disable networking on fetch layers with something like:
#   $(if $(filter fetch,$(lastword $(subst -, ,$(TARGET)))),,--network=none)
# - actually output OCI files for each build (vs plain tar)
# - output manifest.txt of all tar/digest hashes for an easy git diff
# - support buildah and podman
define build
	$(eval CATEGORY := $(1))
	$(eval NAME := $(2))
	$(eval VERSION := $(if $(3),$(3),latest))
	$(eval TARGET := $(if $(4),$(4),package))
	$(eval EXTRA_ARGS := $(if $(5),$(5),))
	$(eval REVISION := $(shell git rev-list HEAD -1 src/$(CATEGORY)/$(NAME)))
	$(eval TEMPFILE := out/.$(notdir $(basename $@)).tmp.tar)
	$(eval BUILD_CMD := \
		DOCKER_BUILDKIT=1 \
		BUILDKIT_MULTI_PLATFORM=1 \
		SOURCE_DATE_EPOCH=1 \
		$(BUILDER) \
			build \
			--ulimit nofile=2048:16384 \
			--tag $(REGISTRY)/$(NAME):$(VERSION) \
			--build-arg REGISTRY=$(REGISTRY) \
			--build-arg CORES=$(shell nproc --all) \
			--platform $(PLATFORM) \
			--progress=plain \
			$(if $(filter latest,$(VERSION)),,--build-arg VERSION=$(VERSION)) \
			--output type=oci,rewrite-timestamp=true,force-compression=true,name=$(NAME),annotation.org.opencontainers.image.revision=$(REVISION),annotation.org.opencontainers.image.version=$(VERSION),dest=$(TEMPFILE) \
			--target $(TARGET) \
			$(EXTRA_ARGS) \
			$(NOCACHE_FLAG) \
			-f src/$(CATEGORY)/$(NAME)/Containerfile \
			src/$(CATEGORY)/$(NAME) \
	)
	$(eval TIMESTAMP := $(shell TZ=GMT date +"%Y-%m-%dT%H:%M:%SZ"))
	set -eux; \
	mkdir -p out/; \
	echo $(TIMESTAMP) $(BUILD_CMD) start >> out/build.log; \
	$(BUILD_CMD); \
	tar -tf $(TEMPFILE); \
	docker load < $(TEMPFILE); \
	mv $(TEMPFILE) $@; \
	tar -xf $@ index.json -O \
		| jq -r '.manifests[].digest | sub("sha256:";"")' \
	> $(basename $@).digest; \
	echo $(TIMESTAMP) $(BUILD_CMD) end >> out/build.log;
endef
