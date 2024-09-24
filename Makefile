include src/global.mk

all: $(all_packages)

check:
	@$(MAKE) CHECK=1 all

verify:
	@$(call verify)

digests:
	@$(call digests)

release: all
	@$(call digests) > digests.txt

sign: release
	@$(call sign)

compat:
	@./src/compat.sh

preseed:
	@./src/preseed.sh
