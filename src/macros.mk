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
