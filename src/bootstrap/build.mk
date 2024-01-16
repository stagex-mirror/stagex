.PHONY: bootstrap
bootstrap: \
	out/live-bootstrap.tgz \
	out/stage0.tgz

out/live-bootstrap.tgz: out/stage0.tgz
	$(call build,bootstrap,live-bootstrap)

out/stage0.tgz:
	$(call build,bootstrap,stage0)
