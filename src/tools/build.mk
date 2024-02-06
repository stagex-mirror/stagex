out/curl.tar: \
	out/gcc.tar \
	out/musl.tar \
	out/busybox.tar \
	out/make.tar \
	out/binutils.tar \
	out/openssl.tar \
	out/ca-certificates.tar
	$(call build,tools,curl)

out/gen_initramfs.tar: \
	out/gcc.tar \
	out/binutils.tar \
	out/musl.tar
	$(call build,tools,gen_initramfs)

out/cpio.tar: \
	out/gcc.tar \
	out/binutils.tar \
	out/musl.tar
	$(call build,tools,cpio)

out/tofu.tar: \
	out/busybox.tar \
	out/go.tar
	$(call build,tools,tofu)

out/sops.tar: \
	out/busybox.tar \
	out/go.tar
	$(call build,tools,sops)
