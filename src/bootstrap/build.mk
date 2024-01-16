.PHONY: bootstrap
bootstrap: \
	out/bootstrap.tgz \
	out/stage0.tgz

out/bootstrap.tgz: out/stage0.tgz
	$(call build,bootstrap,bootstrap)

out/stage0.tgz:
	$(call build,bootstrap,stage0)
