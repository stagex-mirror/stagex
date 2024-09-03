include src/global.mk

all: $(all_packages)

check:
	@$(MAKE) CHECK=1 all

verify:
	@$(call verify)

sign:
	@$(call sign)

digests:
	@$(call digests)

release: all
	@$(call digests) > digests.txt

compat:
	@./src/compat.sh

preseed:
	@./src/preseed.sh
