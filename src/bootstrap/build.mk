.PHONY: bootstrap
bootstrap: \
	out/live-bootstrap.tgz \
	out/stage0.tgz \
	out/cross-x86_64.tgz

out/stage0.tgz:
	$(call build,bootstrap,stage0)

out/live-bootstrap.tgz: out/stage0.tgz
	$(call build,bootstrap,live-bootstrap)

out/cross-x86_64.tgz: out/live-bootstrap.tgz
	$(call build,bootstrap,cross-x86_64)
