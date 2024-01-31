out/curl.tgz: \
	out/gcc.tgz \
	out/musl.tgz \
	out/busybox.tgz \
	out/make.tgz \
	out/binutils.tgz \
	out/openssl.tgz \
	out/ca-certificates.tgz
	$(call build,tools,curl)

out/gen_initramfs.tgz: \
	out/gcc.tgz \
	out/musl.tgz
	$(call build,tools,gen_initramfs)

out/tofu.tgz: \
	out/busybox.tgz \
	out/go.tgz
	$(call build,tools,tofu)

out/sops.tgz: \
	out/busybox.tgz \
	out/go.tgz
	$(call build,tools,sops)
