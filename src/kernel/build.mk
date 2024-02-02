.PHONY: nitro
nitro: \
	out/linux-nitro.tgz

out/linux-nitro.tgz: out/linux-nitro.tgz
	$(call build,kernel,linux-nitro)
