.PHONY: bootstrap
bootstrap: \
	out/stage0.tgz \
	out/stage1.tgz \
	out/stage2.tgz

out/stage0.tgz:
	$(call build,bootstrap,stage0)

out/stage1.tgz: out/stage0.tgz
	$(call build,bootstrap,stage1)

out/stage2.tgz: out/stage1.tgz
	$(call build,bootstrap,stage2)
