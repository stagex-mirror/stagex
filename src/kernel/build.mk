.PHONY: linux
linux: \
	out/linux-generic.tar

out/linux-generic.tar: \
	out/gcc.tar \
	out/binutils.tar \
	out/make.tar \
	out/musl.tar \
	out/bison.tar \
	out/pkgconf.tar \
	out/libzstd.tar \
	out/openssl.tar \
	out/perl.tar \
	out/zlib.tar \
	out/flex.tar \
	out/elfutils.tar
	$(call build,kernel,linux-generic)
