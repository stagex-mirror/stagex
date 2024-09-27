define target-list
	$(eval PACKAGE := $(1))
	grep -Ri "AS package" packages/$(PACKAGE)/Containerfile \
	| sed -e 's/FROM .* AS package//g' \
	| while IFS= read -r; \
		do \
			printf "$(PACKAGE) "; \
		done
endef

define sign
	git diff --quiet \
	|| { echo "Error: Dirty git tree"; exit 1; } \
	&& cut -d' ' -f2 digests.txt | xargs -n1 ./src/sign.sh $(REGISTRY_REMOTE)
endef

define verify
	cat digests.txt \
	| sed 's/\([a-z0-9]\+\) \(.*\)/signatures\/stagex\/\2@sha256=\1/g' \
	| while IFS= read -r sigdir; do \
	    echo $$sigdir; \
    	find $$sigdir -type f \
		| while IFS= read -r sig; do \
			cat $$sig | gpg -v 2>&1 > /dev/null | grep "Good signature" || :; \
		done; \
	done;
endef

define digests
	find out -iname "index.json" \
	| awk -F/ '{print $$2}' \
	| sort \
	| while IFS= read -r package; do \
	    jq \
	        -jr '.manifests[].digest | sub ("sha256:";"")' \
	        out/$${package}/index.json; \
	    printf " %s\n" "$${package}"; \
	done
endef

define dep-list
	$(eval PACKAGE := $(1))
	grep -Ri \
		-e "^COPY --from=stagex/"
		-e "FROM .* AS package" \
		packages/$(PACKAGE)/Containerfile \
	| sed \
		-e 's/COPY --from=stagex\/\([^ ]\+\) .*/\1/g' \
		-e 's/FROM stagex\/\([^ ]\+\).*/\1/g'
	| uniq \
	| while IFS= read -r package; \
		do \
			printf "out/$${package}/index.json "; \
	  	done
endef

define folder-list
	$(eval FOLDER := $(1))
	ls -1 $(FOLDER) 2>/dev/null | while IFS= read -r f; do printf "$$f "; done
endef

define gen-target
out/$(1)/index.json: $(shell $(call dep-list,$(1))) $(shell find packages/$(1)) | out
	$(call build,$(1))
endef

define build-context-args
	$(eval PACKAGE := $(1))
	grep -Ri \
		-e "^COPY --from=stagex/"
		-e "FROM .* AS package" \
		packages/$(PACKAGE)/Containerfile \
	| sed \
		-e 's/COPY --from=stagex\/\([^ ]\+\) .*/\1/g' \
		-e 's/FROM stagex\/\([^ ]\+\).*/\1/g'
	| uniq \
	| while IFS= read -r package; do \
		if [ "$$package" = "$(PACKAGE)" ]; then
			continue; \
		fi; \
		printf -- ' --build-context %s=oci-layout://./out/%s' "stagex/$${package}" "$${package}"; \
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
	$(eval NAME := $(1))
	$(eval VERSION := $(if $(2),$(2),latest))
	$(eval TARGET := $(if $(3),$(3),package))
	$(eval EXTRA_ARGS := $(if $(4),$(4),))
	$(eval REVISION := $(shell git rev-list HEAD -1 packages/$(NAME)))
	$(eval TEMPFILE := out/.$(notdir $(basename $@)).tmp.tar)
	$(eval BUILD_CONTEXT := $(shell $(call build-context-args,$(NAME))))
	$(eval BUILD_CMD := \
		( \
		mkdir out/$(NAME) && \
		DOCKER_BUILDKIT=1 \
		BUILDKIT_MULTI_PLATFORM=1 \
		SOURCE_DATE_EPOCH=1 \
		$(BUILDER) \
			build \
			--ulimit nofile=2048:16384 \
			--tag $(REGISTRY_REMOTE)/$(NAME):$(VERSION) \
			--platform $(PLATFORM) \
			--progress=plain \
			$(if $(filter latest,$(VERSION)),,--build-arg VERSION=$(VERSION)) \
			--output type=oci,rewrite-timestamp=true,force-compression=true,name=$(NAME),annotation.org.opencontainers.image.revision=$(REVISION),annotation.org.opencontainers.image.version=$(VERSION),tar=true,dest=- \
			--target $(TARGET) \
			$(BUILD_CONTEXT) \
			$(EXTRA_ARGS) \
			$(NOCACHE_FLAG) \
			$(CHECK_FLAG) \
			-f packages/$(NAME)/Containerfile \
			packages/$(NAME) \
		| tar -C out/$(NAME) -mx \
		) \
	)
	$(eval TIMESTAMP := $(shell TZ=GMT date +"%Y-%m-%dT%H:%M:%SZ"))
	printf "%s %s %s\n" "$(TIMESTAMP)" "$(BUILD_CMD)" start >> out/build.log \
	&& rm -rf out/$(NAME) \
	&& $(BUILD_CMD) \
	&& printf "%s %s %s\n" "$(TIMESTAMP)" "$(BUILD_CMD)" end >> out/build.log;
endef
