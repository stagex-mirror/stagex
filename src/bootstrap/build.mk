.PHONY: bootstrap
bootstrap: \
	out/stage0.tar \
	out/stage1.tar \
	out/stage2.tar \
	out/stage3.tar

out/stage0.tar:
	$(call build,bootstrap,stage0)

out/stage1.tar: out/stage0.tar
	$(call build,bootstrap,stage1)

out/stage2.tar: out/stage1.tar
	$(call build,bootstrap,stage2)

out/stage3.tar: out/stage2.tar
	$(call build,bootstrap,stage3)
