# Automatically generate help text from comments in root Makefile
define help
	grep -E '^[a-zA-Z0-9 -]+:.*#'  Makefile | sort | while read -r l; do printf "\033[1;32m$$(echo $$l | cut -f 1 -d':')\033[00m:$$(echo $$l | cut -f 2- -d'#')\n"; done
endef

# Sign all unsigned packages for a given category
define sign
	git diff --quiet \
	|| { echo "Error: Dirty git tree"; exit 1; } \
	&& cut -d' ' -f2 digests.txt | xargs -n1 ./src/sign.sh $(REGISTRY)
endef

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

# Generate a full set of OCI Digests for a given category from local build
define gen-digests
	$(eval CATEGORY := $(1))
	find out/$(CATEGORY)-* -iname "index.json" \
	| awk -F/ '{print $$2}' \
	| sort \
	| while IFS= read -r package; do \
	    jq \
	        -jr '.manifests[].digest | sub ("sha256:";"")' \
	        out/$${package}/index.json; \
	    printf " %s\n" "$${package}"; \
	done
endef

# List all dependencies of a given package name under a given category
define dep-list
	$(eval CATEGORY := $(1))
	$(eval NAME := $(2))
	grep -Ri \
		-e "^COPY --from=stagex/" \
		-e "^FROM stagex/.* AS package" \
		packages/$(CATEGORY)/$(NAME)/Containerfile \
	| sed \
		-e 's/COPY --from=stagex\/\([^ ]\+\) .*/\1/g' \
		-e 's/FROM stagex\/\([^ ]\+\).*/\1/g' \
	| sort -u \
	| while IFS= read -r package; \
		do \
			printf "out/$${package}/index.json "; \
	  	done
endef

# List all make targets for a given package category
define target-list
	$(eval CATEGORY := $(1))
	ls -1 packages/$(CATEGORY) 2>/dev/null | while IFS= read -r f; do printf "$(CATEGORY)-$${f} "; done
endef

# Generate dynamic target body for a given target name
define target-gen
	$(eval TARGET := $(1))
	$(eval CATEGORY := $(word 1,$(subst -, ,$(TARGET))))
	$(eval NAME := $(subst $(CATEGORY)-,,$(TARGET)))
out/$(TARGET)/index.json: $(shell $(call dep-list,$(CATEGORY),$(NAME))) $(shell find packages/$(CATEGORY)/$(NAME)) | out
	$(call build,$(CATEGORY),$(NAME))
endef

# Generate args forcing docker to favor locally built images over public ones
define build-context-args
	$(eval CATEGORY := $(1))
	$(eval NAME := $(2))
	grep -Ri \
		-e "^COPY --from=stagex/"
		-e "^FROM stagex/.* AS package" \
		packages/$(CATEGORY)/$(NAME)/Containerfile \
	| sed \
		-e 's/COPY --from=stagex\/\([^ ]\+\) .*/\1/g' \
		-e 's/FROM stagex\/\([^ ]\+\).*/\1/g'
	| sort -u \
	| sed 's/\([a-z]\)-\(.*\)/\1,\2/g' \
	| while IFS=, read -r category name; do \
		if [ "$${category}-$${name}" = "$(CATEGORY)-$(NAME)" ]; then
			continue; \
		fi; \
		printf -- ' --build-context %s=oci-layout://./out/%s-%s' "stagex/$${category}-$${name}" "$${category}" "$${name}"; \
	done
endef

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
	$(eval REVISION := $(shell git rev-list HEAD -1 packages/$(CATEGORY)/$(NAME)))
	$(eval TEMPFILE := out/.$(notdir $(basename $@)).tmp.tar)
	$(eval BUILD_CONTEXT := $(shell $(call build-context-args,$(CATEGORY),$(NAME))))
	$(eval BUILD_CMD := \
		( \
		mkdir -p out/$(CATEGORY)-$(NAME) && \
		DOCKER_BUILDKIT=1 \
		BUILDKIT_MULTI_PLATFORM=1 \
		SOURCE_DATE_EPOCH=1 \
		$(BUILDER) \
			build \
			--ulimit nofile=2048:16384 \
			--tag $(REGISTRY)/$(CATEGORY)-$(NAME):$(VERSION) \
			--platform $(PLATFORM) \
			--progress=$(PROGRESS) \
			$(if $(filter latest,$(VERSION)),,--build-arg VERSION=$(VERSION)) \
			--output type=oci,rewrite-timestamp=true,force-compression=true,name=$(NAME),annotation.org.opencontainers.image.revision=$(REVISION),annotation.org.opencontainers.image.version=$(VERSION),tar=true,dest=- \
			--target $(TARGET) \
			$(BUILD_CONTEXT) \
			$(EXTRA_ARGS) \
			$(NOCACHE_FLAG) \
			$(CHECK_FLAG) \
			-f packages/$(CATEGORY)/$(NAME)/Containerfile \
			packages/$(CATEGORY)/$(NAME) \
		| tar -C out/$(CATEGORY)-$(NAME) -mx \
		) \
	)
	$(eval TIMESTAMP := $(shell TZ=GMT date +"%Y-%m-%dT%H:%M:%SZ"))
	printf "%s %s %s\n" "$(TIMESTAMP)" "$(BUILD_CMD)" start >> out/build.log \
	&& rm -rf out/$(NAME) \
	&& $(BUILD_CMD) \
	&& printf "%s %s %s\n" "$(TIMESTAMP)" "$(BUILD_CMD)" end >> out/build.log;
endef
